import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.title,
    required this.dateTimeText,
    required this.amount,
    required this.isExpense,
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
  final IconData? icon;

  final bool isSubscription;

  /// 'monthly' | 'weekly' | 'biweekly' | etc.
  final String? subscriptionFrequency;

  /// Used to show "Next: 5 Jul" and the "⚠ Due soon" warning.
  final DateTime? nextDueDate;

  /// 'low' | 'medium' | 'high' — controls how much detail is shown.
  final String? confidenceScore;

  /// Optional tap handler — used to open the detail sheet.
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
                // ── Category icon ──────────────────────────────────────────
                Container(
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
                ),
                const SizedBox(width: 12),

                // ── Title + subtitle block ─────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Title row with optional 🔁 icon
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

                      // Subscription subtitle OR plain date
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
}
