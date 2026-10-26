import 'package:flutter/material.dart';
import 'package:financeapp/app_constants.dart';
import 'package:financeapp/models/transaction_model.dart';
import 'package:intl/intl.dart';

class TransactionItem extends StatelessWidget {
  final TransactionModel transaction;
  final String walletName;
  final String? toWalletName;

  const TransactionItem({
    super.key,
    required this.transaction,
    required this.walletName,
    this.toWalletName,
  });

  @override
  Widget build(BuildContext context) {
    final bool isExpense = 
        transaction.type == TransactionType.expense || 
        transaction.type == TransactionType.transfer ||
        transaction.type == TransactionType.loanGiven ||
        transaction.type == TransactionType.loanGivenMore ||
        transaction.type == TransactionType.loanRepaid ||
        transaction.type == TransactionType.investmentCreated ||
        transaction.type == TransactionType.investmentIncreased ||
        transaction.type == TransactionType.investmentExpense ||
        transaction.type == TransactionType.investmentAdjustment ||
        transaction.type == TransactionType.savingsCreated ||
        transaction.type == TransactionType.savingsIncreased;

    String walletDisplay = walletName;
    if (transaction.type == TransactionType.transfer && toWalletName != null) {
      walletDisplay = "$walletName - $toWalletName";
    }

    // Determine Icon
    IconData iconData;
    Color iconColor;
    
    switch (transaction.type) {
      case TransactionType.transfer:
        iconData = Icons.swap_horiz;
        iconColor = AppColors.primaryPurple;
        break;
      case TransactionType.income:
      case TransactionType.investmentProfit:
        iconData = Icons.account_balance_wallet_outlined;
        iconColor = AppColors.incomeGreen;
        break;
      case TransactionType.expense:
        iconData = Icons.shopping_bag_outlined;
        iconColor = AppColors.expenseAlertText;
        break;
      case TransactionType.loanGiven:
      case TransactionType.loanGivenMore:
      case TransactionType.loanTaken:
      case TransactionType.loanTakenMore:
      case TransactionType.loanRecovered:
      case TransactionType.loanRepaid:
        iconData = Icons.person_outline_rounded;
        iconColor = isExpense ? AppColors.expenseAlertText : AppColors.incomeGreen;
        break;
      case TransactionType.investmentCreated:
      case TransactionType.investmentIncreased:
      case TransactionType.investmentWithdraw:
      case TransactionType.investmentExpense:
      case TransactionType.investmentAdjustment:
        iconData = Icons.trending_up_rounded;
        iconColor = isExpense ? AppColors.expenseAlertText : AppColors.incomeGreen;
        break;
      case TransactionType.savingsCreated:
      case TransactionType.savingsIncreased:
      case TransactionType.savingsWithdrawal:
        iconData = Icons.savings_outlined;
        iconColor = (transaction.type == TransactionType.savingsCreated || transaction.type == TransactionType.savingsIncreased) 
            ? AppColors.expenseAlertText 
            : AppColors.incomeGreen;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.borderRadiusMedium,
        border: Border.all(color: AppColors.borderGrey.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.backgroundGrey,
              child: Icon(iconData, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.displayLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    DateFormat('dd MMM yyyy').format(transaction.date),
                    style: AppTypography.caption.copyWith(fontSize: 11),
                  ),
                  if (transaction.note.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      transaction.note,
                      style: AppTypography.caption.copyWith(
                        fontSize: 12,
                        color: AppColors.secondaryText.withOpacity(0.8),
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isExpense ? "-" : "+"}${AppFormat.currency(transaction.amount)}',
                  style: TextStyle(
                    color: isExpense ? AppColors.expenseAlertText : AppColors.incomeGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  walletDisplay,
                  style: AppTypography.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
