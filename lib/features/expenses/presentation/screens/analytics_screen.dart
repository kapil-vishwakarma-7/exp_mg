import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/expense.dart';
import '../../providers/expense_provider.dart';
import '../../services/analytics_service.dart';
import '../utils/expense_ui_helpers.dart';
import '../widgets/analytics_category_tile.dart';
import '../widgets/analytics_pie_chart.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  AnalyticsSnapshot? _cachedSnapshot;
  int? _cacheKey;

  static const List<Color> _chartColors = <Color>[
    Color(0xFF6E3EFF),
    Color(0xFF00A6A6),
    Color(0xFFFF8A4C),
    Color(0xFFEC4899),
    Color(0xFF3B82F6),
    Color(0xFF10B981),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExpenseProvider>().fetchExpenses();
    });
  }

  AnalyticsSnapshot _snapshotFor(List<Expense> expenses) {
    final cacheKey = Object.hash(
      _selectedMonth.year,
      _selectedMonth.month,
      expenses.length,
      expenses.fold<double>(0, (sum, expense) => sum + expense.amount),
    );

    if (_cachedSnapshot != null && _cacheKey == cacheKey) {
      return _cachedSnapshot!;
    }

    _cacheKey = cacheKey;
    _cachedSnapshot = AnalyticsSnapshot.compute(
      expenses,
      _selectedMonth,
      _analyticsService,
    );
    return _cachedSnapshot!;
  }

  List<DateTime> _monthOptions(List<Expense> expenses) {
    final keys = <String, DateTime>{};
    final now = DateTime.now();
    keys['${now.year}-${now.month}'] = DateTime(now.year, now.month);

    for (final expense in expenses) {
      final month = DateTime(expense.date.year, expense.date.month);
      keys['${month.year}-${month.month}'] = month;
    }

    final months = keys.values.toList()
      ..sort((a, b) {
        if (a.year != b.year) return b.year.compareTo(a.year);
        return b.month.compareTo(a.month);
      });
    return months;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: <Widget>[
          Consumer<ExpenseProvider>(
            builder: (context, provider, child) {
              final months = _monthOptions(provider.expenses);
              if (months.isEmpty) return const SizedBox.shrink();

              final selectedExists = months.any(
                (month) =>
                    month.year == _selectedMonth.year &&
                    month.month == _selectedMonth.month,
              );
              final dropdownValue =
                  selectedExists ? _selectedMonth : months.first;

              if (!selectedExists) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() {
                    _selectedMonth = dropdownValue;
                    _cachedSnapshot = null;
                  });
                });
              }

              return Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<DateTime>(
                    value: dropdownValue,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    dropdownColor: cs.surface,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    items: months
                        .map(
                          (month) => DropdownMenuItem<DateTime>(
                            value: month,
                            child: Text(
                              _analyticsService.formatMonthLabel(month),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedMonth = value;
                        _cachedSnapshot = null;
                      });
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<ExpenseProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final snapshot = _snapshotFor(provider.expenses);

          if (provider.expenses.isEmpty) {
            return const _AnalyticsEmptyState();
          }

          if (snapshot.isEmpty) {
            return _AnalyticsEmptyState(
              message:
                  'No expenses in ${_analyticsService.formatMonthLabel(snapshot.month)}.',
            );
          }

          final breakdownEntries = snapshot.categoryBreakdown.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          final pieData = breakdownEntries.asMap().entries.map((entry) {
            final index = entry.key;
            final category = entry.value;
            return PieSliceData(
              value: category.value,
              color: _chartColors[index % _chartColors.length],
              label: category.key,
            );
          }).toList();

          final topCategory = snapshot.topCategory;
          final topCategoryAmount = topCategory == null
              ? 0.0
              : snapshot.categoryBreakdown[topCategory] ?? 0;
          final topCategoryPercent = snapshot.monthlySpending <= 0
              ? 0
              : ((topCategoryAmount / snapshot.monthlySpending) * 100).round();

          final highestDay = snapshot.highestSpendingDay;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _CardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Total Spending (${_analyticsService.formatMonthLabel(snapshot.month)})',
                      style: TextStyle(
                        fontSize: 14,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _analyticsService.formatCurrency(snapshot.monthlySpending),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _CardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Category Distribution',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        AnalyticsPieChart(slices: pieData),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            children: breakdownEntries.asMap().entries.map(
                              (entry) {
                                final index = entry.key;
                                final category = entry.value;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _LegendItem(
                                    color: _chartColors[
                                        index % _chartColors.length],
                                    label: category.key,
                                  ),
                                );
                              },
                            ).toList(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _CardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Insights',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (topCategory != null)
                      _InsightTile(
                        text: 'You spent $topCategoryPercent% on $topCategory',
                      ),
                    if (topCategory != null) const SizedBox(height: 8),
                    if (highestDay != null)
                      _InsightTile(
                        text:
                            'Highest spending day: ${_analyticsService.formatDayLabel(highestDay)}',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Categories',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              ...breakdownEntries.asMap().entries.map((entry) {
                final index = entry.key;
                final category = entry.value;
                final progress = snapshot.monthlySpending <= 0
                    ? 0.0
                    : category.value / snapshot.monthlySpending;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AnalyticsCategoryTile(
                    icon: categoryIcon(category.key),
                    title: category.key,
                    amount: _analyticsService.formatCurrency(category.value),
                    progress: progress,
                    color: _chartColors[index % _chartColors.length],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _AnalyticsEmptyState extends StatelessWidget {
  const _AnalyticsEmptyState({
    this.message = 'Add expenses to see spending insights.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.bar_chart_outlined,
              size: 56,
              color: cs.onSurface.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 12),
            Text(
              'No analytics yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardContainer extends StatelessWidget {
  const _CardContainer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: cs.onSurface.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.lightbulb_outline_rounded,
            color: Color(0xFF6E3EFF),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
