import 'package:flutter/material.dart';
import 'package:financeapp/app_constants.dart';
import 'package:financeapp/widgets/app_components.dart';
import 'package:financeapp/screens/investment_forms.dart';
import 'package:provider/provider.dart';
import 'package:financeapp/providers/finance_provider.dart';
import 'package:financeapp/models/investment_model.dart';
import 'package:financeapp/widgets/transaction_item.dart';
import 'package:intl/intl.dart';

class InvestmentListScreen extends StatelessWidget {
  const InvestmentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final investments = provider.investments;

    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primaryText, size: 20), onPressed: () => Navigator.pop(context)),
        title: const Text('Investments', style: AppTypography.title), centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: AppButton(
              label: 'Create Investment', 
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InvestmentActionScreen(action: InvestmentAction.create)))
            ),
          ),
          Expanded(
            child: investments.isEmpty 
            ? const Center(child: Text('No investments found'))
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: investments.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = investments[index];
                  return Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: AppRadius.borderRadiusMedium, border: Border.all(color: AppColors.borderGrey)),
                    child: ListTile(
                      dense: true,
                      title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(DateFormat('dd MMM yyyy').format(item.date), style: AppTypography.caption),
                      trailing: Text(AppFormat.currency(item.amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvestmentDetailsScreen(investmentId: item.id!))),
                    ),
                  );
                },
              ),
          ),
        ],
      ),
    );
  }
}

class InvestmentDetailsScreen extends StatelessWidget {
  final int investmentId;
  const InvestmentDetailsScreen({required this.investmentId, super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final investment = provider.investments.firstWhere((i) => i.id == investmentId, orElse: () => Investment(title: 'Deleted', amount: 0, date: DateTime.now(), note: ''));
    final history = provider.investmentTransactions.where((t) => t.investmentId == investmentId).toList().reversed.toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primaryText, size: 20), onPressed: () => Navigator.pop(context)),
        title: const Text('Investment Details', style: AppTypography.title), centerTitle: false,
        actions: [
          AppEditIconButton(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvestmentActionScreen(action: InvestmentAction.edit, investment: investment)))),
          AppDeleteIconButton(onTap: () => _showDeleteConfirmation(context, provider)),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.screenPaddingInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSummaryInfoCard(
              title: investment.title, 
              amount: AppFormat.currency(investment.amount),
              amountColor: AppColors.incomeGreen,
              subtitle: 'Total Investment',
            ),
            const SizedBox(height: 24),
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Add Amount', 
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvestmentActionScreen(action: InvestmentAction.moreInvest, investment: investment))),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppButton(
                        label: 'Add Profit', 
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvestmentActionScreen(action: InvestmentAction.addProfit, investment: investment))),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Withdraw', 
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvestmentActionScreen(action: InvestmentAction.withdraw, investment: investment))),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppButton(
                        label: 'Adjustment', 
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvestmentActionScreen(action: InvestmentAction.adjustment, investment: investment))),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildHistorySection(provider, history, investment),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection(FinanceProvider provider, List<InvestmentTransaction> history, Investment investment) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Recent Transaction', style: AppTypography.subTitle),
      const SizedBox(height: 16),
      if (history.isEmpty)
        const Center(child: Text('No history available', style: AppTypography.caption))
      else
        ListView.separated(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          itemCount: history.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final tx = history[index];
            String walletName = "Investment Principal";
            if (tx.walletId != 0 && provider.wallets.isNotEmpty) {
              walletName = provider.wallets.firstWhere((w) => w.id == tx.walletId, orElse: () => provider.wallets.first).name;
            }
            
            // Check if this is a "More" investment by looking at previous history
            bool isMore = false;
            if (tx.type == InvestmentTransactionType.invest) {
              // Find first investment date
              final firstDate = history.last.date;
              if (tx.date.isAfter(firstDate)) {
                isMore = true;
              }
            }

            return TransactionItem(
              transaction: tx.toTransactionModel(investment.title, isMore: isMore),
              walletName: walletName,
            );
          },
        ),
    ],
  );

  void _showDeleteConfirmation(BuildContext context, FinanceProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Investment?'),
        content: const Text('This action cannot be undone. All history for this investment will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText))),
          TextButton(
            onPressed: () { 
              provider.deleteInvestment(investmentId);
              Navigator.pop(context); 
              Navigator.pop(context); 
            }, 
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }
}
