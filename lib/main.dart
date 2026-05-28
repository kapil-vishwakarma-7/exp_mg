import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/expenses/data/expense_database.dart';
import 'features/expenses/data/expense_repository.dart';
import 'features/expenses/presentation/providers/expense_provider.dart';
import 'features/expenses/presentation/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = ExpenseRepository(ExpenseDatabase.instance);

  runApp(ExpenseTrackerApp(repository: repository));
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key, required this.repository});

  final ExpenseRepository repository;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ExpenseProvider>(
      create: (_) => ExpenseProvider(repository: repository)..loadExpenses(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Expense Tracker',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          scaffoldBackgroundColor: const Color(0xFFF7F8FA),
          useMaterial3: true,
          cardTheme: const CardThemeData(
            elevation: 0,
            color: Colors.white,
            margin: EdgeInsets.zero,
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
