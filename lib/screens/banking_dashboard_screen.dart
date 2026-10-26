import 'package:flutter/material.dart';
import 'package:financeapp/app_constants.dart';
import 'package:financeapp/screens/manage_screen.dart';
import 'package:financeapp/screens/profile_screen.dart';
import 'package:financeapp/screens/analytics_dashboard_screen.dart';
import 'package:financeapp/screens/all_transactions_screen.dart';
import 'package:financeapp/screens/category_list_screen.dart';
import 'package:financeapp/widgets/summary_card.dart';
import 'package:financeapp/widgets/quick_actions.dart';
import 'package:provider/provider.dart';
import 'package:financeapp/providers/finance_provider.dart';
import 'package:financeapp/models/transaction_model.dart';
import 'package:financeapp/widgets/transaction_item.dart';
import 'package:financeapp/widgets/update_checker.dart';

class BankingDashboardScreen extends StatelessWidget {
  const BankingDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final wallets = provider.wallets;

    // Calculate Summary Data (Default to current month for the card)
    final now = DateTime.now();
    final double totalWithdrawable = wallets.fold(0, (sum, w) => sum + w.balance);
    
    final double totalExpense = provider.transactions
        .where((tx) => tx.type == TransactionType.expense && tx.date.month == now.month && tx.date.year == now.year)
        .fold(0.0, (sum, tx) => sum + tx.amount);

    final double lastWeekExp = provider.lastWeekExpense;
    final double thisWeekExp = provider.thisWeekExpense;
    
    double expenseChangePercentage = 0.0;
    if (lastWeekExp > 0) {
      expenseChangePercentage = thisWeekExp / lastWeekExp;
    } else if (thisWeekExp > 0) {
      expenseChangePercentage = 1.0;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Container(
            height: 400,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: AppColors.dashboardGradient,
                stops: AppColors.dashboardStops,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: () => provider.fetchAll(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 16, AppSpacing.screenPadding, 0),
                      child: Column(
                        children: [
                          const DashboardHeader(),
                          const SizedBox(height: 24),
                          const UpdateChecker(),
                          SummaryCard(
                            totalWithdrawable: totalWithdrawable,
                            totalExpense: totalExpense,
                            expenseChangePercentage: expenseChangePercentage,
                            onTapDashboard: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsDashboardScreen()));
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height * 0.6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(AppRadius.large),
                          topRight: Radius.circular(AppRadius.large),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 20,
                            offset: Offset(0, -5),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, 32, AppSpacing.screenPadding, 40),
                      child: Column(
                        children: [
                          QuickActionsGrid(),
                          const SizedBox(height: 32),
                          _buildRecentTransactions(context, provider),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(BuildContext context, FinanceProvider provider) {
    final transactions = provider.transactions.reversed.toList();
    final recentCount = transactions.length > 5 ? 5 : transactions.length;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Transactions', style: AppTypography.title),
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AllTransactionsScreen()));
              },
              child: const Text('See all', style: TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 0),
        if (transactions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('No transactions yet.', style: AppTypography.caption),
          )
        else
          ...List.generate(recentCount, (index) {
            final tx = transactions[index];
            String walletName = "Investment Principal";
            if (tx.walletId != 0 && provider.wallets.isNotEmpty) {
              walletName = provider.wallets.firstWhere((w) => w.id == tx.walletId, orElse: () => provider.wallets.first).name;
            }
            final toWallet = (tx.toWalletId != null && provider.wallets.isNotEmpty) 
                ? provider.wallets.firstWhere((w) => w.id == tx.toWalletId, orElse: () => provider.wallets.first)
                : null;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TransactionItem(
                transaction: tx,
                walletName: walletName,
                toWalletName: toWallet?.name,
              ),
            );
          }),
      ],
    );
  }
}

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.backgroundWhite,
                child: ClipOval(
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primaryPurple, Colors.orange],
                      ),
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 28),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome Back,',
                    style: AppTypography.caption,
                  ),
                  SizedBox(height: 0),
                  Text(
                    'Hi, Mahmudul',
                    style: AppTypography.title,
                  ),
                ],
              ),
            ],
          ),
        ),
        Row(
          children: [
            HeaderIconButton(
              icon: Icons.cloud_sync_rounded,
              onTap: () {
                final messenger = ScaffoldMessenger.of(context);
                final finance = context.read<FinanceProvider>();
                messenger.showSnackBar(const SnackBar(content: Text('Syncing with Google Sheets...')));
                finance.syncFromSheet();
              },
            ),
            const SizedBox(width: 6),
            HeaderIconButton(
              icon: Icons.grid_view_rounded,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CategoryListScreen()),
                );
              },
            ),
            const SizedBox(width: 6),
            HeaderIconButton(
              icon: Icons.account_balance_wallet_rounded,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ManageScreen()),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const HeaderIconButton({required this.icon, this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundWhite,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: AppColors.primaryText, size: 22),
        ),
      ),
    );
  }
}
