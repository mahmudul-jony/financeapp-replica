import 'package:flutter/material.dart';
import 'package:financeapp/app_constants.dart';
import 'package:financeapp/widgets/app_components.dart';
import 'package:provider/provider.dart';
import 'package:financeapp/providers/finance_provider.dart';
import 'package:financeapp/models/wallet_model.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  Wallet? _fromWallet;
  Wallet? _toWallet;
  DateTime _selectedDate = DateTime.now();
  bool? _isSelectingFrom;
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

    if (_fromWallet == null && wallets.isNotEmpty) {
      _fromWallet = wallets.firstWhere((w) => w.isDefault, orElse: () => wallets.first);
    }
    if (_toWallet == null && wallets.length > 1) {
      _toWallet = wallets.firstWhere((w) => w.id != _fromWallet?.id, orElse: () => wallets[1]);
    }

    // Filter wallets for selector to avoid same wallet in both
    List<Wallet> availableWallets = wallets;
    if (_isSelectingFrom == true && _toWallet != null) {
      availableWallets = wallets.where((w) => w.id != _toWallet!.id).toList();
    } else if (_isSelectingFrom == false && _fromWallet != null) {
      availableWallets = wallets.where((w) => w.id != _fromWallet!.id).toList();
    }

    final walletItems = availableWallets.map((w) => {
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primaryText, size: 20),
          onPressed: () => _isSelectingFrom != null ? setState(() => _isSelectingFrom = null) : Navigator.pop(context),
        ),
        title: const Text('Transfer', style: AppTypography.title), centerTitle: false,
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
                        children: [
                          if (_isSelectingFrom != null) 
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_isSelectingFrom! ? 'Select From Wallet' : 'Select To Wallet', style: AppTypography.caption),
                                const SizedBox(height: 8),
                                AppWalletSelector(
                                  selectedAccount: (_isSelectingFrom! ? _fromWallet?.name : _toWallet?.name) ?? 'Select Wallet', 
                                  onSelect: (name) => setState(() {
                                    if (_isSelectingFrom!) {
                                      _fromWallet = wallets.firstWhere((w) => w.name == name);
                                    } else {
                                      _toWallet = wallets.firstWhere((w) => w.name == name);
                                    }
                                    _isSelectingFrom = null;
                                  }), 
                                  accounts: walletItems
                                ),
                              ],
                            )
                          else 
                            Row(
                              children: [
                                Expanded(
                                  child: AppStaticWalletCard(
                                    acc: _fromWallet != null ? {
                                      'name': _fromWallet!.name,
                                      'balance': AppFormat.currency(_fromWallet!.balance),
                                      'color': Color(_fromWallet!.color),
                                    } : {'name': 'Select', 'balance': '0', 'color': Colors.grey}, 
                                    label: 'From Wallet', 
                                    onTap: () => setState(() => _isSelectingFrom = true)
                                  )
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(10, 24, 10, 0), 
                                  child: IconButton(
                                    icon: const Icon(Icons.swap_horiz_rounded, color: AppColors.primaryPurple, size: 24),
                                    onPressed: () {
                                      if (_fromWallet != null && _toWallet != null) {
                                        setState(() {
                                          final temp = _fromWallet;
                                          _fromWallet = _toWallet;
                                          _toWallet = temp;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                Expanded(
                                  child: AppStaticWalletCard(
                                    acc: _toWallet != null ? {
                                      'name': _toWallet!.name,
                                      'balance': AppFormat.currency(_toWallet!.balance),
                                      'color': Color(_toWallet!.color),
                                    } : {'name': 'Select', 'balance': '0', 'color': Colors.grey}, 
                                    label: 'To Wallet', 
                                    onTap: () => setState(() => _isSelectingFrom = false)
                                  )
                                ),
                              ],
                            ),
                          
                          const SizedBox(height: 16),
                          AppSelectionField(
                            value: "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}", 
                            icon: Icons.calendar_today_rounded, onTap: _pickDate
                          ),
                          AppSpacing.verticalGap,
                          AppTextField(hint: 'Add a note', controller: _noteController),
                          
                          const Spacer(),
                          AppAmountInput(controller: _amountController, subLabel: 'Enter Amount'),
                          const SizedBox(height: 24),
                          
                          AppButton(
                            label: 'Confirm Transfer', 
                            onTap: () async {
                              setState(() => _errorMessage = null);
                              final amount = double.tryParse(_amountController.text) ?? 0.0;
                              if (amount > 0 && _fromWallet != null && _toWallet != null && _fromWallet!.id != _toWallet!.id) {
                                try {
                                  await provider.addTransfer(amount, _fromWallet!.id!, _toWallet!.id!, _selectedDate, _noteController.text);
                                  if (mounted) Navigator.pop(context);
                                } catch (e) {
                                  if (mounted) {
                                    setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
                                  }
                                }
                              } else if (amount <= 0) {
                                setState(() => _errorMessage = "Amount must be greater than zero");
                              } else if (_fromWallet?.id == _toWallet?.id) {
                                setState(() => _errorMessage = "Source and destination wallets must be different");
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
