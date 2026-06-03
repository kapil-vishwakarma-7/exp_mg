import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

import '../../../../features/sms/models/detected_subscription.dart';
import '../../models/expense.dart';
import '../../providers/expense_provider.dart';
import '../utils/expense_ui_helpers.dart';
import '../widgets/transaction_detail_sheet.dart';
import '../widgets/transaction_tile.dart';
import 'edit_expense_sheet.dart';
import 'subscriptions_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();

  // 'All' | 'Expense' | 'Income' | 'Subscriptions'
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

  // ── Detail sheet ──────────────────────────────────────────────────────────

  void _openDetail(
    BuildContext context,
    Expense expense,
    List<DetectedSubscription> allSubs,
    List<Expense> allExpenses,
  ) {
    DetectedSubscription? sub;
    if (expense.isSubscription && expense.subscriptionId != null) {
      try {
        sub = allSubs.firstWhere((s) => s.id == expense.subscriptionId);
      } catch (_) {}
    }

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

  // ── Delete with undo ──────────────────────────────────────────────────────

  Future<void> _deleteWithUndo(
    BuildContext context,
    Expense expense,
    ExpenseProvider provider,
  ) async {
    if (expense.id == null) return;

    // Optimistic delete.
    await provider.deleteExpense(expense.id!);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Deleted "${expenseDisplayTitle(expense)}"',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () async {
            await provider.restoreExpense(expense);
          },
        ),
      ),
    );
  }

  // ── Edit sheet ────────────────────────────────────────────────────────────

  Future<void> _openEdit(BuildContext context, Expense expense) async {
    await EditExpenseSheet.show(context, expense: expense);
  }

  // ── Filtering ─────────────────────────────────────────────────────────────

  List<Expense> _filteredItems(List<Expense> expenses) {
    final query = _searchController.text.trim().toLowerCase();
    return expenses.where((e) {
      final title = expenseDisplayTitle(e).toLowerCase();
      final category = e.category.toLowerCase();
      final matchesQuery =
          query.isEmpty || title.contains(query) || category.contains(query);
      final matchesFilter = switch (_selectedFilter) {
        'Income' => e.isCredit,
        'Expense' => e.isDebit,
        'Subscriptions' => e.isSubscription,
        _ => true,
      };
      return matchesQuery && matchesFilter;
    }).toList();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: <Widget>[
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
          builder: (context, provider, _) {
            final visibleItems = _filteredItems(provider.expenses);

            // Group into ordered buckets for section headers.
            final today = <Expense>[];
            final yesterday = <Expense>[];
            final older = <Expense>[];

            for (final e in visibleItems) {
              switch (dateGroupLabel(e.date)) {
                case 'Today':
                  today.add(e);
                case 'Yesterday':
                  yesterday.add(e);
                default:
                  older.add(e);
              }
            }

            // Build a flat list of items with section-header sentinels.
            // Each entry is either a String (header) or an Expense (tile).
            final flatItems = <Object>[
              if (today.isNotEmpty) ...['Today', ...today],
              if (yesterday.isNotEmpty) ...['Yesterday', ...yesterday],
              if (older.isNotEmpty) ...['Older', ...older],
            ];

            return Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    children: <Widget>[
                      _SearchBar(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      _FilterRow(
                        selected: _selectedFilter,
                        onChanged: (f) =>
                            setState(() => _selectedFilter = f),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (provider.isLoading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (visibleItems.isEmpty)
                  const Expanded(child: _EmptyState())
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      // Disable Slidable controller caching between scrolls.
                      itemCount: flatItems.length,
                      itemBuilder: (context, index) {
                        final item = flatItems[index];

                        // Section header
                        if (item is String) {
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: 10,
                              top: 4,
                            ),
                            child: Text(
                              item,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                              ),
                            ),
                          );
                        }

                        // Transaction tile with slide actions
                        final expense = item as Expense;
                        DetectedSubscription? sub;
                        if (expense.isSubscription &&
                            expense.subscriptionId != null) {
                          try {
                            sub = provider.subscriptions.firstWhere(
                              (s) => s.id == expense.subscriptionId,
                            );
                          } catch (_) {}
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _SlidableTile(
                            expense: expense,
                            sub: sub,
                            onTap: () => _openDetail(
                              context,
                              expense,
                              provider.subscriptions,
                              provider.expenses,
                            ),
                            onEdit: () =>
                                _openEdit(context, expense),
                            onDelete: () => _deleteWithUndo(
                              context,
                              expense,
                              provider,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Slidable tile ─────────────────────────────────────────────────────────────

class _SlidableTile extends StatelessWidget {
  const _SlidableTile({
    required this.expense,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.sub,
  });

  final Expense expense;
  final DetectedSubscription? sub;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: ValueKey<int?>(expense.id),
      // ── Swipe right → Edit ───────────────────────────────────────────────
      startActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.22,
        children: <Widget>[
          CustomSlidableAction(
            onPressed: (_) => onEdit(),
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.transparent,
            padding: EdgeInsets.zero,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.edit_rounded, color: Colors.white, size: 22),
                    SizedBox(height: 4),
                    Text(
                      'Edit',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      // ── Swipe left → Delete ──────────────────────────────────────────────
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.22,
        children: <Widget>[
          CustomSlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.transparent,
            padding: EdgeInsets.zero,
            child: Container(
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE44B75),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.delete_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Delete',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      child: TransactionTile(
        title: expenseDisplayTitle(expense),
        dateTimeText: formatExpenseDateTime(expense.date),
        amount: expense.isDebit
            ? '-${formatExpenseAmount(expense.amount)}'
            : '+${formatExpenseAmount(expense.amount)}',
        isExpense: expense.isDebit,
        icon: categoryIcon(expense.category),
        isSubscription: expense.isSubscription,
        subscriptionFrequency:
            sub?.frequency ?? expense.subscriptionFrequency,
        nextDueDate: sub?.nextDueDate,
        confidenceScore: sub?.confidenceScore,
        onTap: onTap,
      ),
    );
  }
}

// ── Filter row ────────────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  static const List<(String, IconData?)> _filters = <(String, IconData?)>[
    ('All', null),
    ('Expense', null),
    ('Income', null),
    ('Subscriptions', Icons.repeat_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _filters.map(((String, IconData?) item) {
          final label = item.$1;
          final icon = item.$2;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _FilterChip(
              label: label,
              selected: selected == label,
              leadingIcon: icon,
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
                color: selected
                    ? Colors.white
                    : cs.onSurface.withValues(alpha: 0.7),
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
  const _SearchBar({required this.controller, required this.onChanged});

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

    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              style:
                  TextStyle(color: cs.onSurface.withValues(alpha: 0.55)),
            ),
          ],
        ),
      ),
    );
  }
}
