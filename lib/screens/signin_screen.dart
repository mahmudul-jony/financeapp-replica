import 'package:flutter/material.dart';
import 'package:financeapp/app_constants.dart';
import 'package:financeapp/screens/banking_dashboard_screen.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            children: [
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
                  onPressed: () {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BankingDashboardScreen()));
                  },
                  icon: const Icon(Icons.login_rounded, color: AppColors.primaryPurple),
                  label: const Text('Continue with Google', style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w600, fontSize: 16)),
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
