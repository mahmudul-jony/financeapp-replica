import 'package:flutter/material.dart';
import 'package:financeapp/app_constants.dart';
import 'package:financeapp/screens/banking_dashboard_screen.dart';
import 'package:financeapp/screens/signin_screen.dart';
import 'package:financeapp/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:financeapp/providers/finance_provider.dart';
import 'package:financeapp/providers/update_provider.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()..initialize()),
        ChangeNotifierProvider(create: (_) => FinanceProvider()),
        ChangeNotifierProvider(create: (_) => UpdateProvider()),
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
      navigatorObservers: [routeObserver],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.graphPurple,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.backgroundWhite,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    if (authService.isInitializing) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundWhite,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryPurple),
        ),
      );
    }

    // Direct to homepage if user is authenticated OR if the app opened without internet
    if (authService.isAuthenticated || authService.isOfflineAtLaunch) {
      return const BankingDashboardScreen();
    }

    return const SignInScreen();
  }
}
