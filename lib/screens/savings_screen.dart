import 'package:flutter/material.dart';
import 'package:financeapp/app_constants.dart';
import 'package:financeapp/widgets/app_components.dart';
import 'package:financeapp/screens/savings_forms.dart';
import 'package:provider/provider.dart';
import 'package:financeapp/providers/finance_provider.dart';
import 'package:financeapp/models/savings_model.dart';
import 'package:financeapp/widgets/transaction_item.dart';
import 'package:intl/intl.dart';

class SavingsListScreen extends StatelessWidget {
  const SavingsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final savings = provider.savingsList;

    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primaryText, size: 20), onPressed: () => Navigator.pop(context)),
        title: const Text('All Savings', style: AppTypography.title), centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: AppButton(
              label: 'Create Savings', 
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavingsActionScreen(action: SavingsAction.create)))
            ),
          ),
          Expanded(
            child: savings.isEmpty 
            ? const Center(child: Text('No savings found'))
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: savings.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = savings[index];
                  return Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: AppRadius.borderRadiusMedium, border: Border.all(color: AppColors.borderGrey)),
                    child: ListTile(
                      dense: true,
                      title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(DateFormat('dd MMM yyyy').format(item.date), style: AppTypography.caption),
                      trailing: Text(AppFormat.currency(item.amount), style: TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.bold, fontSize: 14)),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SavingsDetailsScreen(savingsId: item.id!))),
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

class SavingsDetailsScreen extends StatelessWidget {
  final int savingsId;
  const SavingsDetailsScreen({required this.savingsId, super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final savings = provider.savingsList.firstWhere((s) => s.id == savingsId, orElse: () => Savings(title: 'Deleted', amount: 0, date: DateTime.now(), note: ''));
    final history = provider.savingsTransactions.where((t) => t.savingsId == savingsId).toList().reversed.toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primaryText, size: 20), onPressed: () => Navigator.pop(context)),
        title: const Text('Savings Details', style: AppTypography.title), centerTitle: false,
        actions: [
          AppEditIconButton(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SavingsActionScreen(action: SavingsAction.edit, savings: savings)))),
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
              title: savings.title, 
              amount: AppFormat.currency(savings.amount),
              amountColor: AppColors.primaryPurple,
              subtitle: 'Total Savings',
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Add Amount', 
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SavingsActionScreen(action: SavingsAction.addAmount, savings: savings))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Withdraw Savings', 
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SavingsActionScreen(action: SavingsAction.withdraw, savings: savings))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildHistorySection(provider, history),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection(FinanceProvider provider, List<SavingsTransaction> history) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Recent Transaction', style: AppTypography.subTitle),
      const SizedBox(height: 16),
      if (history.isEmpty)
        const Center(child: Text('No transactions yet', style: AppTypography.caption))
      else
        ListView.separated(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          itemCount: history.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final tx = history[index];
            if (provider.wallets.isEmpty) return const SizedBox();

            final wallet = provider.wallets.firstWhere((w) => w.id == tx.walletId, orElse: () => provider.wallets.first);
            
            // Check if this is "More" by looking at history
            bool isMore = false;
            if (tx.type == SavingsTransactionType.deposit) {
              final firstDate = history.last.date;
              if (tx.date.isAfter(firstDate)) {
                isMore = true;
              }
            }

            return TransactionItem(
              transaction: tx.toTransactionModel(isMore: isMore),
              walletName: wallet.name,
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
        title: const Text('Delete Savings?'),
        content: const Text('This action cannot be undone. All history for this savings will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText))),
          TextButton(
            onPressed: () { 
              provider.deleteSavings(savingsId);
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
