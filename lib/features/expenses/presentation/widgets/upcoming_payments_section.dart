import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/recurring_expense.dart';
import '../../providers/expense_provider.dart';
import '../screens/upcoming_payment_detail_sheet.dart';
import '../screens/upcoming_payments_screen.dart';
import 'upcoming_payment_card.dart';

class UpcomingPaymentsSection extends StatefulWidget {
  const UpcomingPaymentsSection({
    super.key,
    this.daysAhead = 7,
    this.maxItems = 5,
    this.refreshToken = 0,
  });

  final int daysAhead;
  final int maxItems;
  final int refreshToken;

  @override
  State<UpcomingPaymentsSection> createState() =>
      _UpcomingPaymentsSectionState();
}

class _UpcomingPaymentsSectionState extends State<UpcomingPaymentsSection> {
  late Future<List<RecurringExpense>> _paymentsFuture;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  @override
  void didUpdateWidget(UpcomingPaymentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken ||
        oldWidget.daysAhead != widget.daysAhead) {
      _loadPayments();
    }
  }

  void _loadPayments() {
    _paymentsFuture = context
        .read<ExpenseProvider>()
        .loadUpcomingPayments(daysAhead: widget.daysAhead);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RecurringExpense>>(
      future: _paymentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _UpcomingLoadingState();
        }
        if (snapshot.hasError) {
          return _UpcomingErrorState(message: snapshot.error.toString());
        }
        final payments = snapshot.data ?? const <RecurringExpense>[];
        return _UpcomingPaymentsContent(
          payments: payments,
          maxItems: widget.maxItems,
        );
      },
    );
  }
}

class _UpcomingPaymentsContent extends StatelessWidget {
  const _UpcomingPaymentsContent({
    required this.payments,
    required this.maxItems,
  });

  final List<RecurringExpense> payments;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final visible = payments.take(maxItems).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              'Upcoming Payments',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: payments.isEmpty
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const UpcomingPaymentsScreen(),
                        ),
                      );
                    },
              child: Text(
                payments.length > maxItems ? 'View All' : 'See all',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: payments.isEmpty
                      ? cs.onSurface.withValues(alpha: 0.3)
                      : cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (payments.isEmpty)
          const _UpcomingEmptyState()
        else
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: visible.length,
              separatorBuilder: (_, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final payment = visible[index];
                return UpcomingPaymentCard(
                  payment: payment,
                  isHighlighted: index == 0,
                  onTap: () => UpcomingPaymentDetailSheet.show(
                    context,
                    payment: payment,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _UpcomingLoadingState extends StatelessWidget {
  const _UpcomingLoadingState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Upcoming Payments',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 14),
        const SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ],
    );
  }
}

class _UpcomingErrorState extends StatelessWidget {
  const _UpcomingErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Upcoming Payments',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Could not load payments',
          style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 14),
        ),
      ],
    );
  }
}

class _UpcomingEmptyState extends StatelessWidget {
  const _UpcomingEmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
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
      child: Text(
        'No upcoming payments 🎉',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: cs.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
