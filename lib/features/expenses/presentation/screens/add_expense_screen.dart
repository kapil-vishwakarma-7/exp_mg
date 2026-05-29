import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/expense.dart';
import '../../providers/expense_provider.dart';
import '../widgets/add_amount_input.dart';
import '../widgets/category_chip_selector.dart';
import '../widgets/expense_date_picker.dart';
import '../widgets/expense_note_input.dart';
import '../widgets/gradient_save_button.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddExpenseScreen(),
    );
  }

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _amountFocusNode = FocusNode();
  String _selectedCategory = _categories.first.label;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  static const List<CategoryItem> _categories = <CategoryItem>[
    CategoryItem(label: 'Food', icon: Icons.restaurant_outlined),
    CategoryItem(label: 'Travel', icon: Icons.directions_car_outlined),
    CategoryItem(label: 'Bills', icon: Icons.receipt_long_outlined),
    CategoryItem(label: 'Shopping', icon: Icons.shopping_bag_outlined),
    CategoryItem(label: 'Others', icon: Icons.category_outlined),
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  String? _validateInput() {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      return 'Enter amount';
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      return 'Enter a valid amount';
    }

    if (_selectedCategory.isEmpty) {
      return 'Select a category';
    }

    return null;
  }

  Future<void> _save() async {
    final validationError = _validateInput();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    final expense = Expense(
      amount: double.parse(_amountController.text.trim()),
      category: _selectedCategory,
      note: _noteController.text.trim(),
      date: _selectedDate,
    );

    setState(() {
      _isSaving = true;
    });

    final saved = await context.read<ExpenseProvider>().addExpense(expense);

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save expense')),
      );
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFF6F7FB),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Add Expense',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: const Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.all(16),
                shrinkWrap: true,
                children: <Widget>[
                  AddAmountInput(
                    controller: _amountController,
                    focusNode: _amountFocusNode,
                  ),
                  const SizedBox(height: 20),
                  CategoryChipSelector(
                    categories: _categories,
                    selectedCategory: _selectedCategory,
                    onSelected: (value) {
                      setState(() {
                        _selectedCategory = value;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  ExpenseNoteInput(controller: _noteController),
                  const SizedBox(height: 14),
                  ExpenseDatePicker(
                    date: _selectedDate,
                    onTap: _pickDate,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GradientSaveButton(
                label: _isSaving ? 'Saving...' : 'Save Expense',
                onTap: _isSaving ? () {} : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
