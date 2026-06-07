import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../features/sms/models/detected_subscription.dart';
import '../../models/expense.dart';
import '../../providers/expense_provider.dart';
import '../widgets/category_chip_selector.dart';
import '../widgets/expense_date_picker.dart';
import '../widgets/expense_note_input.dart';
import '../widgets/gradient_save_button.dart';

/// Pre-filled bottom sheet editor for an existing [Expense].
///
/// When the expense is a subscription, an extra "Recurring Payment" section
/// is shown that lets the user edit frequency and next due date.
class EditExpenseSheet extends StatefulWidget {
  const EditExpenseSheet({super.key, required this.expense});

  final Expense expense;

  static Future<void> show(BuildContext context, {required Expense expense}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditExpenseSheet(expense: expense),
    );
  }

  @override
  State<EditExpenseSheet> createState() => _EditExpenseSheetState();
}

class _EditExpenseSheetState extends State<EditExpenseSheet> {
  // ── Standard fields ───────────────────────────────────────────────────────
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late String _selectedCategory;
  late DateTime _selectedDate;

  // ── Subscription fields (only used when expense.isSubscription) ───────────
  DetectedSubscription? _linkedSubscription;
  late String _frequency;
  late DateTime _nextDueDate;

  bool _isSaving = false;

  static const List<String> _frequencies = <String>[
    'monthly',
    'weekly',
    'yearly',
    'quarterly',
  ];

  static const List<CategoryItem> _categories = <CategoryItem>[
    CategoryItem(label: 'Food', icon: Icons.restaurant_outlined),
    CategoryItem(label: 'Travel', icon: Icons.directions_car_outlined),
    CategoryItem(label: 'Bills', icon: Icons.receipt_long_outlined),
    CategoryItem(label: 'Shopping', icon: Icons.shopping_bag_outlined),
    CategoryItem(label: 'Entertainment', icon: Icons.movie_outlined),
    CategoryItem(label: 'Groceries', icon: Icons.local_grocery_store_outlined),
    CategoryItem(label: 'Others', icon: Icons.category_outlined),
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.expense;

    _amountController = TextEditingController(text: e.amount.toStringAsFixed(2));
    _noteController = TextEditingController(text: e.note);
    _selectedCategory =
        _categories.any((c) => c.label == e.category) ? e.category : 'Others';
    _selectedDate = e.date;

    // Pre-fill subscription fields from what the Expense already knows.
    _frequency = e.subscriptionFrequency ?? 'monthly';
    _nextDueDate = _computeNextDue(e.date, _frequency);

    // Load the linked DetectedSubscription (if any) after first frame so
    // we can read the provider.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSubscription());
  }

  void _loadSubscription() {
    if (!widget.expense.isSubscription ||
        widget.expense.subscriptionId == null) return;
    final provider = context.read<ExpenseProvider>();
    try {
      final sub = provider.subscriptions
          .firstWhere((s) => s.id == widget.expense.subscriptionId);
      setState(() {
        _linkedSubscription = sub;
        _frequency = sub.frequency;
        _nextDueDate = sub.nextDueDate;
      });
    } catch (_) {
      // Subscription not yet in the in-memory list — keep defaults.
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String? _validate() {
    final text = _amountController.text.trim();
    if (text.isEmpty) return 'Enter amount';
    final amount = double.tryParse(text);
    if (amount == null || amount <= 0) return 'Enter a valid amount';
    return null;
  }

  String _frequencyLabel(String f) {
    switch (f) {
      case 'weekly':
        return 'Weekly';
      case 'yearly':
        return 'Yearly';
      case 'quarterly':
        return 'Quarterly';
      default:
        return 'Monthly';
    }
  }

  DateTime _computeNextDue(DateTime from, String freq) {
    switch (freq) {
      case 'weekly':
        return from.add(const Duration(days: 7));
      case 'quarterly':
        return DateTime(from.year, from.month + 3, from.day);
      case 'yearly':
        return DateTime(from.year + 1, from.month, from.day);
      default: // monthly
        return DateTime(from.year, from.month + 1, from.day);
    }
  }

  Future<void> _pickNextDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _nextDueDate = picked);
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    final note = _noteController.text.trim();
    final newAmount = double.parse(_amountController.text.trim());

    final updatedExpense = widget.expense.copyWith(
      title: note.isEmpty ? _selectedCategory : note,
      amount: newAmount,
      category: _selectedCategory,
      note: note,
      date: _selectedDate,
      transactionTime: _selectedDate,
      subscriptionFrequency:
          widget.expense.isSubscription ? _frequency : null,
    );

    setState(() => _isSaving = true);
    bool ok;

    if (widget.expense.isSubscription && _linkedSubscription != null) {
      // Update both the expense and the linked subscription row.
      final updatedSub = _linkedSubscription!.copyWith(
        amount: newAmount,
        frequency: _frequency,
        nextDueDate: _nextDueDate,
        lastPaidDate: _selectedDate,
        confidenceScore: 'high', // user explicitly edited = high confidence
      );
      ok = await context.read<ExpenseProvider>().updateExpenseWithSubscription(
            updatedExpense,
            updatedSub,
          );
    } else {
      ok = await context.read<ExpenseProvider>().updateExpense(updatedExpense);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save changes')),
      );
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // ── Handle ───────────────────────────────────────────────────────
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),

            // ── Header ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          'Edit Transaction',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        if (widget.expense.isSubscription) ...<Widget>[
                          const SizedBox(width: 8),
                          Icon(Icons.repeat_rounded,
                              size: 18, color: cs.primary),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),

            // ── Scrollable fields ─────────────────────────────────────────────
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                shrinkWrap: true,
                children: <Widget>[
                  // Amount
                  TextField(
                    controller: _amountController,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: '₹0',
                      hintStyle: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Category
                  CategoryChipSelector(
                    categories: _categories,
                    selectedCategory: _selectedCategory,
                    onSelected: (v) => setState(() => _selectedCategory = v),
                  ),
                  const SizedBox(height: 20),

                  // Note
                  ExpenseNoteInput(controller: _noteController),
                  const SizedBox(height: 14),

                  // Date
                  ExpenseDatePicker(date: _selectedDate, onTap: _pickDate),

                  // ── Recurring Payment section ─────────────────────────────
                  if (widget.expense.isSubscription) ...<Widget>[
                    const SizedBox(height: 20),
                    _RecurringSection(
                      frequency: _frequency,
                      nextDueDate: _nextDueDate,
                      frequencies: _frequencies,
                      frequencyLabel: _frequencyLabel,
                      onFrequencyChanged: (f) => setState(() {
                        _frequency = f;
                        // Recompute next due when frequency changes.
                        _nextDueDate = _computeNextDue(_selectedDate, f);
                      }),
                      onPickNextDue: _pickNextDueDate,
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),

            // ── Save button ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GradientSaveButton(
                label: _isSaving ? 'Saving…' : 'Save Changes',
                onTap: _isSaving ? () {} : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recurring Payment section widget ─────────────────────────────────────────

class _RecurringSection extends StatelessWidget {
  const _RecurringSection({
    required this.frequency,
    required this.nextDueDate,
    required this.frequencies,
    required this.frequencyLabel,
    required this.onFrequencyChanged,
    required this.onPickNextDue,
  });

  final String frequency;
  final DateTime nextDueDate;
  final List<String> frequencies;
  final String Function(String) frequencyLabel;
  final ValueChanged<String> onFrequencyChanged;
  final VoidCallback onPickNextDue;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Section header
          Row(
            children: <Widget>[
              Icon(Icons.repeat_rounded, size: 16, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                'Recurring Payment',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Frequency label
          Text(
            'Billing Frequency',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 8),

          // Frequency chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: frequencies.map((f) {
              final selected = frequency == f;
              return GestureDetector(
                onTap: () => onFrequencyChanged(f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? cs.primary : cs.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? Colors.transparent
                          : cs.outlineVariant,
                    ),
                  ),
                  child: Text(
                    frequencyLabel(f),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.white
                          : cs.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Next due date
          Text(
            'Next Due Date',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: onPickNextDue,
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    DateFormat('dd MMM yyyy').format(nextDueDate),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
