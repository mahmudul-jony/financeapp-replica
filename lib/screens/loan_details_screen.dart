import 'package:flutter/material.dart';
import 'package:financeapp/app_constants.dart';
import 'package:financeapp/screens/loan_forms.dart';
import 'package:financeapp/widgets/app_components.dart';
import 'package:financeapp/models/loan_model.dart';
import 'package:provider/provider.dart';
import 'package:financeapp/providers/finance_provider.dart';

import 'package:financeapp/widgets/transaction_item.dart';

class LoanDetailsScreen extends StatelessWidget {
  final int recipientId;
  final bool isGiven;

  const LoanDetailsScreen({required this.recipientId, required this.isGiven, super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final recipient = provider.loanRecipients.firstWhere(
      (r) => r.id == recipientId, 
      orElse: () => LoanRecipient(name: 'Deleted', totalAmount: 0)
    );
    final history = provider.loanTransactions
        .where((t) => t.recipientId == recipientId)
        .toList().reversed.toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primaryText, size: 20), onPressed: () => Navigator.pop(context)),
        title: const Text('Loan Details', style: AppTypography.title), centerTitle: false,
        actions: [
          AppEditIconButton(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoanActionScreen(action: LoanAction.edit, isGiven: isGiven, recipient: recipient)))),
          AppDeleteIconButton(onTap: () => _showDeleteConfirmation(context, provider)),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.screenPaddingInsets,
        child: Column(
          children: [
            AppSummaryInfoCard(
              title: recipient.name,
              amount: AppFormat.currency(recipient.totalAmount),
              amountColor: isGiven ? AppColors.expenseAlertText : AppColors.incomeGreen,
              icon: Icons.person_outline_rounded,
              subtitle: isGiven ? 'Given Loan' : 'Taken Loan',
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: AppButton(label: isGiven ? 'Add More' : 'Take More', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoanActionScreen(action: isGiven ? LoanAction.addMore : LoanAction.takeMore, isGiven: isGiven, recipient: recipient))))),
                const SizedBox(width: 12),
                Expanded(child: AppButton(label: isGiven ? 'Recover Loan' : 'Repay Loan', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoanActionScreen(action: isGiven ? LoanAction.recover : LoanAction.pay, isGiven: isGiven, recipient: recipient))))),
              ],
            ),
            const SizedBox(height: 32),
            _buildHistorySection(provider, history, recipient),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection(FinanceProvider provider, List<LoanTransaction> history, LoanRecipient recipient) => Column(
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
            if (provider.wallets.isEmpty) return const SizedBox();

            final wallet = provider.wallets.firstWhere((w) => w.id == tx.walletId, orElse: () => provider.wallets.first);
            
            return TransactionItem(
              transaction: tx.toTransactionModel(recipient.name),
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
        title: const Text('Delete Loan?'),
        content: const Text('This action cannot be undone. All history for this person will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText))),
          TextButton(
            onPressed: () { 
              provider.deleteLoanRecipient(recipientId);
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
