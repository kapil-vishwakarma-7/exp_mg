import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderScope; // only ProviderScope needed here
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

import 'features/expenses/providers/expense_provider.dart';
import 'features/expenses/providers/theme_provider.dart';
import 'features/expenses/providers/user_provider.dart';
import 'features/expenses/presentation/screens/home_screen.dart';
import 'features/sms/providers/sms_tracking_provider.dart';
import 'features/sms/services/sms_debug_bootstrap.dart';
import 'features/sms/services/sms_incoming_handler.dart';
import 'features/sms/services/sms_rule_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('DB path: ${await getDatabasesPath()}');

  // Load SMS rules (cache → asset) before the first parse can happen.
  // The subsequent remote sync runs in the background and does not block startup.
  await SmsRuleRepository.instance.initialize();

  await bootstrapSmsDebugListener();

  runApp(
    // ProviderScope is required by flutter_riverpod. It sits above
    // MultiProvider so both Riverpod and Provider can coexist.
    ProviderScope(
      child: MultiProvider(
      providers: <ChangeNotifierProvider<dynamic>>[
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider<UserProvider>(
          create: (_) => UserProvider(),
        ),
        ChangeNotifierProvider<ExpenseProvider>(
          create: (_) => ExpenseProvider()..initialize(),
        ),
        ChangeNotifierProvider<SmsTrackingProvider>(
          create: (_) => SmsTrackingProvider()..loadPreference(),
        ),
      ],
      child: const _AppRoot(),
      ),
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _wireSmsRefresh();
      context.read<UserProvider>().loadUser();
      context.read<ThemeProvider>().loadTheme();
    });
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

  // Shared seed colour used in both themes so the purple accent is consistent.
  static const Color _seed = Color(0xFF6E3EFF);

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeProvider>().themeMode;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Expense Tracker',
      themeMode: themeMode,
      // ── Light theme ──────────────────────────────────────────────────────
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.light,
          surface: const Color(0xFFF6F7FB),
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          elevation: 0,
          color: Colors.white,
          margin: EdgeInsets.zero,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF6F7FB),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        bottomAppBarTheme: const BottomAppBarThemeData(
          color: Colors.white,
          elevation: 2,
        ),
      ),
      // ── Dark theme ───────────────────────────────────────────────────────
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
          surface: const Color(0xFF1C1C1E),
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        bottomAppBarTheme: const BottomAppBarThemeData(
          color: Color(0xFF1C1C1E),
          elevation: 2,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
