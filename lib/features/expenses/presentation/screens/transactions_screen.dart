import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/expense.dart';
import '../../providers/expense_provider.dart';
import '../utils/expense_ui_helpers.dart';
import '../widgets/transaction_tile.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExpenseProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
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
        child: Consumer<ExpenseProvider>(
          builder: (context, provider, child) {
            final visibleItems = _filteredItems(provider.expenses);
            final grouped = <String, List<Expense>>{};
            for (final item in visibleItems) {
              grouped
                  .putIfAbsent(dateGroupLabel(item.date), () => <Expense>[])
                  .add(item);
            }

            return ListView(
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
                if (provider.isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (visibleItems.isEmpty)
                  const _EmptyState()
                else ...<Widget>[
                  ..._buildGroup(grouped, 'Today', cs),
                  ..._buildGroup(grouped, 'Yesterday', cs),
                  ..._buildGroup(grouped, 'Older', cs),
                ],
                const SizedBox(height: 12),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Expense> _filteredItems(List<Expense> expenses) {
    final query = _searchController.text.trim().toLowerCase();

    return expenses.where((expense) {
      final title = expenseDisplayTitle(expense).toLowerCase();
      final category = expense.category.toLowerCase();
      final matchesQuery =
          query.isEmpty || title.contains(query) || category.contains(query);
      final matchesFilter = switch (_selectedFilter) {
        'Income' => false,
        'Expense' => true,
        _ => true,
      };
      return matchesQuery && matchesFilter;
    }).toList();
  }

  List<Widget> _buildGroup(
    Map<String, List<Expense>> grouped,
    String title,
    ColorScheme cs,
  ) {
    final sectionItems = grouped[title];
    if (sectionItems == null || sectionItems.isEmpty) return <Widget>[];

    return <Widget>[
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
      ),
      ...sectionItems.map(
        (expense) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TransactionTile(
            title: expenseDisplayTitle(expense),
            dateTimeText: formatExpenseDateTime(expense.date),
            amount: '-${formatExpenseAmount(expense.amount)}',
            isExpense: true,
            icon: categoryIcon(expense.category),
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
    final cs = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search transactions',
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: cs.surface,
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
    final cs = Theme.of(context).colorScheme;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      side: BorderSide(
        color: selected ? Colors.transparent : cs.outlineVariant,
      ),
      backgroundColor: cs.surface,
      selectedColor: cs.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : cs.onSurface,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.receipt_long_outlined,
            size: 44,
            color: cs.onSurface.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 10),
          Text(
            'No transactions found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try changing your search or filter.',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.55)),
          ),
        ],
      ),
    );
  }
}
