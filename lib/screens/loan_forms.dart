import 'package:flutter/material.dart';
import 'package:financeapp/app_constants.dart';
import 'package:financeapp/widgets/app_components.dart';
import 'package:provider/provider.dart';
import 'package:financeapp/providers/finance_provider.dart';
import 'package:financeapp/models/wallet_model.dart';
import 'package:financeapp/models/loan_model.dart';

enum LoanAction { addMore, recover, takeMore, pay, edit }

class CreateLoanScreen extends StatefulWidget {
  final bool isGiven;
  const CreateLoanScreen({required this.isGiven, super.key});

  @override
  State<CreateLoanScreen> createState() => _CreateLoanScreenState();
}

class _CreateLoanScreenState extends State<CreateLoanScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  Wallet? _selectedWallet;
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
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.primaryText), onPressed: () => Navigator.pop(context)),
        title: Text(widget.isGiven ? 'Give Loan' : 'Take Loan', style: AppTypography.title), centerTitle: false,
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
                        AppTextField(hint: widget.isGiven ? 'Recipient Name' : 'Provider name', controller: _nameController),
                        const SizedBox(height: 12),
                        AppWalletSelector(
                          selectedAccount: _selectedWallet?.name ?? 'Select Wallet', 
                          onSelect: (n) => setState(() => _selectedWallet = wallets.firstWhere((w) => w.name == n)), 
                          accounts: walletItems
                        ),
                        const SizedBox(height: 12),
                        AppSelectionField(value: "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}", icon: Icons.calendar_today_rounded, onTap: _pickDate),
                        AppSpacing.verticalGap,
                        AppTextField(hint: 'Add a note', controller: _noteController),
                        const Spacer(),
                        AppAmountInput(controller: _amountController, subLabel: 'Enter Loan Amount'),
                        const SizedBox(height: 24),
                        AppButton(
                          label: widget.isGiven ? 'Give Loan' : 'Take Loan', 
                          onTap: () async {
                            setState(() => _errorMessage = null);
                            final amount = double.tryParse(_amountController.text) ?? 0.0;
                            if (amount > 0 && _nameController.text.isNotEmpty && _selectedWallet != null) {
                              try {
                                if (widget.isGiven) {
                                  await provider.giveLoan(_nameController.text, amount, _selectedWallet!.id!, _selectedDate, _noteController.text);
                                } else {
                                  await provider.takeLoan(_nameController.text, amount, _selectedWallet!.id!, _selectedDate, _noteController.text);
                                }
                                if (mounted) Navigator.pop(context);
                              } catch (e) {
                                if (mounted) {
                                  setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
                                }
                              }
                            } else if (_nameController.text.isEmpty) {
                              setState(() => _errorMessage = "Please enter a name");
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
}

class LoanActionScreen extends StatefulWidget {
  final LoanAction action;
  final bool isGiven;
  final LoanRecipient recipient;

  const LoanActionScreen({required this.action, required this.isGiven, required this.recipient, super.key});

  @override
  State<LoanActionScreen> createState() => _LoanActionScreenState();
}

class _LoanActionScreenState extends State<LoanActionScreen> {
  late final TextEditingController _amountController;
  late final TextEditingController _nameController;
  final TextEditingController _noteController = TextEditingController();
  Wallet? _selectedWallet;
  DateTime _selectedDate = DateTime.now();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _nameController = TextEditingController(text: widget.recipient.name);
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
    final wallets = provider.activeWallets;
    final bool isEdit = widget.action == LoanAction.edit;

    if (_selectedWallet == null && wallets.isNotEmpty) {
      _selectedWallet = wallets.firstWhere((w) => w.isDefault, orElse: () => wallets.first);
    }

    final walletItems = wallets.map((w) => {
      'id': w.id,
      'name': w.name,
      'balance': AppFormat.currency(w.balance),
      'color': Color(w.color),
    }).toList();

    String title = 'Loan Action';
    String buttonLabel = 'Submit';
    if (isEdit) {
      title = 'Edit Loan';
      buttonLabel = 'Update Name';
    } else if (widget.action == LoanAction.addMore) {
      title = 'Add More';
      buttonLabel = 'Add More';
    } else if (widget.action == LoanAction.recover) {
      title = 'Recover Loan';
      buttonLabel = 'Recover Loan';
    } else if (widget.action == LoanAction.takeMore) {
      title = 'Take More';
      buttonLabel = 'Take More';
    } else if (widget.action == LoanAction.pay) {
      title = 'Repay Loan';
      buttonLabel = 'Repay Loan';
    }

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
                        if (isEdit)
                          AppTextField(hint: widget.isGiven ? 'Recipient Name' : 'Provider name', controller: _nameController)
                        else
                          _buildReadOnlyCard(widget.recipient.name, AppFormat.currency(widget.recipient.totalAmount)),
                        
                        if (!isEdit) ...[
                          const SizedBox(height: 16),
                          AppWalletSelector(
                            selectedAccount: _selectedWallet?.name ?? 'Select Wallet', 
                            onSelect: (n) => setState(() => _selectedWallet = wallets.firstWhere((w) => w.name == n)), 
                            accounts: walletItems
                          ),
                          const SizedBox(height: 12),
                          AppSelectionField(value: "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}", icon: Icons.calendar_today_rounded, onTap: _pickDate),
                          AppSpacing.verticalGap,
                          AppTextField(hint: 'Add a note', controller: _noteController),
                          const Spacer(),
                          AppAmountInput(controller: _amountController, subLabel: 'Enter Loan Amount'),
                        ] else const Spacer(),
                        const SizedBox(height: 24),
                        AppButton(
                          label: buttonLabel, 
                          onTap: () async {
                            setState(() => _errorMessage = null);
                            if (isEdit) {
                              if (_nameController.text.isNotEmpty) {
                                provider.updateLoanRecipientName(widget.recipient.id!, _nameController.text);
                                Navigator.pop(context);
                              } else {
                                setState(() => _errorMessage = "Please enter a name");
                              }
                              return;
                            }
                            final amount = double.tryParse(_amountController.text) ?? 0.0;
                            if (amount > 0 && _selectedWallet != null) {
                              try {
                                if (widget.action == LoanAction.addMore) {
                                  await provider.giveLoan(widget.recipient.name, amount, _selectedWallet!.id!, _selectedDate, _noteController.text);
                                } else if (widget.action == LoanAction.recover) {
                                  await provider.recoverLoan(widget.recipient.id!, amount, _selectedWallet!.id!, _selectedDate, _noteController.text);
                                } else if (widget.action == LoanAction.takeMore) {
                                  await provider.takeLoan(widget.recipient.name, amount, _selectedWallet!.id!, _selectedDate, _noteController.text);
                                } else if (widget.action == LoanAction.pay) {
                                  await provider.repayLoan(widget.recipient.id!, amount, _selectedWallet!.id!, _selectedDate, _noteController.text);
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

  Widget _buildReadOnlyCard(String name, String amount) => Container(
    width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderGrey)),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryPurple)),
      ],
    ),
  );
}
