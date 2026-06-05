import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction_model.dart';
import 'transaction_tile.dart';

/// The "Needs Review" section shown at the top of the transaction list
/// when there are pending transactions awaiting user confirmation.
class PendingSection extends ConsumerWidget {
  const PendingSection({
    super.key,
    required this.pending,
  });

  final List<TransactionModel> pending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (pending.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // ── Header ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: <Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE07B00).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text('⚠️', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 5),
                    Text(
                      'Needs Review (${pending.length})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE07B00),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'Swipe to confirm or ignore',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),

        // ── Pending tiles ────────────────────────────────────────────────────
        ...pending.map(
          (tx) => TransactionTile(key: ValueKey<int>(tx.id), transaction: tx),
        ),

        // ── Divider before confirmed list ────────────────────────────────────
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Divider(height: 1),
        ),
      ],
    );
  }
}
