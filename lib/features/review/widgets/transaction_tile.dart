import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../models/transaction_model.dart';
import '../providers/transaction_providers.dart';

/// A single transaction row with swipe-to-confirm (right) and
/// swipe-to-ignore (left) actions via [Slidable].
///
/// Pending tiles are visually muted; confirmed tiles render normally.
class TransactionTile extends ConsumerWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
  });

  final TransactionModel transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isPending = transaction.isPending;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Slidable(
        key: ValueKey<int>(transaction.id),

        // ── Swipe right → Confirm ──────────────────────────────────────────
        startActionPane: isPending
            ? ActionPane(
                motion: const BehindMotion(),
                extentRatio: 0.28,
                children: <Widget>[
                  CustomSlidableAction(
                    onPressed: (_) => _confirm(context, ref),
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.transparent,
                    padding: EdgeInsets.zero,
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0FA968),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.check_rounded,
                                color: Colors.white, size: 24),
                            SizedBox(height: 4),
                            Text(
                              'Confirm',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : null,

        // ── Swipe left → Ignore (pending) or Delete (confirmed) ────────────
        endActionPane: isPending
            ? ActionPane(
                motion: const BehindMotion(),
                extentRatio: 0.28,
                children: <Widget>[
                  CustomSlidableAction(
                    onPressed: (_) => _ignore(context, ref),
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.transparent,
                    padding: EdgeInsets.zero,
                    child: Container(
                      margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE44B75),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.close_rounded,
                                color: Colors.white, size: 24),
                            SizedBox(height: 4),
                            Text(
                              'Ignore',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : null,

        // ── Tile body ──────────────────────────────────────────────────────
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            // Pending: muted surface; Confirmed: normal card surface
            color: isPending
                ? cs.surfaceContainerHighest.withValues(alpha: 0.5)
                : cs.surface,
            borderRadius: BorderRadius.circular(12),
            border: isPending
                ? Border.all(
                    color: const Color(0xFFE07B00).withValues(alpha: 0.3),
                  )
                : null,
            boxShadow: isPending
                ? null
                : <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Row(
            children: <Widget>[
              // ── Left: icon ───────────────────────────────────────────────
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isPending
                      ? const Color(0xFFE07B00).withValues(alpha: 0.1)
                      : cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPending
                      ? Icons.help_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  color: isPending ? const Color(0xFFE07B00) : cs.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // ── Centre: merchant + amount ─────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      transaction.merchant,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isPending
                            ? cs.onSurface.withValues(alpha: 0.55)
                            : cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      transaction.formattedAmount,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isPending
                            ? const Color(0xFFE44B75).withValues(alpha: 0.6)
                            : const Color(0xFFE44B75),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Right: date + pending badge ───────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    transaction.shortDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  if (isPending) ...<Widget>[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFFE07B00).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Pending',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE07B00),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Action handlers ───────────────────────────────────────────────────────

  void _confirm(BuildContext context, WidgetRef ref) {
    ref.read(transactionControllerProvider.notifier).confirm(transaction.id);
    _showSnack(context, '✔ Added to expenses', const Color(0xFF0FA968));
  }

  void _ignore(BuildContext context, WidgetRef ref) {
    ref.read(transactionControllerProvider.notifier).ignore(transaction.id);
    _showSnack(
      context,
      'Transaction ignored',
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
    );
  }

  void _showSnack(BuildContext context, String message, Color bgColor) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: bgColor,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
  }
}
