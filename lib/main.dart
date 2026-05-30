import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

import 'features/expenses/providers/expense_provider.dart';
import 'features/expenses/presentation/screens/home_screen.dart';
import 'features/sms/providers/sms_tracking_provider.dart';
import 'features/sms/services/sms_debug_bootstrap.dart';
import 'features/sms/services/sms_incoming_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('DB path: ${await getDatabasesPath()}');

  await bootstrapSmsDebugListener();

  runApp(
    MultiProvider(
      providers: <ChangeNotifierProvider<dynamic>>[
        ChangeNotifierProvider<ExpenseProvider>(
          create: (_) => ExpenseProvider()..initialize(),
        ),
        ChangeNotifierProvider<SmsTrackingProvider>(
          create: (_) => SmsTrackingProvider()..loadPreference(),
        ),
      ],
      child: const _AppRoot(),
    ),
  );
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _wireSmsRefresh());
  }

  void _wireSmsRefresh() {
    SmsIncomingHandler.instance.onTransactionSaved = () async {
      if (!mounted) return;
      await context.read<ExpenseProvider>().fetchExpenses();
    };
  }

  @override
  Widget build(BuildContext context) {
    return const ExpenseTrackerApp();
  }
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
    );
  }
}
