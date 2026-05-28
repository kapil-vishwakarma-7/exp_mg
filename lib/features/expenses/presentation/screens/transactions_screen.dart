import 'package:flutter/material.dart';

import '../widgets/transaction_tile.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';

  final List<_TransactionItem> _items = const <_TransactionItem>[
    _TransactionItem(
      name: 'Zomato',
      dateTimeText: 'Today, 1:20 PM',
      amount: '-₹420.00',
      isExpense: true,
      group: 'Today',
      icon: Icons.restaurant_outlined,
    ),
    _TransactionItem(
      name: 'Salary',
      dateTimeText: 'Today, 9:05 AM',
      amount: '+₹35,000.00',
      isExpense: false,
      group: 'Today',
      icon: Icons.account_balance_outlined,
    ),
    _TransactionItem(
      name: 'Uber',
      dateTimeText: 'Yesterday, 8:12 PM',
      amount: '-₹230.00',
      isExpense: true,
      group: 'Yesterday',
      icon: Icons.local_taxi_outlined,
    ),
    _TransactionItem(
      name: 'Amazon Refund',
      dateTimeText: 'Yesterday, 11:34 AM',
      amount: '+₹899.00',
      isExpense: false,
      group: 'Yesterday',
      icon: Icons.inventory_2_outlined,
    ),
    _TransactionItem(
      name: 'Electricity Bill',
      dateTimeText: '20 Sep, 6:01 PM',
      amount: '-₹1,750.00',
      isExpense: true,
      group: 'Older',
      icon: Icons.bolt_outlined,
    ),
    _TransactionItem(
      name: 'Groceries',
      dateTimeText: '19 Sep, 7:45 PM',
      amount: '-₹1,290.00',
      isExpense: true,
      group: 'Older',
      icon: Icons.shopping_bag_outlined,
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _filteredItems();
    final grouped = <String, List<_TransactionItem>>{};
    for (final item in visibleItems) {
      grouped.putIfAbsent(item.group, () => <_TransactionItem>[]).add(item);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: <Widget>[
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Filter',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _SearchBar(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                _FilterChip(
                  label: 'All',
                  selected: _selectedFilter == 'All',
                  onTap: () => _updateFilter('All'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Income',
                  selected: _selectedFilter == 'Income',
                  onTap: () => _updateFilter('Income'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Expense',
                  selected: _selectedFilter == 'Expense',
                  onTap: () => _updateFilter('Expense'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (visibleItems.isEmpty)
              const _EmptyState()
            else ...<Widget>[
              ..._buildGroup(grouped, 'Today'),
              ..._buildGroup(grouped, 'Yesterday'),
              ..._buildGroup(grouped, 'Older'),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  List<_TransactionItem> _filteredItems() {
    final query = _searchController.text.trim().toLowerCase();

    return _items.where((item) {
      final matchesQuery = query.isEmpty || item.name.toLowerCase().contains(query);
      final matchesFilter = switch (_selectedFilter) {
        'Income' => !item.isExpense,
        'Expense' => item.isExpense,
        _ => true,
      };
      return matchesQuery && matchesFilter;
    }).toList();
  }

  List<Widget> _buildGroup(
    Map<String, List<_TransactionItem>> grouped,
    String title,
  ) {
    final sectionItems = grouped[title];
    if (sectionItems == null || sectionItems.isEmpty) return <Widget>[];

    return <Widget>[
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
      ),
      ...sectionItems.map(
        (item) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TransactionTile(
            title: item.name,
            dateTimeText: item.dateTimeText,
            amount: item.amount,
            isExpense: item.isExpense,
            icon: item.icon,
          ),
        ),
      ),
      const SizedBox(height: 4),
    ];
  }

  void _updateFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search transactions',
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      side: BorderSide(
        color: selected ? Colors.transparent : const Color(0xFFE5E7EB),
      ),
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF6E3EFF),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF374151),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.receipt_long_outlined,
            size: 44,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 10),
          const Text(
            'No transactions found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Try changing your search or filter.',
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

class _TransactionItem {
  const _TransactionItem({
    required this.name,
    required this.dateTimeText,
    required this.amount,
    required this.isExpense,
    required this.group,
    required this.icon,
  });

  final String name;
  final String dateTimeText;
  final String amount;
  final bool isExpense;
  final String group;
  final IconData icon;
}
