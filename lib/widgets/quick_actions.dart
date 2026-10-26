import 'package:flutter/material.dart';
import 'package:financeapp/app_constants.dart';
import 'package:financeapp/models/account_model.dart';
import 'package:financeapp/screens/add_expense_screen.dart';
import 'package:financeapp/screens/add_money_screen.dart';
import 'package:financeapp/screens/transfer_screen.dart';
import 'package:financeapp/screens/savings_screen.dart';
import 'package:financeapp/screens/investment_screen.dart';
import 'package:financeapp/screens/loan_screen.dart';
import 'package:provider/provider.dart';
import 'package:financeapp/providers/finance_provider.dart';

class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({super.key});

  static const List<QuickAction> actions = [
    QuickAction('Add Money', Icons.account_balance_wallet_outlined),
    QuickAction('Add Expense', Icons.note_add_outlined),
    QuickAction('Transfer', Icons.swap_calls_outlined),
    QuickAction('Loans', Icons.real_estate_agent_outlined),
    QuickAction('Investments', Icons.analytics_outlined),
    QuickAction('Savings', Icons.savings_outlined),
    QuickAction('Assets', Icons.layers_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final walletCount = context.watch<FinanceProvider>().wallets.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - (AppSpacing.horizontalGap.width! * 3)) / 4;
        return Wrap(
          spacing: AppSpacing.horizontalGap.width!,
          runSpacing: AppSpacing.verticalGap.height!,
          children: actions.map((action) {
            bool isDisabled = false;
            if (action.label == 'Transfer' && walletCount < 2) {
              isDisabled = true;
            }

            return SizedBox(
              width: itemWidth,
              child: QuickActionItem(
                action: action,
                isDisabled: isDisabled,
                onTap: () {
                  if (isDisabled) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Add at least 2 wallets to use Transfer')),
                    );
                    return;
                  }
                  if (action.label == 'Add Expense') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddExpenseScreen()));
                  } else if (action.label == 'Add Money') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddMoneyScreen()));
                  } else if (action.label == 'Transfer') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const TransferScreen()));
                  } else if (action.label == 'Savings') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SavingsListScreen()));
                  } else if (action.label == 'Investments') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const InvestmentListScreen()));
                  } else if (action.label == 'Loans') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LoanScreen()));
                  }
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class QuickActionItem extends StatelessWidget {
  final QuickAction action;
  final VoidCallback onTap;
  final bool isDisabled;
  const QuickActionItem({required this.action, required this.onTap, this.isDisabled = false, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: isDisabled ? Colors.grey[200] : AppColors.incomeGreen,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                action.icon, 
                color: isDisabled ? Colors.grey[400] : Colors.white, 
                size: 20
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          action.label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption.copyWith(
            color: isDisabled ? Colors.grey[400] : Colors.black,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
