import 'package:flutter/material.dart';
import '../widgets/add_amount_input.dart';
import '../widgets/category_chip_selector.dart';
import '../widgets/expense_date_picker.dart';
import '../widgets/expense_note_input.dart';
import '../widgets/gradient_save_button.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _amountFocusNode = FocusNode();
  String _selectedCategory = _categories.first.label;
  DateTime _selectedDate = DateTime.now();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Add Expense'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  const SizedBox(height: 8),
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
              padding: const EdgeInsets.all(16),
              child: GradientSaveButton(
                label: 'Save Expense',
                onTap: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
