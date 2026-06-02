import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/recurring_expense.dart';
import '../../providers/expense_provider.dart';
import '../utils/expense_ui_helpers.dart';
import '../utils/upcoming_payment_utils.dart';
import 'upcoming_payment_detail_sheet.dart';

class UpcomingPaymentsScreen extends StatefulWidget {
  const UpcomingPaymentsScreen({super.key, this.daysAhead = 90});

  final int daysAhead;

  @override
  State<UpcomingPaymentsScreen> createState() => _UpcomingPaymentsScreenState();
}

class _UpcomingPaymentsScreenState extends State<UpcomingPaymentsScreen> {
  List<RecurringExpense> _payments = <RecurringExpense>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await context.read<ExpenseProvider>().loadUpcomingPayments(
          daysAhead: widget.daysAhead,
        );
    if (!mounted) return;
    setState(() {
      _payments = items;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Upcoming Payments')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _payments.isEmpty
              ? Center(
                  child: Text(
                    'No upcoming payments 🎉',
                    style: TextStyle(
                      fontSize: 16,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _payments.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final payment = _payments[index];
                    final urgent = isUrgentPayment(payment.nextDueDate);

                    return Material(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: () => UpcomingPaymentDetailSheet.show(
                          context,
                          payment: payment,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: <Widget>[
                              Container(
                                width: 42,
                                height: 42,
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
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                        color: cs.onSurface,
                                      ),
                                    ),
                                    Text(
                                      formatFrequencyLabel(
                                        payment.frequency,
                                        payment.interval,
                                      ),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: <Widget>[
                                  Text(
                                    formatExpenseAmount(payment.amount),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  Text(
                                    formatDueDate(payment.nextDueDate),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: urgent
                                          ? const Color(0xFFE44B75)
                                          : cs.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
