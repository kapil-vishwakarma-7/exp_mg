import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'merchant_icon_widget.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.title,
    required this.dateTimeText,
    required this.amount,
    required this.isExpense,
    // ── Merchant icon fields ───────────────────────────────────────────────
    this.merchantName,
    this.category = 'Others',
    /// Kept for backwards-compatibility — ignored when [merchantName] is set.
    this.icon,
    // ── Subscription fields ────────────────────────────────────────────────
    this.isSubscription = false,
    this.subscriptionFrequency,
    this.nextDueDate,
    this.confidenceScore,
    this.onTap,
  });

  final String title;
  final String dateTimeText;
  final String amount;
  final bool isExpense;

  /// Merchant name used to resolve the local icon via [MerchantIconWidget].
  /// When null or "Unknown" the widget falls back to [icon] / category icon.
  final String? merchantName;

  /// Category string used for the fallback icon ("Food", "Travel", etc.).
  final String category;

  /// Legacy fallback — used when [merchantName] is absent.
  final IconData? icon;

  final bool isSubscription;
  final String? subscriptionFrequency;
  final DateTime? nextDueDate;
  final String? confidenceScore;
  final VoidCallback? onTap;

  // ── Derived helpers ───────────────────────────────────────────────────────

  bool get _showDetails =>
      isSubscription &&
      confidenceScore != null &&
      confidenceScore != 'low' &&
      subscriptionFrequency != null;

  bool get _isDueSoon {
    if (nextDueDate == null) return false;
    final days = nextDueDate!.difference(DateTime.now()).inDays;
    return days >= 0 && days <= 3;
  }

  String get _frequencyLabel {
    if (subscriptionFrequency == null) return '';
    final f = subscriptionFrequency!;
    return f[0].toUpperCase() + f.substring(1).toLowerCase();
  }

  String? get _nextDueLabel {
    if (nextDueDate == null) return null;
    return DateFormat('d MMM').format(nextDueDate!);
  }

  // ── Whether to use MerchantIconWidget or the legacy icon ─────────────────

  bool get _useMerchantIcon =>
      merchantName != null &&
      merchantName!.isNotEmpty &&
      merchantName != 'Unknown';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                // ── Merchant icon (local file) or category fallback ────────
                _buildIcon(cs),
                const SizedBox(width: 12),

                // ── Title + subtitle ───────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              title,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurface,
                                  ),
                            ),
                          ),
                          if (isSubscription) ...<Widget>[
                            const SizedBox(width: 5),
                            Icon(
                              Icons.repeat_rounded,
                              size: 14,
                              color: cs.primary.withValues(alpha: 0.75),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      if (_showDetails) ...<Widget>[
                        Row(
                          children: <Widget>[
                            Text(
                              _nextDueLabel != null
                                  ? '$_frequencyLabel • Next: $_nextDueLabel'
                                  : _frequencyLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: cs.primary.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            if (_isDueSoon) ...<Widget>[
                              const SizedBox(width: 6),
                              Text(
                                '⚠ Due soon',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: const Color(0xFFE07B00),
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          dateTimeText,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.45),
                              ),
                        ),
                      ] else ...<Widget>[
                        Text(
                          dateTimeText,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.55),
                              ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // ── Amount ─────────────────────────────────────────────────
                Text(
                  amount,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: isExpense
                            ? const Color(0xFFE44B75)
                            : const Color(0xFF0FA968),
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(ColorScheme cs) {
    // If we have a merchant name, delegate to MerchantIconWidget which
    // handles local file → category icon fallback automatically.
    if (_useMerchantIcon) {
      return MerchantIconWidget(
        merchantName: merchantName!,
        category: category,
        size: 42,
      );
    }

    // Legacy path: plain category / supplied icon inside a circle.
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: isSubscription
            ? cs.primary.withValues(alpha: 0.1)
            : cs.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon ?? Icons.account_balance_wallet_outlined,
        color: isSubscription ? cs.primary : cs.onSurface,
        size: 20,
      ),
    );
  }
}
