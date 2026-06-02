import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../features/sms/models/detected_subscription.dart';
import '../../models/expense.dart';
import '../../providers/expense_provider.dart';
import '../utils/expense_ui_helpers.dart';
import '../widgets/transaction_detail_sheet.dart';
import '../widgets/transaction_tile.dart';
import 'subscriptions_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();

  // 'All' | 'Income' | 'Expense' | 'Subscriptions'
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

  // ── Tap handler — open detail sheet ──────────────────────────────────────

  void _openDetail(
    BuildContext context,
    Expense expense,
    List<DetectedSubscription> allSubs,
    List<Expense> allExpenses,
  ) {
    // Find linked subscription if any.
    DetectedSubscription? sub;
    if (expense.isSubscription && expense.subscriptionId != null) {
      try {
        sub = allSubs.firstWhere((s) => s.id == expense.subscriptionId);
      } catch (_) {
        // Not found — sub stays null.
      }
    }

    // Collect last 3 payments from same merchant (excluding this one).
    final recentPayments = expense.merchant != null
        ? allExpenses
            .where(
              (e) =>
                  e.id != expense.id &&
                  e.merchant == expense.merchant &&
                  e.isDebit,
            )
            .take(3)
            .toList()
        : <Expense>[];

    TransactionDetailSheet.show(
      context,
      expense: expense,
      subscription: sub,
      recentPayments: recentPayments,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: <Widget>[
          // Quick link to Subscriptions screen
          IconButton(
            icon: const Icon(Icons.repeat_rounded),
            tooltip: 'Subscriptions',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SubscriptionsScreen(),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<ExpenseProvider>(
          builder: (context, provider, child) {
            final visibleItems =
                _filteredItems(provider.expenses);
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
                _FilterRow(
                  selected: _selectedFilter,
                  onChanged: (f) => setState(() => _selectedFilter = f),
                ),
                const SizedBox(height: 16),
                if (provider.isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (visibleItems.isEmpty)
                  const _EmptyState()
                else ...<Widget>[
                  ..._buildGroup(
                    grouped,
                    'Today',
                    cs,
                    provider,
                  ),
                  ..._buildGroup(
                    grouped,
                    'Yesterday',
                    cs,
                    provider,
                  ),
                  ..._buildGroup(
                    grouped,
                    'Older',
                    cs,
                    provider,
                  ),
                ],
                const SizedBox(height: 12),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Filtering ─────────────────────────────────────────────────────────────

  List<Expense> _filteredItems(List<Expense> expenses) {
    final query = _searchController.text.trim().toLowerCase();

    return expenses.where((expense) {
      final title = expenseDisplayTitle(expense).toLowerCase();
      final category = expense.category.toLowerCase();
      final matchesQuery =
          query.isEmpty || title.contains(query) || category.contains(query);

      final matchesFilter = switch (_selectedFilter) {
        'Income' => expense.isCredit,
        'Expense' => expense.isDebit,
        'Subscriptions' => expense.isSubscription,
        _ => true,
      };
      return matchesQuery && matchesFilter;
    }).toList();
  }

  // ── Group builder ─────────────────────────────────────────────────────────

  List<Widget> _buildGroup(
    Map<String, List<Expense>> grouped,
    String title,
    ColorScheme cs,
    ExpenseProvider provider,
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
      ...sectionItems.map((expense) {
        // Find linked subscription for tile display.
        DetectedSubscription? sub;
        if (expense.isSubscription && expense.subscriptionId != null) {
          try {
            sub = provider.subscriptions
                .firstWhere((s) => s.id == expense.subscriptionId);
          } catch (_) {
            // Not yet loaded — graceful degradation.
          }
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TransactionTile(
            title: expenseDisplayTitle(expense),
            dateTimeText: formatExpenseDateTime(expense.date),
            amount: expense.isDebit
                ? '-${formatExpenseAmount(expense.amount)}'
                : '+${formatExpenseAmount(expense.amount)}',
            isExpense: expense.isDebit,
            icon: categoryIcon(expense.category),
            isSubscription: expense.isSubscription,
            subscriptionFrequency: sub?.frequency ?? expense.subscriptionFrequency,
            nextDueDate: sub?.nextDueDate,
            confidenceScore: sub?.confidenceScore,
            onTap: () => _openDetail(
              context,
              expense,
              provider.subscriptions,
              provider.expenses,
            ),
          ),
        );
      }),
      const SizedBox(height: 4),
    ];
  }
}

// ── Filter row ────────────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  static const List<String> _filters = <String>[
    'All',
    'Expense',
    'Income',
    'Subscriptions',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _filters.map((label) {
          final isSelected = selected == label;
          final isSubFilter = label == 'Subscriptions';
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _FilterChip(
              label: label,
              selected: isSelected,
              leadingIcon: isSubFilter ? Icons.repeat_rounded : null,
              onTap: () => onChanged(label),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.leadingIcon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.transparent : cs.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (leadingIcon != null) ...<Widget>[
              Icon(
                leadingIcon,
                size: 14,
                color: selected ? Colors.white : cs.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

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

// ── Empty state ───────────────────────────────────────────────────────────────

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
