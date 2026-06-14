import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/merchant_icon.dart';
import '../../services/merchant_icon_service.dart';

// ── Category fallback icon data ───────────────────────────────────────────────

/// Maps category strings to Material icons used when no local icon exists.
/// Extend this as new categories are added.
IconData _categoryFallback(String category) {
  switch (category.toLowerCase()) {
    case 'food':
      return Icons.restaurant_outlined;
    case 'travel':
      return Icons.directions_car_outlined;
    case 'bills':
      return Icons.receipt_long_outlined;
    case 'shopping':
      return Icons.shopping_bag_outlined;
    case 'entertainment':
      return Icons.movie_outlined;
    case 'groceries':
      return Icons.local_grocery_store_outlined;
    case 'cash':
      return Icons.atm_outlined;
    case 'health':
      return Icons.local_hospital_outlined;
    case 'education':
      return Icons.school_outlined;
    default:
      return Icons.category_outlined;
  }
}

// ── Widget ────────────────────────────────────────────────────────────────────

/// Displays the merchant icon for a transaction tile.
///
/// Resolution order:
///   1. Local file image (`FileImage`) — instant, no network
///   2. Category-based Material icon — reliable offline fallback
///
/// The widget also triggers a background [MerchantIconService.processMerchant]
/// call so the icon is downloaded the first time it's seen, without blocking
/// the UI.
class MerchantIconWidget extends StatefulWidget {
  const MerchantIconWidget({
    super.key,
    required this.merchantName,
    required this.category,
    this.size = 42,
    this.domain,
    this.iconUrl,
    this.iconService,
  });

  final String merchantName;
  final String category;
  final double size;

  /// Optional domain hint — passed to [MerchantIconService.processMerchant].
  final String? domain;

  /// Optional direct icon URL from the AI parser response.
  final String? iconUrl;

  /// Injected for testing; defaults to the singleton instance.
  final MerchantIconService? iconService;

  @override
  State<MerchantIconWidget> createState() => _MerchantIconWidgetState();
}

class _MerchantIconWidgetState extends State<MerchantIconWidget> {
  MerchantIcon? _icon;
  bool _triggered = false;

  MerchantIconService get _service =>
      widget.iconService ?? _defaultService;

  // Shared singleton so all tiles share one HTTP client and cache.
  static final MerchantIconService _defaultService = MerchantIconService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MerchantIconWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.merchantName != widget.merchantName) {
      _triggered = false;
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.merchantName.isEmpty || widget.merchantName == 'Unknown') return;

    // Fast path: check cache / DB immediately.
    final existing = await _service.getMerchantIcon(widget.merchantName);
    if (mounted) setState(() => _icon = existing);

    // Background download (once per widget lifetime).
    if (!_triggered) {
      _triggered = true;
      _service
          .processMerchant(
        merchantName: widget.merchantName,
        domain: widget.domain,
        iconUrl: widget.iconUrl,
        category: widget.category,
      )
          .then((_) async {
        // Re-query after processing so the tile updates once the icon lands.
        final updated = await _service.getMerchantIcon(widget.merchantName);
        if (mounted && updated?.localIconPath != _icon?.localIconPath) {
          setState(() => _icon = updated);
        }
      }).catchError((_) {/* silent */});
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final localPath = _icon?.localIconPath;

    // ── Case 1: local file exists ─────────────────────────────────────────
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.size / 4),
          child: Image.file(
            file,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallbackIcon(cs),
          ),
        );
      }
    }

    // ── Case 2: category icon fallback ────────────────────────────────────
    return _fallbackIcon(cs);
  }

  Widget _fallbackIcon(ColorScheme cs) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(widget.size / 4),
      ),
      child: Icon(
        _categoryFallback(widget.category),
        size: widget.size * 0.5,
        color: cs.onSurface.withValues(alpha: 0.7),
      ),
    );
  }
}
