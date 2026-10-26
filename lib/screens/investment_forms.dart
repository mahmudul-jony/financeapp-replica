import 'package:flutter/material.dart';
import 'package:financeapp/app_constants.dart';
import 'package:financeapp/widgets/app_components.dart';
import 'package:provider/provider.dart';
import 'package:financeapp/providers/finance_provider.dart';
import 'package:financeapp/models/investment_model.dart';
import 'package:financeapp/models/wallet_model.dart';

enum InvestmentAction { create, edit, moreInvest, addProfit, withdraw, adjustment }
enum AdjustmentSource { wallet, investmentPrincipal }

class InvestmentActionScreen extends StatefulWidget {
  final InvestmentAction action;
  final Investment? investment;

  const InvestmentActionScreen({required this.action, this.investment, super.key});

  @override
  State<InvestmentActionScreen> createState() => _InvestmentActionScreenState();
}

class _InvestmentActionScreenState extends State<InvestmentActionScreen> {
  late final TextEditingController _amountController;
  late final TextEditingController _nameController;
  final TextEditingController _noteController = TextEditingController();
  Wallet? _selectedWallet;
  DateTime _selectedDate = DateTime.now();
  AdjustmentSource _adjustmentSource = AdjustmentSource.wallet;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _nameController = TextEditingController(text: widget.investment?.title ?? '');
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

    String title = 'Investment Action';
    String buttonLabel = 'Submit';
    if (widget.action == InvestmentAction.create) {
      title = 'Create Investment';
      buttonLabel = 'Create Investment';
    } else if (widget.action == InvestmentAction.edit) {
      title = 'Investment Info';
      buttonLabel = 'Update Title';
    } else if (widget.action == InvestmentAction.moreInvest) {
      title = 'Add Amount';
      buttonLabel = 'Add Amount';
    } else if (widget.action == InvestmentAction.addProfit) {
      title = 'Add Profit';
      buttonLabel = 'Add Profit';
    } else if (widget.action == InvestmentAction.withdraw) {
      title = 'Investment Withdraw';
      buttonLabel = 'Withdraw';
    } else if (widget.action == InvestmentAction.adjustment) {
      title = 'Investment Adjustment';
      buttonLabel = 'Apply Adjustment';
    }

    final bool isCreationOrEdit = widget.action == InvestmentAction.create || widget.action == InvestmentAction.edit;

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
                          AppTextField(hint: 'Investment name', controller: _nameController)
                        else if (widget.investment != null)
                          _buildReadOnlyCard(widget.investment!.title, AppFormat.currency(widget.investment!.amount)),
                        
                        if (widget.action == InvestmentAction.adjustment) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.borderGrey),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => setState(() => _adjustmentSource = AdjustmentSource.wallet),
                                    child: Row(
                                      children: [
                                        Radio<AdjustmentSource>(
                                          value: AdjustmentSource.wallet,
                                          groupValue: _adjustmentSource,
                                          activeColor: AppColors.primaryPurple,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          onChanged: (val) {
                                            if (val != null) setState(() => _adjustmentSource = val);
                                          },
                                        ),
                                        const Text('Wallet', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                ),
                                Container(width: 1, height: 24, color: AppColors.borderGrey),
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => setState(() => _adjustmentSource = AdjustmentSource.investmentPrincipal),
                                    child: Row(
                                      children: [
                                        Radio<AdjustmentSource>(
                                          value: AdjustmentSource.investmentPrincipal,
                                          groupValue: _adjustmentSource,
                                          activeColor: AppColors.primaryPurple,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          onChanged: (val) {
                                            if (val != null) setState(() => _adjustmentSource = val);
                                          },
                                        ),
                                        const Expanded(
                                          child: Text(
                                            'Total Investment', 
                                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_adjustmentSource == AdjustmentSource.wallet) ...[
                            const SizedBox(height: 12),
                            AppWalletSelector(
                              selectedAccount: _selectedWallet?.name ?? 'Select Wallet', 
                              onSelect: (n) => setState(() => _selectedWallet = wallets.firstWhere((w) => w.name == n)), 
                              accounts: walletItems
                            ),
                          ],
                          const SizedBox(height: 12),
                          AppSelectionField(value: "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}", icon: Icons.calendar_today_rounded, onTap: _pickDate),
                          AppSpacing.verticalGap,
                          AppTextField(hint: 'Add a note', controller: _noteController),
                          const Spacer(),
                          AppAmountInput(controller: _amountController, subLabel: 'Enter Amount'),
                        ] else if (widget.action != InvestmentAction.edit) ...[
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
                          AppAmountInput(controller: _amountController, subLabel: 'Enter Amount'),
                        ] else const Spacer(),
                        const SizedBox(height: 24),
                        AppButton(
                          label: buttonLabel, 
                          onTap: () async {
                            setState(() => _errorMessage = null);
                            if (widget.action == InvestmentAction.edit) {
                              if (_nameController.text.isNotEmpty) {
                                provider.updateInvestmentTitle(widget.investment!.id!, _nameController.text);
                                Navigator.pop(context);
                              } else {
                                setState(() => _errorMessage = "Please enter a name");
                              }
                              return;
                            }
                            final amount = double.tryParse(_amountController.text) ?? 0.0;
                            if (amount <= 0) {
                              setState(() => _errorMessage = "Amount must be greater than zero");
                              return;
                            }

                            if (widget.action == InvestmentAction.adjustment && widget.investment != null) {
                              try {
                                if (_adjustmentSource == AdjustmentSource.wallet) {
                                  if (_selectedWallet == null) {
                                    throw Exception("Please select a wallet");
                                  }
                                  if (amount > _selectedWallet!.balance) {
                                    throw Exception("Amount exceeds wallet withdrawable balance");
                                  }
                                  await provider.adjustInvestmentFromWallet(
                                    widget.investment!.id!, amount, _selectedWallet!.id!, _selectedDate, _noteController.text
                                  );
                                } else {
                                  if (amount > widget.investment!.amount) {
                                    throw Exception("Amount exceeds investment remaining principal");
                                  }
                                  await provider.adjustInvestmentFromPrincipal(
                                    widget.investment!.id!, amount, _selectedDate, _noteController.text
                                  );
                                }
                                if (mounted) Navigator.pop(context);
                              } catch (e) {
                                if (mounted) {
                                  setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
                                }
                              }
                              return;
                            }

                            if (amount > 0 && _selectedWallet != null) {
                              try {
                                if (widget.action == InvestmentAction.create) {
                                  if (_nameController.text.isEmpty) throw Exception("Please enter a name");
                                  await provider.addInvestment(_nameController.text, amount, _selectedWallet!.id!, _selectedDate, _noteController.text);
                                } else if (widget.action == InvestmentAction.moreInvest && widget.investment != null) {
                                  await provider.moreInvest(widget.investment!.id!, amount, _selectedWallet!.id!, _selectedDate, _noteController.text);
                                } else if (widget.action == InvestmentAction.addProfit && widget.investment != null) {
                                  await provider.addInvestmentProfit(widget.investment!.id!, amount, _selectedWallet!.id!, _selectedDate, _noteController.text);
                                } else if (widget.action == InvestmentAction.withdraw && widget.investment != null) {
                                  await provider.withdrawInvestment(widget.investment!.id!, amount, _selectedWallet!.id!, _selectedDate, _noteController.text);
                                }
                                if (mounted) Navigator.pop(context);
                              } catch (e) {
                                if (mounted) {
                                  setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
                                }
                              }
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
