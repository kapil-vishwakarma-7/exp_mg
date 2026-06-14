import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../database/database_helper.dart';
import '../models/merchant_icon.dart';

/// Manages merchant icon download, local caching, and lookup.
///
/// All operations are safe to call fire-and-forget — every public method
/// catches its own errors and logs them without throwing.
///
/// Call [getMerchantIcon] to resolve an icon for a transaction tile.
/// Call [processMerchant] after a transaction is saved to ensure the
/// merchant record exists and its icon is downloaded asynchronously.
class MerchantIconService {
  MerchantIconService({
    DatabaseHelper? db,
    http.Client? httpClient,
    this.downloadTimeout = const Duration(seconds: 8),
  })  : _db = db ?? DatabaseHelper.instance,
        _httpClient = httpClient ?? http.Client();

  final DatabaseHelper _db;
  final http.Client _httpClient;
  final Duration downloadTimeout;

  // ── In-memory cache (name → icon) to avoid repeated DB hits ──────────────
  final Map<String, MerchantIcon> _cache = <String, MerchantIcon>{};

  // ── Public API ────────────────────────────────────────────────────────────

  /// Ensures [merchantName] exists in the DB and queues an icon download
  /// if one is not already stored locally.
  ///
  /// Fire-and-forget — call after a transaction is saved.
  Future<void> processMerchant({
    required String merchantName,
    String? domain,
    String? iconUrl,
    required String category,
  }) async {
    try {
      if (merchantName.isEmpty || merchantName == 'Unknown') return;

      final existing = await _db.getMerchantByName(merchantName);

      if (existing != null && existing.hasLocalIcon) {
        // Already fully resolved — update cache and return.
        _cache[_key(merchantName)] = existing;
        debugPrint('[ICON] Already cached: ${existing.name}');
        return;
      }

      // Upsert the merchant row (fills in domain / iconUrl if provided).
      final merchant = await _db.upsertMerchant(
        name: merchantName,
        domain: domain ?? _inferDomain(merchantName),
        iconUrl: iconUrl,
        category: category,
      );

      _cache[_key(merchantName)] = merchant;

      // Download icon if we have a source URL and no local file yet.
      if (!merchant.hasLocalIcon && merchant.hasRemoteSource) {
        unawaited(_downloadAndStore(merchant));
      }
    } catch (e, st) {
      debugPrint('[ICON] processMerchant error for $merchantName: $e\n$st');
    }
  }

  /// Returns the [MerchantIcon] for [merchantName], or null if not found.
  ///
  /// Checks the in-memory cache first, then the DB.
  Future<MerchantIcon?> getMerchantIcon(String merchantName) async {
    if (merchantName.isEmpty || merchantName == 'Unknown') return null;
    final k = _key(merchantName);
    if (_cache.containsKey(k)) return _cache[k];
    final record = await _db.getMerchantByName(merchantName);
    if (record != null) _cache[k] = record;
    return record;
  }

  // ── Download & store ──────────────────────────────────────────────────────

  /// Downloads the icon for [merchant] and persists it locally.
  /// Tries [MerchantIcon.resolvedIconUrl] first, then [MerchantIcon.fallbackIconUrl].
  Future<void> _downloadAndStore(MerchantIcon merchant) async {
    try {
      final primaryUrl = merchant.resolvedIconUrl;
      if (primaryUrl == null) return;

      debugPrint('[ICON] Downloading: ${merchant.name} from $primaryUrl');

      final bytes = await _tryDownload(primaryUrl) ??
          (merchant.fallbackIconUrl != null
              ? await _tryDownload(merchant.fallbackIconUrl!)
              : null);

      if (bytes == null) {
        debugPrint('[ICON] All sources failed for ${merchant.name}');
        return;
      }

      final localPath = await _saveToFile(merchant.name, bytes);
      await _db.updateMerchantLocalIcon(merchant.name, localPath);

      final updated = merchant.copyWith(localIconPath: localPath);
      _cache[_key(merchant.name)] = updated;

      debugPrint('[ICON] Stored: ${merchant.name} → $localPath');
    } catch (e) {
      debugPrint('[ICON] Download error for ${merchant.name}: $e');
    }
  }

  /// Attempts to download from [url]. Returns the bytes on success,
  /// or null when:
  ///   - HTTP status ≠ 200
  ///   - Response is not an image
  ///   - Image is suspiciously small (< 200 bytes → likely a placeholder)
  Future<List<int>?> _tryDownload(String url) async {
    try {
      final response = await _httpClient
          .get(Uri.parse(url))
          .timeout(downloadTimeout);

      if (response.statusCode != 200) {
        debugPrint('[ICON] HTTP ${response.statusCode} from $url');
        return null;
      }

      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.startsWith('image/')) {
        debugPrint('[ICON] Non-image content-type ($contentType) from $url');
        return null;
      }

      // Google's "unknown domain" favicon is a 1×1 grey PNG < 200 bytes.
      if (response.bodyBytes.length < 200) {
        debugPrint(
          '[ICON] Placeholder detected (${response.bodyBytes.length}B) from $url',
        );
        return null;
      }

      return response.bodyBytes;
    } catch (e) {
      debugPrint('[ICON] _tryDownload error for $url: $e');
      return null;
    }
  }

  // ── File storage ──────────────────────────────────────────────────────────

  /// Saves [bytes] to `<appDocuments>/merchant_icons/<hash>.png`.
  ///
  /// Uses a SHA-256 hash of the merchant name as the filename so:
  ///   - Special characters and spaces are never a problem
  ///   - The same merchant always maps to the same file (idempotent)
  Future<String> _saveToFile(String merchantName, List<int> bytes) async {
    final dir = await _iconsDirectory();
    final hash = _hashName(merchantName);
    final file = File('${dir.path}/$hash.png');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<Directory> _iconsDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/merchant_icons');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  /// SHA-256 hex of the normalised merchant name — safe filename, no dupes.
  String _hashName(String name) {
    final bytes = utf8.encode(name.trim().toLowerCase());
    return sha256.convert(bytes).toString();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _key(String name) => name.trim().toLowerCase();

  /// Best-effort domain inference from known merchant names.
  String? _inferDomain(String merchantName) {
    final lower = merchantName.toLowerCase().trim();
    const knownDomains = <String, String>{
      'netflix': 'netflix.com',
      'spotify': 'spotify.com',
      'amazon': 'amazon.in',
      'amazon prime': 'primevideo.com',
      'swiggy': 'swiggy.com',
      'zomato': 'zomato.com',
      'hotstar': 'hotstar.com',
      'youtube': 'youtube.com',
      'uber': 'uber.com',
      'ola': 'olacabs.com',
      'flipkart': 'flipkart.com',
      'myntra': 'myntra.com',
      'bigbasket': 'bigbasket.com',
      'blinkit': 'blinkit.com',
      'paytm': 'paytm.com',
      'phonepe': 'phonepe.com',
      'gpay': 'pay.google.com',
      'google pay': 'pay.google.com',
      'irctc': 'irctc.co.in',
      'dominos': 'dominos.co.in',
      'rapido': 'rapido.bike',
      'github': 'github.com',
      'linkedin': 'linkedin.com',
      'microsoft': 'microsoft.com',
      'adobe': 'adobe.com',
      'dropbox': 'dropbox.com',
    };
    for (final entry in knownDomains.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return null;
  }

  void dispose() => _httpClient.close();
}

// ── Top-level unawaited helper ────────────────────────────────────────────────
void unawaited(Future<void> future) {}
