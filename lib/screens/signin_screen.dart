import 'package:flutter/material.dart';
import 'package:financeapp/app_constants.dart';
import 'package:financeapp/screens/banking_dashboard_screen.dart';
import 'package:financeapp/services/auth_service.dart';
import 'package:financeapp/widgets/update_checker.dart';
import 'package:provider/provider.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final isLoading = authService.isLoading;

    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            children: [
              const UpdateChecker(),
              const Spacer(),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple,
                  borderRadius: AppRadius.borderRadiusLarge,
                ),
                child: const Icon(Icons.wallet_rounded, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 32),
              const Text('FinanceApp', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -1)),
              const SizedBox(height: 8),
              const Text('Simple way to manage your finance', style: AppTypography.subTitle),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: TextButton.icon(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final success = await context.read<AuthService>().signIn();
                          if (context.mounted) {
                            if (success) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const BankingDashboardScreen()),
                              );
                            } else {
                              final error = context.read<AuthService>().errorMessage;
                              if (error != null && !error.toLowerCase().contains('cancelled')) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(error),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            }
                          }
                        },
                  icon: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryPurple),
                        )
                      : const Icon(Icons.login_rounded, color: AppColors.primaryPurple),
                  label: Text(
                    isLoading ? 'Signing in with Google...' : 'Continue with Google',
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.backgroundGrey,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.borderRadiusMedium),
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
