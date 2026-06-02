import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/expense.dart';
import '../../providers/expense_provider.dart';
import '../../services/analytics_service.dart';
import '../utils/expense_ui_helpers.dart';
import '../widgets/analytics_category_tile.dart';
import '../widgets/analytics_pie_chart.dart';
import '../widgets/spending_bar_chart.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();

  // Normalised to the first day of the month — no time component.
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

  // ── Month navigation ────────────────────────────────────────────────────────

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year &&
        _selectedMonth.month == now.month;
  }

  void _goToPreviousMonth() {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month - 1);
      _cachedSnapshot = null;
      _cacheKey = null;
    });
  }

  void _goToNextMonth() {
    if (_isCurrentMonth) return; // never navigate into the future
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + 1);
      _cachedSnapshot = null;
      _cacheKey = null;
    });
  }

  // ── Snapshot caching ────────────────────────────────────────────────────────

  AnalyticsSnapshot _snapshotFor(List<Expense> expenses) {
    final cacheKey = Object.hash(
      _selectedMonth.year,
      _selectedMonth.month,
      expenses.length,
      expenses.fold<double>(0, (sum, e) => sum + e.amount),
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

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: Consumer<ExpenseProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.expenses.isEmpty) {
            return const _AnalyticsEmptyState();
          }

          final snapshot = _snapshotFor(provider.expenses);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: <Widget>[
              // ── Month navigator ───────────────────────────────────────
              _MonthNavigator(
                selectedMonth: _selectedMonth,
                isCurrentMonth: _isCurrentMonth,
                onPrevious: _goToPreviousMonth,
                onNext: _goToNextMonth,
              ),
              const SizedBox(height: 16),

              // ── Total spending card ───────────────────────────────────
              _CardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Total Spending',
                      style: TextStyle(
                        fontSize: 14,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    snapshot.isEmpty
                        ? Text(
                            '₹0.00',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface.withValues(alpha: 0.35),
                            ),
                          )
                        : Text(
                            _analyticsService
                                .formatCurrency(snapshot.monthlySpending),
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                    if (snapshot.isEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        'No expenses recorded this month.',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Bar chart (always shown; handles empty internally) ─────
              // Key forces widget rebuild when month changes so the toggle
              // resets to Monthly and the cache is cleared.
              _CardContainer(
                child: SpendingBarChart(
                  key: ValueKey<String>(
                    '${_selectedMonth.year}-${_selectedMonth.month}',
                  ),
                  expenses: snapshot.monthExpenses,
                  selectedMonth: _selectedMonth,
                ),
              ),

              // ── Everything below only when there is data ──────────────
              if (!snapshot.isEmpty) ...<Widget>[
                const SizedBox(height: 16),

                // ── Pie chart ───────────────────────────────────────────
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
                          AnalyticsPieChart(
                            slices: _buildPieSlices(snapshot),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              children: snapshot.categoryBreakdown.entries
                                  .toList()
                                  .asMap()
                                  .entries
                                  .map((e) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8),
                                        child: _LegendItem(
                                          color: _chartColors[
                                              e.key % _chartColors.length],
                                          label: e.value.key,
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Insights ────────────────────────────────────────────
                _buildInsightsCard(snapshot, cs),
                const SizedBox(height: 16),

                // ── Category tiles ──────────────────────────────────────
                Text(
                  'Categories',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                ..._buildCategoryTiles(snapshot),
              ],
            ],
          );
        },
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  List<PieSliceData> _buildPieSlices(AnalyticsSnapshot snapshot) {
    final entries = snapshot.categoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.asMap().entries.map((e) {
      return PieSliceData(
        value: e.value.value,
        color: _chartColors[e.key % _chartColors.length],
        label: e.value.key,
      );
    }).toList();
  }

  Widget _buildInsightsCard(AnalyticsSnapshot snapshot, ColorScheme cs) {
    final topCategory = snapshot.topCategory;
    final topCategoryAmount =
        topCategory == null ? 0.0 : snapshot.categoryBreakdown[topCategory] ?? 0;
    final topCategoryPercent = snapshot.monthlySpending <= 0
        ? 0
        : ((topCategoryAmount / snapshot.monthlySpending) * 100).round();
    final highestDay = snapshot.highestSpendingDay;

    return _CardContainer(
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
          if (topCategory != null && highestDay != null)
            const SizedBox(height: 8),
          if (highestDay != null)
            _InsightTile(
              text:
                  'Highest spending day: ${_analyticsService.formatDayLabel(highestDay)}',
            ),
        ],
      ),
    );
  }

  List<Widget> _buildCategoryTiles(AnalyticsSnapshot snapshot) {
    final entries = snapshot.categoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries.asMap().entries.map((e) {
      final progress = snapshot.monthlySpending <= 0
          ? 0.0
          : e.value.value / snapshot.monthlySpending;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: AnalyticsCategoryTile(
          icon: categoryIcon(e.value.key),
          title: e.value.key,
          amount: _analyticsService.formatCurrency(e.value.value),
          progress: progress,
          color: _chartColors[e.key % _chartColors.length],
        ),
      );
    }).toList();
  }
}

// ─── Month navigator ──────────────────────────────────────────────────────────

class _MonthNavigator extends StatelessWidget {
  const _MonthNavigator({
    required this.selectedMonth,
    required this.isCurrentMonth,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime selectedMonth;
  final bool isCurrentMonth;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = DateFormat('MMMM yyyy').format(selectedMonth);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          // ── Previous ───────────────────────────────────────────────────
          _NavButton(
            icon: Icons.chevron_left_rounded,
            onTap: onPrevious,
            enabled: true,
          ),

          // ── Month label ────────────────────────────────────────────────
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ),

          // ── Next (disabled when on current month) ──────────────────────
          _NavButton(
            icon: Icons.chevron_right_rounded,
            onTap: isCurrentMonth ? null : onNext,
            enabled: !isCurrentMonth,
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.onTap,
    required this.enabled,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 24,
            color: enabled
                ? cs.onSurface
                : cs.onSurface.withValues(alpha: 0.25),
          ),
        ),
      ),
    );
  }
}

// ─── Supporting widgets ───────────────────────────────────────────────────────

class _AnalyticsEmptyState extends StatelessWidget {
  const _AnalyticsEmptyState();

  static const String _message = 'Add expenses to see spending insights.';

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
              _message,
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
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurface.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
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
