import 'package:flutter/material.dart';

import '../widgets/analytics_category_tile.dart';
import '../widgets/analytics_pie_chart.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  static const List<String> _months = <String>[
    'September 2026',
    'August 2026',
    'July 2026',
  ];

  String _selectedMonth = _months.first;

  final _categoryData = const <_CategoryData>[
    _CategoryData(
      name: 'Food',
      amount: 18280,
      progress: 0.40,
      icon: Icons.restaurant_outlined,
      color: Color(0xFF6E3EFF),
    ),
    _CategoryData(
      name: 'Travel',
      amount: 12400,
      progress: 0.27,
      icon: Icons.directions_car_outlined,
      color: Color(0xFF00A6A6),
    ),
    _CategoryData(
      name: 'Bills',
      amount: 8900,
      progress: 0.19,
      icon: Icons.receipt_long_outlined,
      color: Color(0xFFFF8A4C),
    ),
    _CategoryData(
      name: 'Shopping',
      amount: 6120,
      progress: 0.14,
      icon: Icons.shopping_bag_outlined,
      color: Color(0xFFEC4899),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pieData = _categoryData
        .map(
          (item) => PieSliceData(
            value: item.amount.toDouble(),
            color: item.color,
            label: item.name,
          ),
        )
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F7FB),
        elevation: 0,
        title: const Text('Analytics'),
        actions: <Widget>[
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedMonth,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.w600,
                ),
                items: _months
                    .map(
                      (month) => DropdownMenuItem<String>(
                        value: month,
                        child: Text(month),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedMonth = value;
                  });
                },
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _CardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const <Widget>[
                Text(
                  'Total Spending This Month',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '₹45,700',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
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
                const Text(
                  'Category Distribution',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    AnalyticsPieChart(slices: pieData),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: _categoryData
                            .map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _LegendItem(
                                  color: item.color,
                                  label: item.name,
                                ),
                              ),
                            )
                            .toList(),
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
              children: const <Widget>[
                Text(
                  'Insights',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 12),
                _InsightTile(text: 'You spent 40% on Food'),
                SizedBox(height: 8),
                _InsightTile(text: 'Highest spending day: Friday'),
                SizedBox(height: 8),
                _InsightTile(text: 'Spending is down 8% vs last month'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Categories',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          ..._categoryData.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AnalyticsCategoryTile(
                icon: item.icon,
                title: item.name,
                amount: '₹${item.amount}',
                progress: item.progress,
                color: item.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardContainer extends StatelessWidget {
  const _CardContainer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
  const _LegendItem({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF374151),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
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
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF111827),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryData {
  const _CategoryData({
    required this.name,
    required this.amount,
    required this.progress,
    required this.icon,
    required this.color,
  });

  final String name;
  final int amount;
  final double progress;
  final IconData icon;
  final Color color;
}
