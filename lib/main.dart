import 'package:flutter/material.dart';
import 'package:financeapp/app_constants.dart';
import 'package:financeapp/screens/signin_screen.dart';
import 'package:provider/provider.dart';
import 'package:financeapp/providers/finance_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FinanceProvider()),
      ],
      child: const BankingDashboardApp(),
    ),
  );
}

class BankingDashboardApp extends StatelessWidget {
  const BankingDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mobile Banking Dashboard',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.graphPurple,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.backgroundWhite,
        // Removed explicit fontFamily to use system default and avoid black screen issues
      ),
      home: const SignInScreen(),
    );
  }
}
