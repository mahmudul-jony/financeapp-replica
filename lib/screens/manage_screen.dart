import 'package:flutter/material.dart';
import 'package:financeapp/app_constants.dart';
import 'package:financeapp/screens/wallet_forms.dart';
import 'package:financeapp/widgets/app_components.dart';
import 'package:financeapp/widgets/account_card.dart';
import 'package:financeapp/models/account_model.dart';
import 'package:provider/provider.dart';
import 'package:financeapp/providers/finance_provider.dart';

class ManageScreen extends StatelessWidget {
  const ManageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final wallets = provider.wallets;

    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primaryText, size: 20), 
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('All Wallets', style: AppTypography.title),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: AppButton(
              label: 'Add Wallet', 
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateWalletScreen())),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: wallets.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final w = wallets[index];
                final cardData = AccountCardData(
                  bankName: w.name,
                  balance: AppFormat.currency(w.balance),
                  frozenAmount: AppFormat.currency(w.frozenAmount),
                  maskedNumber: w.isDefault ? 'Default Wallet' : 'Personal Wallet',
                  accent: Color(w.color),
                );

                return Stack(
                  children: [
                    AccountCard(data: cardData),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Row(
                        children: [
                          AppEditIconButton(
                            color: Colors.white,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditWalletScreen(wallet: w))),
                          ),
                        ],
                      ),
                    ),
                    // If it's archived, overlay a label
                    if (w.isArchived)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: AppRadius.borderRadiusLarge,
                          ),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'ARCHIVED',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: 1.2),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
