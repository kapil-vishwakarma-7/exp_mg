import 'package:flutter/material.dart';

import '../../models/recurring_expense.dart';
import '../utils/expense_ui_helpers.dart';
import '../utils/upcoming_payment_utils.dart';

class UpcomingPaymentDetailSheet extends StatelessWidget {
  const UpcomingPaymentDetailSheet({super.key, required this.payment});

  final RecurringExpense payment;

  static Future<void> show(
    BuildContext context, {
    required RecurringExpense payment,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => UpcomingPaymentDetailSheet(payment: payment),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  categoryIcon(payment.category),
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      payment.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      formatExpenseAmount(payment.amount),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6E3EFF),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DetailRow(label: 'Due', value: formatDueDate(payment.nextDueDate)),
          _DetailRow(
            label: 'Date',
            value: formatExactDueDate(payment.nextDueDate),
          ),
          _DetailRow(
            label: 'Frequency',
            value: formatFrequencyLabel(payment.frequency, payment.interval),
          ),
          _DetailRow(label: 'Category', value: payment.category),
          if (payment.endDate != null)
            _DetailRow(
              label: 'Ends',
              value: formatExactDueDate(payment.endDate!),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
