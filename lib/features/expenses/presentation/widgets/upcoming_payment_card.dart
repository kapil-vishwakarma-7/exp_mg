import 'package:flutter/material.dart';

import '../../models/recurring_expense.dart';
import '../utils/expense_ui_helpers.dart';
import '../utils/upcoming_payment_utils.dart';

class UpcomingPaymentCard extends StatelessWidget {
  const UpcomingPaymentCard({
    super.key,
    required this.payment,
    required this.onTap,
    this.isHighlighted = false,
  });

  final RecurringExpense payment;
  final VoidCallback onTap;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final urgent = isUrgentPayment(payment.nextDueDate);
    final dueLabel = formatDueDate(payment.nextDueDate);
    final frequencyLabel =
        formatFrequencyLabel(payment.frequency, payment.interval);
    final borderRadius = BorderRadius.circular(20);

    // Colours that depend on whether the card has the gradient highlight.
    final iconBg = isHighlighted
        ? Colors.white.withValues(alpha: 0.2)
        : cs.surfaceContainerHighest;
    final iconColor = isHighlighted ? Colors.white : cs.onSurface;
    final titleColor = isHighlighted ? Colors.white : cs.onSurface;
    final subtitleColor = isHighlighted
        ? Colors.white.withValues(alpha: 0.85)
        : cs.onSurface.withValues(alpha: 0.6);
    final dueColor = urgent && !isHighlighted
        ? const Color(0xFFE44B75)
        : isHighlighted
            ? Colors.white.withValues(alpha: 0.9)
            : cs.onSurface.withValues(alpha: 0.6);

    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  categoryIcon(payment.category),
                  size: 20,
                  color: iconColor,
                ),
              ),
              if (urgent) ...<Widget>[
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isHighlighted
                        ? Colors.white.withValues(alpha: 0.25)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Urgent',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isHighlighted
                          ? Colors.white
                          : const Color(0xFFE44B75),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const Spacer(),
          Text(
            payment.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatExpenseAmount(payment.amount),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dueLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: dueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            frequencyLabel,
            style: TextStyle(fontSize: 12, color: subtitleColor),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: isHighlighted
            ? DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFF6E3EFF), Color(0xFF9A6BFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: content,
              )
            : DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: borderRadius,
                ),
                child: content,
              ),
      ),
    );
  }
}
