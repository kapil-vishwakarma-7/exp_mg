import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/transaction_providers.dart';
import '../widgets/pending_section.dart';
import '../widgets/transaction_tile.dart';

/// Entry-point screen for the Riverpod-powered transaction review UI.
///
/// Wrap with [ProviderScope] (done once at the app level) before navigating here.
/// Displays pending transactions in a "Needs Review" section at the top,
/// followed by the confirmed transaction list below.
class TransactionScreen extends ConsumerWidget {
  const TransactionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final pending = ref.watch(pendingTransactionsProvider);
    final confirmed = ref.watch(confirmedTransactionsProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: <Widget>[
          // Badge showing pending count — disappears when all reviewed.
          if (pending.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE07B00),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${pending.length} pending',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: (pending.isEmpty && confirmed.isEmpty)
            ? _EmptyState()
            : ListView(
                children: <Widget>[
                  // ── Needs Review section ─────────────────────────────────
                  PendingSection(pending: pending),

                  // ── Confirmed section header ─────────────────────────────
                  if (confirmed.isNotEmpty)
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Text(
                        'Transactions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                    ),

                  // ── Confirmed tiles ──────────────────────────────────────
                  ...confirmed.map(
                    (tx) => TransactionTile(
                      key: ValueKey<int>(tx.id),
                      transaction: tx,
                    ),
                  ),

                  // Bottom breathing room
                  const SizedBox(height: 24),
                ],
              ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

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
              Icons.receipt_long_outlined,
              size: 56,
              color: cs.onSurface.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 14),
            Text(
              'No transactions yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'SMS-detected payments will appear here\nfor your review.',
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
