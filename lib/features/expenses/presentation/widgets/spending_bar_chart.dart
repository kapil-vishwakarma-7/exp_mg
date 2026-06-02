import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/expense.dart';

// ─── View type enum ───────────────────────────────────────────────────────────

enum SpendingViewType { daily, weekly, monthly }

// ─── Data model for a single bar ─────────────────────────────────────────────

class _BarEntry {
  const _BarEntry({required this.x, required this.label, required this.total});

  final int x;
  final String label;
  final double total;
}

// ─── Public widget ────────────────────────────────────────────────────────────

class SpendingBarChart extends StatefulWidget {
  const SpendingBarChart({
    super.key,
    required this.expenses,
    required this.selectedMonth,
  });

  /// All expenses for the currently selected month (already filtered by caller).
  final List<Expense> expenses;

  /// The month whose data is being displayed (used for axis labels).
  final DateTime selectedMonth;

  @override
  State<SpendingBarChart> createState() => _SpendingBarChartState();
}

class _SpendingBarChartState extends State<SpendingBarChart> {
  SpendingViewType _view = SpendingViewType.monthly;

  // Cached entries — recomputed only when view or expenses change.
  List<_BarEntry>? _cachedEntries;
  SpendingViewType? _cachedView;
  int? _cachedExpenseHash;

  String _viewTitle(SpendingViewType view) {
    switch (view) {
      case SpendingViewType.daily:
        return 'Last 7 Days';
      case SpendingViewType.weekly:
        return 'By Day of Week';
      case SpendingViewType.monthly:
        return 'Daily Breakdown';
    }
  }

  List<_BarEntry> _getEntries() {
    final hash = Object.hash(
      _view,
      widget.expenses.length,
      widget.expenses.fold<double>(0, (s, e) => s + e.amount),
    );

    if (_cachedEntries != null &&
        _cachedView == _view &&
        _cachedExpenseHash == hash) {
      return _cachedEntries!;
    }

    _cachedView = _view;
    _cachedExpenseHash = hash;
    _cachedEntries = _buildEntries(_view, widget.expenses, widget.selectedMonth);
    return _cachedEntries!;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entries = _getEntries();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // ── Section header ────────────────────────────────────────────────
        Text(
          _viewTitle(_view),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 14),

        // ── Toggle ────────────────────────────────────────────────────────
        _ViewToggle(
          selected: _view,
          onChanged: (v) => setState(() => _view = v),
        ),
        const SizedBox(height: 20),

        // ── Chart or empty hint ───────────────────────────────────────────
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No data for this period',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 180,
            child: _Chart(entries: entries, colorScheme: cs),
          ),
      ],
    );
  }
}

// ─── Toggle widget ────────────────────────────────────────────────────────────

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.selected, required this.onChanged});

  final SpendingViewType selected;
  final ValueChanged<SpendingViewType> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: SpendingViewType.values.map((type) {
          final isSelected = selected == type;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? cs.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _label(type),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : cs.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _label(SpendingViewType type) {
    switch (type) {
      case SpendingViewType.daily:
        return '7 Days';
      case SpendingViewType.weekly:
        return 'Weekly';
      case SpendingViewType.monthly:
        return 'Monthly';
    }
  }
}

// ─── fl_chart bar chart ───────────────────────────────────────────────────────

class _Chart extends StatefulWidget {
  const _Chart({required this.entries, required this.colorScheme});

  final List<_BarEntry> entries;
  final ColorScheme colorScheme;

  @override
  State<_Chart> createState() => _ChartState();
}

class _ChartState extends State<_Chart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    final maxY = widget.entries
        .map((e) => e.total)
        .fold<double>(0, (a, b) => a > b ? a : b);

    // Round the Y ceiling up to a nice number so bars never hit the top.
    final yMax = maxY <= 0 ? 100.0 : (maxY * 1.25).ceilToDouble();

    // Decide how many x-axis labels to show so they don't overlap.
    final count = widget.entries.length;
    final labelInterval = count <= 10
        ? 1
        : count <= 20
            ? 2
            : count <= 31
                ? 5
                : 7;

    return BarChart(
      BarChartData(
        maxY: yMax,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => cs.inverseSurface,
            tooltipRoundedRadius: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final entry = widget.entries[group.x];
              final formatted = NumberFormat.currency(
                symbol: '₹',
                decimalDigits: 0,
              ).format(rod.toY);
              return BarTooltipItem(
                '${entry.label}\n$formatted',
                TextStyle(
                  color: cs.onInverseSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
          touchCallback: (event, response) {
            setState(() {
              _touchedIndex =
                  (event.isInterestedForInteractions &&
                          response?.spot != null)
                      ? response!.spot!.touchedBarGroupIndex
                      : null;
            });
          },
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yMax / 4,
          getDrawingHorizontalLine: (_) => FlLine(
            color: cs.outlineVariant.withValues(alpha: 0.5),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: yMax / 4,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value == meta.max) {
                  return const SizedBox.shrink();
                }
                return Text(
                  _shortAmount(value),
                  style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: labelInterval.toDouble(),
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= widget.entries.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    widget.entries[idx].label,
                    style: TextStyle(
                      fontSize: 10,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: widget.entries.asMap().entries.map((e) {
          final isTouched = e.key == _touchedIndex;
          return BarChartGroupData(
            x: e.key,
            barRods: <BarChartRodData>[
              BarChartRodData(
                toY: e.value.total,
                width: _barWidth(count),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(5),
                ),
                gradient: LinearGradient(
                  colors: isTouched
                      ? <Color>[
                          const Color(0xFF9A6BFF),
                          const Color(0xFF6E3EFF),
                        ]
                      : <Color>[
                          cs.primary.withValues(alpha: 0.7),
                          cs.primary,
                        ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ],
          );
        }).toList(),
      ),
      swapAnimationDuration: const Duration(milliseconds: 300),
      swapAnimationCurve: Curves.easeInOut,
    );
  }

  double _barWidth(int count) {
    if (count <= 7) return 20;
    if (count <= 14) return 14;
    if (count <= 24) return 10;
    return 7;
  }

  String _shortAmount(double value) {
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return value.toStringAsFixed(0);
  }
}

// ─── Data aggregation ─────────────────────────────────────────────────────────

List<_BarEntry> _buildEntries(
  SpendingViewType view,
  List<Expense> expenses,
  DateTime month,
) {
  switch (view) {
    case SpendingViewType.daily:
      return _groupByLast7Days(expenses, month);
    case SpendingViewType.weekly:
      return _groupByWeekday(expenses);
    case SpendingViewType.monthly:
      return _groupByDayOfMonth(expenses, month);
  }
}

/// Last 7 days within the selected month, labelled by date (e.g. "1", "2" …).
/// Only days that fall within the month are included.
List<_BarEntry> _groupByLast7Days(List<Expense> expenses, DateTime month) {
  final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
  // Last 7 days of the month (or all days if month has ≤7 days).
  final startDay = (daysInMonth - 6).clamp(1, daysInMonth);
  final totals = <int, double>{};
  for (var d = startDay; d <= daysInMonth; d++) {
    totals[d] = 0;
  }
  for (final e in expenses) {
    if (e.date.day >= startDay) {
      totals[e.date.day] = (totals[e.date.day] ?? 0) + e.amount;
    }
  }
  return totals.entries
      .map((entry) =>
          _BarEntry(x: entry.key - startDay, label: '${entry.key}', total: entry.value))
      .toList()
    ..sort((a, b) => a.x.compareTo(b.x));
}

/// Mon–Sun buckets (ISO weekday 1=Mon … 7=Sun).
List<_BarEntry> _groupByWeekday(List<Expense> expenses) {
  const labels = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final totals = List<double>.filled(7, 0);
  for (final e in expenses) {
    totals[e.date.weekday - 1] += e.amount;
  }
  return List.generate(
    7,
    (i) => _BarEntry(x: i, label: labels[i], total: totals[i]),
  );
}

/// Day-of-month buckets 1..N for the given month.
List<_BarEntry> _groupByDayOfMonth(
  List<Expense> expenses,
  DateTime month,
) {
  final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
  final totals = List<double>.filled(daysInMonth + 1, 0);
  for (final e in expenses) {
    if (e.date.year == month.year && e.date.month == month.month) {
      totals[e.date.day] += e.amount;
    }
  }
  return List.generate(
    daysInMonth,
    (i) => _BarEntry(x: i, label: '${i + 1}', total: totals[i + 1]),
  );
}
