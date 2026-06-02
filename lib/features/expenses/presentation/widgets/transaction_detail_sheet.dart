import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/expense.dart';
import '../utils/expense_ui_helpers.dart';
import '../../../../features/sms/models/detected_subscription.dart';

class TransactionDetailSheet extends StatelessWidget {
  const TransactionDetailSheet({
    super.key,
    required this.expense,
    this.subscription,
    this.recentPayments = const <Expense>[],
  });

  final Expense expense;

  /// Linked subscription record — null for non-subscription expenses.
  final DetectedSubscription? subscription;

  /// Last 3 payments from the same merchant (for subscription section).
  final List<Expense> recentPayments;

  static Future<void> show(
    BuildContext context, {
    required Expense expense,
    DetectedSubscription? subscription,
    List<Expense> recentPayments = const <Expense>[],
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => TransactionDetailSheet(
        expense: expense,
        subscription: subscription,
        recentPayments: recentPayments,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // ── Drag handle ─────────────────────────────────────────────────
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              shrinkWrap: true,
              children: <Widget>[
                // ── Header ────────────────────────────────────────────────
                _Header(expense: expense),
                const SizedBox(height: 20),

                // ── Basic details ─────────────────────────────────────────
                _SectionCard(
                  children: <Widget>[
                    _DetailRow(
                      label: 'Date',
                      value: DateFormat('dd MMM yyyy, hh:mm a')
                          .format(expense.transactionTime),
                    ),
                    if (expense.category.isNotEmpty)
                      _DetailRow(
                        label: 'Category',
                        value: expense.category,
                      ),
                    if (expense.merchant != null &&
                        expense.merchant!.isNotEmpty)
                      _DetailRow(
                        label: 'Merchant',
                        value: expense.merchant!,
                      ),
                    if (expense.note.isNotEmpty &&
                        !expense.note.startsWith('SMS'))
                      _DetailRow(label: 'Note', value: expense.note),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Subscription section ──────────────────────────────────
                if (subscription != null) ...<Widget>[
                  _SubscriptionSection(
                    subscription: subscription!,
                    recentPayments: recentPayments,
                  ),
                  const SizedBox(height: 16),
                ] else if (expense.isSubscription) ...<Widget>[
                  // Flagged but subscription record not yet loaded
                  _SectionCard(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.repeat_rounded,
                            size: 16,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Recurring Payment',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: cs.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final amountColor = expense.isDebit
        ? const Color(0xFFE44B75)
        : const Color(0xFF0FA968);

    return Row(
      children: <Widget>[
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: expense.isSubscription
                ? cs.primary.withValues(alpha: 0.1)
                : cs.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Icon(
            categoryIcon(expense.category),
            color: expense.isSubscription ? cs.primary : cs.onSurface,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      expenseDisplayTitle(expense),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  if (expense.isSubscription) ...<Widget>[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.repeat_rounded,
                      size: 16,
                      color: cs.primary,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                formatExpenseAmount(expense.amount),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: amountColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Subscription section ──────────────────────────────────────────────────────

class _SubscriptionSection extends StatelessWidget {
  const _SubscriptionSection({
    required this.subscription,
    required this.recentPayments,
  });

  final DetectedSubscription subscription;
  final List<Expense> recentPayments;

  String get _frequencyLabel {
    final f = subscription.frequency;
    return f[0].toUpperCase() + f.substring(1).toLowerCase();
  }

  bool get _isDueSoon {
    final days = subscription.nextDueDate.difference(DateTime.now()).inDays;
    return days >= 0 && days <= 3;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return _SectionCard(
      children: <Widget>[
        // Section header
        Row(
          children: <Widget>[
            Icon(Icons.repeat_rounded, size: 16, color: cs.primary),
            const SizedBox(width: 8),
            Text(
              'Recurring Payment',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: cs.primary,
              ),
            ),
            const Spacer(),
            // Confidence badge
            _ConfidenceBadge(score: subscription.confidenceScore),
          ],
        ),
        const SizedBox(height: 12),

        _DetailRow(label: 'Frequency', value: _frequencyLabel),
        _DetailRow(
          label: 'Last Paid',
          value: DateFormat('d MMM yyyy').format(subscription.lastPaidDate),
        ),
        _DetailRow(
          label: 'Next Due',
          value: DateFormat('d MMM yyyy').format(subscription.nextDueDate),
          valueColor: _isDueSoon ? const Color(0xFFE07B00) : null,
          suffix: _isDueSoon
              ? '  ⚠ Due soon'
              : null,
          suffixColor: const Color(0xFFE07B00),
        ),

        // Recent payments mini-list
        if (recentPayments.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            'Recent Payments',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          ...recentPayments.take(3).map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: <Widget>[
                      Text(
                        DateFormat('d MMM').format(e.date),
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        formatExpenseAmount(e.amount),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ],
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.score});

  final String score;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Color bg;
    Color fg;
    String label;

    switch (score) {
      case 'high':
        bg = const Color(0xFF0FA968).withValues(alpha: 0.12);
        fg = const Color(0xFF0FA968);
        label = 'High confidence';
      case 'medium':
        bg = cs.primary.withValues(alpha: 0.1);
        fg = cs.primary;
        label = 'Medium confidence';
      default:
        bg = cs.surfaceContainerHighest;
        fg = cs.onSurface.withValues(alpha: 0.5);
        label = 'Low confidence';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

// ── Shared card wrapper ───────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

// ── Detail row ────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.suffix,
    this.suffixColor,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final String? suffix;
  final Color? suffixColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: valueColor ?? cs.onSurface,
                    ),
                  ),
                ),
                if (suffix != null)
                  Text(
                    suffix!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: suffixColor ?? cs.onSurface,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
