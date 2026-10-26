import 'package:flutter/material.dart';
import 'package:financeapp/app_constants.dart';
import 'package:financeapp/widgets/custom_painters.dart';
import 'package:provider/provider.dart';
import 'package:financeapp/providers/finance_provider.dart';
import 'package:financeapp/models/transaction_model.dart';
import 'package:financeapp/models/category_model.dart';
import 'package:financeapp/widgets/app_components.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _netWorthTabController;

  @override
  void initState() {
    super.initState();
    _netWorthTabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinanceProvider>().resetFilter();
    });
  }

  @override
  void dispose() {
    _netWorthTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final transactions = provider.filteredTransactions;

    // Total Withdrawable
    double totalWithdrawable = provider.wallets.fold(0, (sum, w) => sum + w.balance);

    // Period Cash Flow (Filtered)
    double periodIncome = transactions
        .where((tx) => tx.type == TransactionType.income || tx.type == TransactionType.investmentProfit)
        .fold(0, (sum, tx) => sum + tx.amount);
    double periodExpense = transactions
        .where((tx) => tx.type == TransactionType.expense)
        .fold(0, (sum, tx) => sum + tx.amount);
    double netCashFlow = periodIncome - periodExpense;

    String periodLabel = 'This Month';
    switch (provider.currentFilter) {
      case FilterType.today: periodLabel = 'Today'; break;
      case FilterType.week: periodLabel = 'This Week'; break;
      case FilterType.month: periodLabel = 'This Month'; break;
      case FilterType.year: periodLabel = 'This Year'; break;
    }

    // Expense by Category (Filtered)
    Map<int, double> categoryExpenses = {};
    for (var tx in transactions.where((t) => t.type == TransactionType.expense)) {
      if (tx.categoryId != null) {
        categoryExpenses[tx.categoryId!] = (categoryExpenses[tx.categoryId!] ?? 0) + tx.amount;
      }
    }
    var sortedCategoryIds = categoryExpenses.keys.toList()
      ..sort((a, b) => categoryExpenses[b]!.compareTo(categoryExpenses[a]!));
    double maxCatExpense = categoryExpenses.isEmpty ? 0 : categoryExpenses[sortedCategoryIds.first]!;

    // Savings
    double totalFrozen = provider.wallets.fold(0, (sum, w) => sum + w.frozenAmount);
    double savingsRatio = periodIncome > 0 ? (totalFrozen / periodIncome) * 100 : 0;

    // Investments
    double totalInvested = provider.investments.fold(0, (sum, i) => sum + i.amount);
    double periodProfit = transactions
        .where((tx) => tx.type == TransactionType.investmentProfit)
        .fold(0, (sum, tx) => sum + tx.amount);
    double profitRatio = totalInvested > 0 ? (periodProfit / totalInvested) * 100 : 0;

    // Loans
    double totalGiven = provider.totalLoanReceivable;
    double totalTaken = provider.totalLoanPayable;

    // Net Worth
    double netWorth = provider.netWorth;
    double totalAssets = provider.totalAssets;

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
        title: const Text('Dashboard', style: AppTypography.title),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Filter Bar
          AppFilterBar(
            currentFilter: provider.currentFilter,
            selectedDate: provider.selectedFilterDate,
            onPrevious: provider.previousPeriod,
            onNext: provider.nextPeriod,
            onFilterChanged: provider.setFilterType,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  // 1. Cash Flow Overview with Horizontal Progress Bars
                  _buildCashFlowOverview(
                    periodLabel: periodLabel,
                    income: periodIncome,
                    expense: periodExpense,
                    netCashFlow: netCashFlow,
                  ),
                  const SizedBox(height: 16),

                  // 2. Expense by Category (Filtered)
                  if (sortedCategoryIds.isNotEmpty)
                    _buildSectionCard(
                      'Expense by Category',
                      Column(
                        children: sortedCategoryIds.map((id) {
                          final cat = provider.categories.firstWhere(
                            (c) => c.id == id,
                            orElse: () => Category(name: 'Other', iconCode: 0, type: CategoryType.expense),
                          );
                          final amount = categoryExpenses[id]!;
                          final ratio = maxCatExpense > 0 ? amount / maxCatExpense : 0.0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                                    Text(AppFormat.currency(amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: ratio,
                                    minHeight: 6,
                                    backgroundColor: AppColors.backgroundGrey,
                                    color: AppColors.primaryPurple,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  if (sortedCategoryIds.isNotEmpty) const SizedBox(height: 16),

                  // 3. Balance by Wallet (Static)
                  _buildSectionCard(
                    'Balance by Wallet',
                    Column(
                      children: [
                        ...provider.wallets.map((w) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildListRow(w.name, AppFormat.currency(w.balance), AppColors.primaryText),
                        )),
                        const Divider(height: 20),
                        _buildListRow('Total Balance', AppFormat.currency(totalWithdrawable), AppColors.primaryPurple, isBold: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4. Savings Overview
                  _buildSectionCard(
                    'Savings Overview',
                    Center(
                      child: Column(
                        children: [
                          const Text('Total Freeze Amount', style: AppTypography.caption),
                          const SizedBox(height: 6),
                          Text(
                            AppFormat.currency(totalFrozen),
                            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.orange),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Savings Ratio: ${savingsRatio.round()}% of period income',
                              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 5. Investment Overview
                  _buildSectionCard(
                    'Investment Overview',
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildListRow('Total Invested', AppFormat.currency(totalInvested), AppColors.primaryText),
                              const SizedBox(height: 8),
                              _buildListRow('Period Profit', AppFormat.currency(periodProfit), AppColors.incomeGreen),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: CustomPaint(painter: DonutChartPainter(percentage: (profitRatio / 100).clamp(0.0, 1.0), color: AppColors.incomeGreen)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 6. Loan Summary
                  _buildSectionCard(
                    'Loan Summary',
                    Column(
                      children: [
                        _buildListRow('Given (To Recover)', AppFormat.currency(totalGiven), AppColors.incomeGreen),
                        const SizedBox(height: 10),
                        _buildListRow('Taken (To Repay)', AppFormat.currency(totalTaken), AppColors.expenseAlertText),
                        const Divider(height: 20),
                        _buildListRow(
                          'Net Loan Position',
                          AppFormat.currency((totalGiven - totalTaken).abs()),
                          (totalGiven - totalTaken) >= 0 ? AppColors.incomeGreen : AppColors.expenseAlertText,
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 7. Net Worth Card
                  _buildNetWorthCard(
                    netWorth: netWorth, 
                    assets: totalAssets, 
                    liabilities: totalTaken,
                    withdrawable: totalWithdrawable,
                    frozen: totalFrozen,
                    invested: totalInvested,
                    loanGiven: totalGiven,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashFlowOverview({
    required String periodLabel,
    required double income,
    required double expense,
    required double netCashFlow,
  }) {
    double maxVal = (income > expense ? income : expense);
    if (maxVal <= 0) maxVal = 1;

    double incomeRatio = income > 0 ? (income / maxVal).clamp(0.05, 1.0) : 0.0;
    double expenseRatio = expense > 0 ? (expense / maxVal).clamp(0.05, 1.0) : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderGrey.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cash Flow Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryText)),
          const SizedBox(height: 12),
          const Text('NET CASH FLOW', style: TextStyle(color: AppColors.secondaryText, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(
            AppFormat.currency(netCashFlow),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: netCashFlow >= 0 ? AppColors.primaryText : AppColors.expenseAlertText,
            ),
          ),
          const SizedBox(height: 20),
          
          // Income Row & Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Income', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.primaryText)),
              Text(AppFormat.currency(income), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.incomeGreen)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: incomeRatio,
              minHeight: 10,
              backgroundColor: AppColors.backgroundGrey,
              color: AppColors.incomeGreen,
            ),
          ),
          const SizedBox(height: 16),

          // Expenses Row & Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Expenses', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.primaryText)),
              Text(AppFormat.currency(expense), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.expenseAlertText)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: expenseRatio,
              minHeight: 10,
              backgroundColor: AppColors.backgroundGrey,
              color: AppColors.expenseAlertText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetWorthCard({
    required double netWorth, 
    required double assets, 
    required double liabilities,
    required double withdrawable,
    required double frozen,
    required double invested,
    required double loanGiven,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderGrey.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          const Text('Net Worth', style: AppTypography.caption),
          const SizedBox(height: 4),
          Text(AppFormat.currency(netWorth), style: const TextStyle(color: AppColors.primaryText, fontSize: 30, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          const Text('Assets − Liabilities', style: TextStyle(color: AppColors.secondaryText, fontSize: 10)),
          const SizedBox(height: 16),
          Container(
            height: 42,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: AppColors.backgroundGrey, borderRadius: BorderRadius.circular(12)),
            child: TabBar(
              controller: _netWorthTabController,
              indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]),
              labelColor: AppColors.primaryPurple, unselectedLabelColor: AppColors.secondaryText,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [Tab(text: 'Assets'), Tab(text: 'Liabilities')],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 170,
            child: TabBarView(
              controller: _netWorthTabController,
              children: [
                _buildAssetBreakdown(assets, withdrawable, frozen, invested, loanGiven),
                _buildLiabilityBreakdown(liabilities),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetBreakdown(double total, double w, double f, double i, double l) => Column(
    children: [
      _buildListRow('Total Assets', AppFormat.currency(total), AppColors.incomeGreen, isBold: true),
      const Divider(height: 20),
      _buildListRow('Withdrawable', AppFormat.currency(w), AppColors.primaryText, fontSize: 12),
      const SizedBox(height: 8),
      _buildListRow('Savings (Frozen)', AppFormat.currency(f), AppColors.primaryText, fontSize: 12),
      const SizedBox(height: 8),
      _buildListRow('Investments', AppFormat.currency(i), AppColors.primaryText, fontSize: 12),
      const SizedBox(height: 8),
      _buildListRow('Loans Given', AppFormat.currency(l), AppColors.primaryText, fontSize: 12),
    ],
  );

  Widget _buildLiabilityBreakdown(double total) => Column(
    children: [
      _buildListRow('Total Liabilities', AppFormat.currency(total), AppColors.expenseAlertText, isBold: true),
      const Divider(height: 20),
      _buildListRow('Loans Taken', AppFormat.currency(total), AppColors.primaryText, fontSize: 12),
    ],
  );

  Widget _buildSectionCard(String title, Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.borderGrey.withOpacity(0.8)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.02),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryText)),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );

  Widget _buildListRow(String label, String value, Color valueColor, {bool isBold = false, double fontSize = 13}) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: TextStyle(color: AppColors.primaryText, fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
      Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: fontSize)),
    ],
  );
}
