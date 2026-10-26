import 'package:flutter/material.dart';
import 'package:financeapp/app_constants.dart';
import 'package:financeapp/widgets/app_components.dart';
import 'package:financeapp/screens/loan_forms.dart';
import 'package:financeapp/screens/loan_details_screen.dart';
import 'package:provider/provider.dart';
import 'package:financeapp/providers/finance_provider.dart';

class LoanScreen extends StatefulWidget {
  const LoanScreen({super.key});

  @override
  State<LoanScreen> createState() => _LoanScreenState();
}

class _LoanScreenState extends State<LoanScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primaryText, size: 20), onPressed: () => Navigator.pop(context)),
        title: const Text('All Loans', style: AppTypography.title), centerTitle: false,
        bottom: TabBar(
          controller: _tabController, labelColor: AppColors.primaryPurple, unselectedLabelColor: AppColors.secondaryText,
          indicator: const UnderlineTabIndicator(borderSide: BorderSide(width: 3, color: AppColors.primaryPurple), insets: EdgeInsets.symmetric(horizontal: 48)),
          tabs: const [Tab(text: 'Given'), Tab(text: 'Taken')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildLoanListTab(true), _buildLoanListTab(false)],
      ),
    );
  }

  Widget _buildLoanListTab(bool isGiven) {
    final provider = context.watch<FinanceProvider>();
    final recipients = provider.loanRecipients.where((r) => r.isDebt == !isGiven).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: AppButton(
            label: isGiven ? 'Give Loan' : 'Take Loan', 
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateLoanScreen(isGiven: isGiven)))
          ),
        ),
        Expanded(
          child: recipients.isEmpty 
          ? const Center(child: Text('No loans found'))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: recipients.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = recipients[index];
                return Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: AppRadius.borderRadiusMedium, border: Border.all(color: AppColors.borderGrey)),
                  child: ListTile(
                    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Total Loan', style: AppTypography.caption),
                    trailing: Text(AppFormat.currency(item.totalAmount), style: TextStyle(color: isGiven ? AppColors.expenseAlertText : AppColors.incomeGreen, fontWeight: FontWeight.bold, fontSize: 14)),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoanDetailsScreen(recipientId: item.id!, isGiven: isGiven))),
                  ),
                );
              },
            ),
        ),
      ],
    );
  }
}
