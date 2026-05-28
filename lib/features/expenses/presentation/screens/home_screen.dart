import 'package:flutter/material.dart';

import 'add_expense_screen.dart';
import 'analytics_screen.dart';
import 'profile_screen.dart';
import 'transactions_screen.dart';
import '../widgets/balance_card.dart';
import '../widgets/payment_card.dart';
import '../widgets/transaction_tile.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Future<void> openAddExpense() async {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const AddExpenseScreen(),
        ),
      );
    }

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
            BalanceCard(
              title: 'Current Balance',
              amount: '₹45,700',
              onAddTap: openAddExpense,
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
            const _SectionHeader(
              title: 'Recent Transactions',
              actionText: 'See all',
            ),
            const SizedBox(height: 14),
            const TransactionTile(
              title: 'Apple Inc.',
              dateTimeText: '21 Sep, 03:02 PM',
              amount: '-₹230.50',
              isExpense: true,
              icon: Icons.apple_rounded,
            ),
            const SizedBox(height: 10),
            const TransactionTile(
              title: 'Adobe',
              dateTimeText: '21 Sep, 03:22 PM',
              amount: '-₹130.50',
              isExpense: true,
              icon: Icons.change_history_rounded,
            ),
            const SizedBox(height: 10),
            const TransactionTile(
              title: 'Amazon',
              dateTimeText: '21 Sep, 02:02 PM',
              amount: '-₹20.50',
              isExpense: true,
              icon: Icons.shopping_bag_outlined,
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
          onPressed: openAddExpense,
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.actionText});

  final String title;
  final String actionText;

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
          onPressed: () {},
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
