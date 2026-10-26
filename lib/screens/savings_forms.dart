import 'package:flutter/material.dart';
import 'package:financeapp/app_constants.dart';
import 'package:financeapp/widgets/app_components.dart';
import 'package:provider/provider.dart';
import 'package:financeapp/providers/finance_provider.dart';
import 'package:financeapp/models/savings_model.dart';
import 'package:financeapp/models/wallet_model.dart';

enum SavingsAction { create, edit, addAmount, withdraw }

class SavingsActionScreen extends StatefulWidget {
  final SavingsAction action;
  final Savings? savings;

  const SavingsActionScreen({required this.action, this.savings, super.key});

  @override
  State<SavingsActionScreen> createState() => _SavingsActionScreenState();
}

class _SavingsActionScreenState extends State<SavingsActionScreen> {
  late final TextEditingController _amountController;
  late final TextEditingController _nameController;
  final TextEditingController _noteController = TextEditingController();
  Wallet? _selectedWallet;
  DateTime _selectedDate = DateTime.now();

  List<Wallet> _availableWallets = [];
  double _currentAllocation = 0.0;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _nameController = TextEditingController(text: widget.savings?.title ?? '');
    if (widget.action == SavingsAction.withdraw && widget.savings != null) {
      _loadWithdrawalWallets();
    }
  }

  Future<void> _loadWithdrawalWallets() async {
    setState(() => _isLoading = true);
    final provider = context.read<FinanceProvider>();
    final wallets = await provider.getWalletsForSavings(widget.savings!.id!);
    setState(() {
      _availableWallets = wallets;
      if (_availableWallets.isNotEmpty) {
        _selectedWallet = _availableWallets.first;
        _updateAllocation();
      }
      _isLoading = false;
    });
  }

  Future<void> _updateAllocation() async {
    if (_selectedWallet != null && widget.savings != null) {
      final alloc = await context.read<FinanceProvider>().getSavingsAllocationForWallet(widget.savings!.id!, _selectedWallet!.id!);
      setState(() => _currentAllocation = alloc);
    }
  }

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
    final wallets = widget.action == SavingsAction.withdraw ? _availableWallets : provider.activeWallets;

    if (_selectedWallet == null && wallets.isNotEmpty && widget.action != SavingsAction.withdraw) {
      _selectedWallet = wallets.firstWhere((w) => w.isDefault, orElse: () => wallets.first);
    }

    final walletItems = wallets.map((w) => {
      'id': w.id,
      'name': w.name,
      'balance': AppFormat.currency(w.balance),
      'frozen_amount': w.frozenAmount,
      'color': Color(w.color),
    }).toList();

    String title = 'Savings Action';
    String buttonLabel = 'Submit';
    if (widget.action == SavingsAction.create) {
      title = 'Create Savings';
      buttonLabel = 'Create Savings';
    } else if (widget.action == SavingsAction.edit) {
      title = 'Savings Info';
      buttonLabel = 'Update Title';
    } else if (widget.action == SavingsAction.addAmount) {
      title = 'Add Amount';
      buttonLabel = 'Add Amount';
    } else if (widget.action == SavingsAction.withdraw) {
      title = 'Withdraw Savings';
      buttonLabel = 'Withdraw Savings';
    }

    final bool isCreationOrEdit = widget.action == SavingsAction.create || widget.action == SavingsAction.edit;

    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.primaryText), onPressed: () => Navigator.pop(context)),
        title: Text(title, style: AppTypography.title), centerTitle: false,
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
                      padding: const EdgeInsets.all(AppSpacing.screenPadding),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (isCreationOrEdit)
                          AppTextField(hint: 'Saving title', controller: _nameController)
                        else if (widget.savings != null)
                          _buildReadOnlyCard(widget.savings!.title, AppFormat.currency(widget.savings!.amount)),
                        
                        if (widget.action != SavingsAction.edit) ...[
                          const SizedBox(height: 16),
                          if (widget.action == SavingsAction.withdraw && wallets.isEmpty && !_isLoading)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Text("No wallets have allocations for this savings goal.", style: TextStyle(color: Colors.red)),
                            )
                          else
                            AppWalletSelector(
                            selectedAccount: _selectedWallet?.name ?? 'Select Wallet', 
                            onSelect: (n) {
                              setState(() => _selectedWallet = wallets.firstWhere((w) => w.name == n));
                              if (widget.action == SavingsAction.withdraw) _updateAllocation();
                            }, 
                            accounts: walletItems
                          ),
                          if (widget.action == SavingsAction.withdraw && _selectedWallet != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8, left: 4),
                              child: Text(
                                'Available for Goal in this Wallet: ${AppFormat.currency(_currentAllocation)}',
                                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          const SizedBox(height: 12),
                          AppSelectionField(value: "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}", icon: Icons.calendar_today_rounded, onTap: _pickDate),
                          AppSpacing.verticalGap,
                          AppTextField(hint: 'Add a note', controller: _noteController),
                          const Spacer(),
                          AppAmountInput(controller: _amountController, subLabel: 'Enter Amount'),
                        ] else const Spacer(),
                        const SizedBox(height: 24),
                        AppButton(
                          label: buttonLabel, 
                          onTap: () async {
                            setState(() => _errorMessage = null);
                            if (widget.action == SavingsAction.edit) {
                              if (_nameController.text.isNotEmpty) {
                                provider.updateSavingsTitle(widget.savings!.id!, _nameController.text);
                                Navigator.pop(context);
                              } else {
                                setState(() => _errorMessage = "Please enter a title");
                              }
                              return;
                            }
                            final amount = double.tryParse(_amountController.text) ?? 0.0;
                            if (amount > 0 && _selectedWallet != null) {
                              try {
                                if (widget.action == SavingsAction.create) {
                                  if (_nameController.text.isEmpty) throw Exception("Please enter a title");
                                  await provider.addSavings(_nameController.text, amount, _selectedWallet!.id!, _selectedDate, _noteController.text);
                                } else if (widget.action == SavingsAction.addAmount && widget.savings != null) {
                                  await provider.depositToSavings(widget.savings!.id!, amount, _selectedWallet!.id!, _selectedDate, _noteController.text);
                                } else if (widget.action == SavingsAction.withdraw && widget.savings != null) {
                                  await provider.withdrawFromSavings(widget.savings!.id!, amount, _selectedWallet!.id!, _selectedDate, _noteController.text);
                                }
                                if (mounted) Navigator.pop(context);
                              } catch (e) {
                                if (mounted) {
                                  setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
                                }
                              }
                            } else if (amount <= 0) {
                              setState(() => _errorMessage = "Amount must be greater than zero");
                            }
                          }
                        ),
                        const SizedBox(height: 8),
                      ]),
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

  Widget _buildReadOnlyCard(String title, String amount) => Container(
    width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderGrey)),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryPurple)),
      ],
    ),
  );
}
