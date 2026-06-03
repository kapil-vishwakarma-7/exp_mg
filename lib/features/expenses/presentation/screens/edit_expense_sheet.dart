import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/expense.dart';
import '../../providers/expense_provider.dart';
import '../widgets/category_chip_selector.dart';
import '../widgets/expense_date_picker.dart';
import '../widgets/expense_note_input.dart';
import '../widgets/gradient_save_button.dart';

/// Pre-filled bottom sheet editor for an existing [Expense].
///
/// Opens via [EditExpenseSheet.show]. Saves changes through [ExpenseProvider]
/// and pops when done.
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
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late String _selectedCategory;
  late DateTime _selectedDate;
  bool _isSaving = false;

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
    _amountController =
        TextEditingController(text: e.amount.toStringAsFixed(2));
    _noteController = TextEditingController(text: e.note);
    // Find category in list; default to 'Others' if not found.
    _selectedCategory = _categories.any((c) => c.label == e.category)
        ? e.category
        : 'Others';
    _selectedDate = e.date;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ── Validation ────────────────────────────────────────────────────────────

  String? _validate() {
    final text = _amountController.text.trim();
    if (text.isEmpty) return 'Enter amount';
    final amount = double.tryParse(text);
    if (amount == null || amount <= 0) return 'Enter a valid amount';
    return null;
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    final note = _noteController.text.trim();
    final updated = widget.expense.copyWith(
      title: note.isEmpty ? _selectedCategory : note,
      amount: double.parse(_amountController.text.trim()),
      category: _selectedCategory,
      note: note,
      date: _selectedDate,
      transactionTime: _selectedDate,
    );

    setState(() => _isSaving = true);
    final ok =
        await context.read<ExpenseProvider>().updateExpense(updated);
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

  // ── Date picker ───────────────────────────────────────────────────────────

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
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.90,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // ── Drag handle ───────────────────────────────────────────────
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            // ── Header row ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Edit Transaction',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
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

            // ── Fields ────────────────────────────────────────────────────
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                shrinkWrap: true,
                children: <Widget>[
                  // Amount — large numeric input
                  TextField(
                    controller: _amountController,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
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

                  // Category chips
                  CategoryChipSelector(
                    categories: _categories,
                    selectedCategory: _selectedCategory,
                    onSelected: (v) =>
                        setState(() => _selectedCategory = v),
                  ),
                  const SizedBox(height: 20),

                  // Note
                  ExpenseNoteInput(controller: _noteController),
                  const SizedBox(height: 14),

                  // Date
                  ExpenseDatePicker(
                    date: _selectedDate,
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // ── Save button ───────────────────────────────────────────────
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
