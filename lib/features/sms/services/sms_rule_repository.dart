import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/sms_rule_file.dart';
import '../utils/sms_logger.dart';

/// Singleton that loads, caches, and periodically syncs SMS parsing rules.
///
/// Loading priority on startup:
///   1. Cache file  (app_documents/sms_rules_cache.json)
///   2. Bundled asset  (lib/config/sms_rules_v1.json)
///   3. Write asset → cache so future launches use it
///
/// After startup (background):
///   4. Fetch remote JSON
///   5. If version > cached version → overwrite cache + refresh memory rules
///
/// All errors are swallowed — the app always works with whatever rules it has.
class SmsRuleRepository {
  SmsRuleRepository._();

  static final SmsRuleRepository instance = SmsRuleRepository._();

  // ── Configuration ─────────────────────────────────────────────────────────

  static const String _remoteUrl =
      'https://raw.githubusercontent.com/kapil-vishwakarma-7/exp_mg/main/lib/config/sms_rules_v1.json';

  static const String _assetPath = 'lib/config/sms_rules_v1.json';
  static const String _cacheFileName = 'sms_rules_cache.json';

  static const Duration _syncInterval = Duration(hours: 6);
  static const Duration _remoteTimeout = Duration(seconds: 5);

  // ── State ─────────────────────────────────────────────────────────────────

  SmsRuleFile? _rules;
  Timer? _syncTimer;

  /// The currently active rules. Never null after [initialize] completes.
  SmsRuleFile get rules {
    assert(_rules != null, 'SmsRuleRepository.initialize() not awaited');
    return _rules!;
  }

  // ── Update stream ─────────────────────────────────────────────────────────

  final StreamController<SmsRuleFile> _updateController =
      StreamController<SmsRuleFile>.broadcast();

  /// Emits every time in-memory rules are replaced with a newer remote version.
  Stream<SmsRuleFile> get ruleUpdates => _updateController.stream;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Must be awaited before the first SMS parse.
  /// Safe to call multiple times — only initialises once.
  Future<void> initialize() async {
    if (_rules != null) return; // already initialised

    await _loadStartupRules();
    _schedulePeriodicSync();
    // Fire-and-forget background fetch so startup is not blocked.
    unawaited(_syncOnce());
  }

  /// Manually trigger a remote sync (e.g. when user enables SMS tracking).
  Future<void> syncNow() => _syncOnce();

  /// Cancel the periodic timer — call from app dispose if needed.
  void dispose() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _updateController.close();
  }

  // ── Startup loading ───────────────────────────────────────────────────────

  Future<void> _loadStartupRules() async {
    // Always load the bundled asset first so we know its version.
    final asset = await _loadFromAsset();
    final cached = await _loadFromCache();

    // Pick whichever is newer: if the bundled asset has been updated (e.g. a
    // new app build ships version 2 rules) it wins over a stale v1 cache.
    if (cached != null && cached.version >= (asset?.version ?? 0)) {
      _rules = cached;
      SmsLogger.sms(
        '[RULES] Loaded rules from cache | version=${cached.version}',
      );
      return;
    }

    if (asset != null) {
      _rules = asset;
      SmsLogger.sms(
        '[RULES] Bundled asset is newer — overwriting cache | '
        'asset=${asset.version} cache=${cached?.version ?? "none"}',
      );
      // Overwrite cache so next launch hits the correct version.
      await _writeCache(asset.toJsonString());
      return;
    }

    // Should never happen — asset is always bundled.
    throw StateError(
      '[RULES] Failed to load SMS rules from both cache and asset.',
    );
  }

  // ── Periodic sync ─────────────────────────────────────────────────────────

  void _schedulePeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) => unawaited(_syncOnce()));
  }

  // ── Remote sync ───────────────────────────────────────────────────────────

  Future<void> _syncOnce() async {
    try {
      SmsLogger.sms('[RULES] Fetching remote rules…');
      final response = await http
          .get(Uri.parse(_remoteUrl))
          .timeout(_remoteTimeout);

      if (response.statusCode != 200) {
        SmsLogger.sms(
          '[RULES] Remote fetch failed — HTTP ${response.statusCode}',
        );
        return;
      }

      final remote = SmsRuleFile.fromJsonString(response.body);
      final currentVersion = _rules?.version ?? 0;

      SmsLogger.sms(
        '[RULES] Remote version=${remote.version} | '
        'Local version=$currentVersion',
      );

      if (remote.version <= currentVersion) {
        SmsLogger.sms('[RULES] Remote rules are not newer — skipping update');
        return;
      }

      // Newer rules available → update cache and memory
      await _writeCache(response.body);
      _rules = remote;
      _updateController.add(remote);

      SmsLogger.sms(
        '[RULES] Remote rules updated | version=${remote.version}',
      );
    } on TimeoutException {
      SmsLogger.sms('[RULES] Remote fetch timed out — using cached rules');
    } on SocketException catch (e) {
      SmsLogger.sms('[RULES] No network — $e');
    } on FormatException catch (e) {
      SmsLogger.sms('[RULES] Invalid remote JSON — $e');
    } catch (e) {
      SmsLogger.sms('[RULES] Unexpected sync error — $e');
    }
  }

  // ── Cache helpers ─────────────────────────────────────────────────────────

  Future<File> _cacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_cacheFileName');
  }

  Future<SmsRuleFile?> _loadFromCache() async {
    try {
      final file = await _cacheFile();
      if (!file.existsSync()) return null;
      final raw = await file.readAsString();
      final rules = SmsRuleFile.fromJsonString(raw);
      SmsLogger.sms('[RULES] Rule version: ${rules.version}');
      return rules;
    } catch (e) {
      SmsLogger.sms('[RULES] Cache read failed — $e');
      return null;
    }
  }

  Future<void> _writeCache(String jsonString) async {
    try {
      final file = await _cacheFile();
      await file.writeAsString(jsonString, flush: true);
    } catch (e) {
      SmsLogger.sms('[RULES] Cache write failed — $e');
    }
  }

  // ── Asset helper ──────────────────────────────────────────────────────────

  Future<SmsRuleFile?> _loadFromAsset() async {
    try {
      final raw = await rootBundle.loadString(_assetPath);
      return SmsRuleFile.fromJsonString(raw);
    } catch (e) {
      SmsLogger.sms('[RULES] Asset load failed — $e');
      return null;
    }
  }
}
