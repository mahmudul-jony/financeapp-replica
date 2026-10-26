import 'package:flutter/material.dart';
import 'package:financeapp/app_constants.dart';
import 'package:provider/provider.dart';
import 'package:financeapp/providers/finance_provider.dart';
import 'package:financeapp/widgets/transaction_item.dart';
import 'package:financeapp/widgets/app_components.dart';

class AllTransactionsScreen extends StatefulWidget {
  const AllTransactionsScreen({super.key});

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  @override
  void initState() {
    super.initState();
    // Reset filter to current month when entering all transactions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinanceProvider>().resetFilter();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final transactions = provider.filteredTransactions.reversed.toList();

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
        title: const Text('All Transactions', style: AppTypography.title),
        centerTitle: false,
      ),
      body: Column(
        children: [
          AppFilterBar(
            currentFilter: provider.currentFilter,
            selectedDate: provider.selectedFilterDate,
            onPrevious: provider.previousPeriod,
            onNext: provider.nextPeriod,
            onFilterChanged: provider.setFilterType,
          ),
          
          const SizedBox(height: 12),
          
          Expanded(
            child: transactions.isEmpty 
            ? const Center(child: Text('No transactions found for this period'))
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: transactions.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final tx = transactions[index];
                  String walletName = "Investment Principal";
                  if (tx.walletId != 0 && provider.wallets.isNotEmpty) {
                    walletName = provider.wallets.firstWhere((w) => w.id == tx.walletId, orElse: () => provider.wallets.first).name;
                  }
                  final toWallet = (tx.toWalletId != null && provider.wallets.isNotEmpty) 
                      ? provider.wallets.firstWhere((w) => w.id == tx.toWalletId, orElse: () => provider.wallets.first)
                      : null;

                  return TransactionItem(
                    transaction: tx,
                    walletName: walletName,
                    toWalletName: toWallet?.name,
                  );
                },
              ),
          ),
        ],
      ),
    );
  }
}
