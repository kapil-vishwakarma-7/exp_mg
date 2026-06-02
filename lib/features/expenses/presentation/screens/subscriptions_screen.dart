import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../features/sms/models/detected_subscription.dart';
import '../../providers/expense_provider.dart';
import '../utils/expense_ui_helpers.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  List<DetectedSubscription> _subscriptions = <DetectedSubscription>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final subs =
        await context.read<ExpenseProvider>().loadUpcomingSubscriptions(
              daysAhead: 365 * 5, // fetch all active — UI groups them
            );
    if (!mounted) return;
    setState(() {
      _subscriptions = subs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Subscriptions')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _subscriptions.isEmpty
              ? _EmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _subscriptions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return _SubscriptionCard(
                      sub: _subscriptions[index],
                    );
                  },
                ),
    );
  }
}

// ── Subscription card ─────────────────────────────────────────────────────────

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.sub});

  final DetectedSubscription sub;

  bool get _isDueSoon {
    final days = sub.nextDueDate.difference(DateTime.now()).inDays;
    return days >= 0 && days <= 3;
  }

  String get _frequencyLabel {
    final f = sub.frequency;
    return f[0].toUpperCase() + f.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nextDueStr = DateFormat('d MMM yyyy').format(sub.nextDueDate);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          // ── Icon ──────────────────────────────────────────────────────
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              categoryIcon(sub.category),
              color: cs.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),

          // ── Info block ─────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Merchant name
                Text(
                  sub.merchant,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                // Frequency + next due
                Row(
                  children: <Widget>[
                    Text(
                      '$_frequencyLabel • Next: $nextDueStr',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    if (_isDueSoon) ...<Widget>[
                      const SizedBox(width: 6),
                      Text(
                        '⚠ Due soon',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFE07B00),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // ── Amount ────────────────────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                formatExpenseAmount(sub.amount),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 3),
              _ConfidenceDot(score: sub.confidenceScore),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfidenceDot extends StatelessWidget {
  const _ConfidenceDot({required this.score});

  final String score;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (score) {
      case 'high':
        color = const Color(0xFF0FA968);
      case 'medium':
        color = Theme.of(context).colorScheme.primary;
      default:
        color = Theme.of(context).colorScheme.outlineVariant;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          score[0].toUpperCase() + score.substring(1),
          style: TextStyle(fontSize: 11, color: color),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.repeat_rounded,
              size: 56,
              color: cs.onSurface.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 14),
            Text(
              'No subscriptions detected',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Recurring payments will appear here\nonce detected from your SMS history.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
