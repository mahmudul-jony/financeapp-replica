import 'package:flutter/material.dart';
import 'package:financeapp/app_constants.dart';
import 'package:financeapp/widgets/app_components.dart';
import 'package:financeapp/screens/category_selection_screen.dart';
import 'package:provider/provider.dart';
import 'package:financeapp/providers/finance_provider.dart';
import 'package:financeapp/models/wallet_model.dart';
import 'package:financeapp/models/category_model.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  Wallet? _selectedWallet;
  Category? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  String? _errorMessage;

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context, initialDate: _selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2101),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primaryPurple, onPrimary: Colors.white, onSurface: AppColors.primaryText),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final wallets = provider.activeWallets;
    
    if (_selectedWallet == null && wallets.isNotEmpty) {
      _selectedWallet = wallets.firstWhere((w) => w.isDefault, orElse: () => wallets.first);
    } else if (_selectedWallet != null && wallets.isNotEmpty) {
      _selectedWallet = wallets.firstWhere(
        (w) => w.id == _selectedWallet!.id,
        orElse: () => wallets.firstWhere((w) => w.isDefault, orElse: () => wallets.first),
      );
    }

    final walletItems = wallets.map((w) => {
      'id': w.id,
      'name': w.name,
      'balance': AppFormat.currency(w.balance),
      'color': Color(w.color),
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primaryText, size: 20), onPressed: () => Navigator.pop(context)),
        title: const Text('Add Expense', style: AppTypography.title), centerTitle: false,
      ),
      body: Column(
        children: [
          AppErrorBanner(
            message: _errorMessage,
            onDismissed: () => setState(() => _errorMessage = null),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: AppSpacing.screenPaddingInsets,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppWalletSelector(
                            selectedAccount: _selectedWallet?.name ?? 'Select Wallet', 
                            onSelect: (name) => setState(() => _selectedWallet = wallets.firstWhere((w) => w.name == name)), 
                            accounts: walletItems
                          ),
                          AppSpacing.verticalGap,
                          
                          AppSelectionField(
                            value: "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}", 
                            icon: Icons.calendar_today_rounded, onTap: _pickDate
                          ),
                          AppSpacing.verticalGap,
                          
                          AppSelectionField(
                            value: _selectedCategory?.name ?? 'Select Category', 
                            icon: Icons.grid_view_rounded, 
                            onTap: () async {
                              final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CategorySelectionScreen(type: CategoryType.expense)));
                              if (res != null) setState(() => _selectedCategory = res as Category);
                            }
                          ),
                          AppSpacing.verticalGap,
                          AppTextField(hint: 'Add a note', controller: _noteController),
      
                          const Spacer(),
                          AppAmountInput(controller: _amountController, subLabel: 'Enter Amount'),
                          const SizedBox(height: 32),
                          
                          AppButton(
                            label: 'Add Expense', 
                            onTap: () async {
                              setState(() => _errorMessage = null);
                              final amount = double.tryParse(_amountController.text) ?? 0.0;
                              if (amount > 0 && _selectedWallet != null && _selectedCategory != null) {
                                try {
                                  await provider.addExpense(amount, _selectedWallet!.id!, _selectedCategory!.id!, _selectedDate, _noteController.text);
                                  if (mounted) Navigator.pop(context);
                                } catch (e) {
                                  if (mounted) {
                                    setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
                                  }
                                }
                              } else if (amount <= 0) {
                                setState(() => _errorMessage = "Amount must be greater than zero");
                              } else if (_selectedCategory == null) {
                                setState(() => _errorMessage = "Please select a category");
                              }
                            }
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
