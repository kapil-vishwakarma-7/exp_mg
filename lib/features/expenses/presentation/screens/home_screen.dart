import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/expense_provider.dart';
import '../utils/expense_ui_helpers.dart';
import 'add_expense_screen.dart';
import 'analytics_screen.dart';
import 'profile_screen.dart';
import 'transactions_screen.dart';
import '../widgets/balance_card.dart';
import '../widgets/payment_card.dart';
import '../widgets/transaction_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExpenseProvider>().fetchExpenses();
    });
  }

  Future<void> _openAddExpense() async {
    await AddExpenseScreen.show(context);
    if (!mounted) return;
    await context.read<ExpenseProvider>().fetchExpenses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Hello, Kapil!',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF121826),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Track your money, stay in control',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                _RoundIconButton(icon: Icons.search_rounded, onTap: () {}),
                const SizedBox(width: 10),
                _RoundIconButton(
                  icon: Icons.notifications_none_rounded,
                  onTap: () {},
                  showDot: true,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Consumer<ExpenseProvider>(
              builder: (context, provider, child) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    BalanceCard(
                      title: 'Total Spent',
                      amount: formatExpenseAmount(provider.totalAmount),
                      onAddTap: _openAddExpense,
                    ),
                    const SizedBox(height: 24),
                    const _SectionHeader(
                      title: 'Upcoming Payments',
                      actionText: 'See all',
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 210,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: const <Widget>[
                          PaymentCard(
                            appName: 'Adobe Premium',
                            pricePerMonth: '₹2,499',
                            daysLeft: '2 days left',
                            isHighlighted: true,
                            icon: Icons.change_history_rounded,
                          ),
                          SizedBox(width: 12),
                          PaymentCard(
                            appName: 'Apple Premium',
                            pricePerMonth: '₹249',
                            daysLeft: '2 days left',
                            icon: Icons.apple_rounded,
                          ),
                          SizedBox(width: 12),
                          PaymentCard(
                            appName: 'Spotify',
                            pricePerMonth: '₹119',
                            daysLeft: '5 days left',
                            icon: Icons.music_note_rounded,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SectionHeader(
                      title: 'Recent Transactions',
                      actionText: 'See all',
                      onActionTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const TransactionsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    _ExpenseListSection(provider: provider),
                  ],
                );
              },
            ),
            const SizedBox(height: 88),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFF6E3EFF).withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _openAddExpense,
          backgroundColor: const Color(0xFF6E3EFF),
          shape: const CircleBorder(),
          child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: Colors.white,
        elevation: 2,
        child: SizedBox(
          height: 68,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              _BottomNavItem(icon: Icons.home_rounded, selected: true),
              _BottomNavItem(
                icon: Icons.account_balance_wallet_outlined,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TransactionsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 40),
              _BottomNavItem(
                icon: Icons.bar_chart_rounded,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AnalyticsScreen(),
                    ),
                  );
                },
              ),
              _BottomNavItem(
                icon: Icons.person_outline_rounded,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ProfileScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpenseListSection extends StatelessWidget {
  const _ExpenseListSection({required this.provider});

  final ExpenseProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (provider.expenses.isEmpty) {
      return const _RecentEmptyState();
    }

    return Column(
      children: provider.expenses
          .map(
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
          )
          .toList(),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(icon, color: const Color(0xFF111827), size: 24),
            ),
          ),
        ),
        if (showDot)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

class _RecentEmptyState extends StatelessWidget {
  const _RecentEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          const Text(
            'No expenses yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap + to add your first expense.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionText,
    this.onActionTap,
  });

  final String title;
  final String actionText;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFF121826),
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: onActionTap,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            actionText,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    this.selected = false,
    this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap ?? () {},
      icon: Icon(
        icon,
        size: 26,
        color: selected ? const Color(0xFF6E3EFF) : const Color(0xFF7C8596),
      ),
    );
  }
}
