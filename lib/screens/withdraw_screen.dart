import 'package:flutter/material.dart';
import 'package:financeapp/app_constants.dart';
import 'package:financeapp/widgets/app_components.dart';
import 'package:provider/provider.dart';
import 'package:financeapp/providers/finance_provider.dart';
import 'package:financeapp/models/wallet_model.dart';

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  Wallet? _sourceWallet;
  DateTime _selectedDate = DateTime.now();
  bool _isSelectingSource = false;
  String? _errorMessage;

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryPurple,
            onPrimary: Colors.white,
            onSurface: AppColors.primaryText,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final activeWallets = provider.activeWallets;

    // Filter out default Cash wallet from source options
    final withdrawableWallets = activeWallets
        .where((w) => !w.isDefault && w.name.toLowerCase() != 'cash')
        .toList();

    final defaultCashWallet = activeWallets.firstWhere(
      (w) => w.isDefault,
      orElse: () => activeWallets.firstWhere(
        (w) => w.name.toLowerCase() == 'cash',
        orElse: () => activeWallets.isNotEmpty ? activeWallets.first : Wallet(name: 'Cash', balance: 0.0, color: 0xFF7F3DFF, isDefault: true),
      ),
    );

    if (_sourceWallet == null && withdrawableWallets.isNotEmpty) {
      _sourceWallet = withdrawableWallets.first;
    }

    final walletItems = withdrawableWallets.map((w) => {
      'id': w.id,
      'name': w.name,
      'balance': AppFormat.currency(w.balance - w.frozenAmount),
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
          onPressed: () => _isSelectingSource ? setState(() => _isSelectingSource = false) : Navigator.pop(context),
        ),
        title: const Text('Cash Withdrawal', style: AppTypography.title),
        centerTitle: false,
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
                          if (withdrawableWallets.isEmpty) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.orange),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Please add a Bank or MFS wallet first to perform a cash withdrawal.',
                                      style: TextStyle(color: Colors.black87, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          if (_isSelectingSource) ...[
                            const Text('Select Source Wallet', style: AppTypography.caption),
                            const SizedBox(height: 6),
                            AppWalletSelector(
                              selectedAccount: _sourceWallet?.name ?? 'Select Wallet',
                              onSelect: (name) => setState(() {
                                _sourceWallet = withdrawableWallets.firstWhere((w) => w.name == name);
                                _isSelectingSource = false;
                              }),
                              accounts: walletItems,
                            ),
                          ] else ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: AppStaticWalletCard(
                                    acc: _sourceWallet != null ? {
                                      'name': _sourceWallet!.name,
                                      'balance': AppFormat.currency(_sourceWallet!.balance - _sourceWallet!.frozenAmount),
                                      'color': Color(_sourceWallet!.color),
                                    } : {'name': 'Select', 'balance': '0', 'color': Colors.grey},
                                    label: 'Withdraw From',
                                    onTap: () {
                                      if (withdrawableWallets.isNotEmpty) {
                                        setState(() => _isSelectingSource = true);
                                      }
                                    },
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(8, 38, 8, 0),
                                  child: Icon(Icons.arrow_forward_rounded, color: AppColors.primaryPurple, size: 22),
                                ),
                                Expanded(
                                  child: AppStaticWalletCard(
                                    acc: {
                                      'name': defaultCashWallet.name,
                                      'balance': AppFormat.currency(defaultCashWallet.balance),
                                      'color': Color(defaultCashWallet.color),
                                    },
                                    label: 'Destination (Cash)',
                                    onTap: () {}, // Fixed to Cash wallet
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Read-Only Category Indicator
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.borderGrey),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.local_atm_outlined, color: AppColors.primaryPurple, size: 22),
                                SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Category', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                    SizedBox(height: 2),
                                    Text('Cash Withdrawal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),
                          AppSelectionField(
                            value: "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
                            icon: Icons.calendar_today_rounded,
                            onTap: _pickDate,
                          ),
                          AppSpacing.verticalGap,
                          AppTextField(hint: 'Add a note (optional)', controller: _noteController),

                          const Spacer(),
                          AppAmountInput(controller: _amountController, subLabel: 'Enter Withdrawal Amount'),
                          const SizedBox(height: 24),

                          AppButton(
                            label: 'Confirm Withdrawal',
                            onTap: () async {
                              if (withdrawableWallets.isEmpty) {
                                setState(() => _errorMessage = "Please add a Bank or MFS wallet first");
                                return;
                              }
                              setState(() => _errorMessage = null);
                              final amount = double.tryParse(_amountController.text) ?? 0.0;
                              if (amount > 0 && _sourceWallet != null) {
                                final available = _sourceWallet!.balance - _sourceWallet!.frozenAmount;
                                if (amount > available) {
                                  setState(() => _errorMessage = "Insufficient withdrawable balance (${AppFormat.currency(available)} available)");
                                  return;
                                }
                                try {
                                  await provider.addCashWithdrawal(
                                    amount,
                                    _sourceWallet!.id!,
                                    _selectedDate,
                                    _noteController.text.trim(),
                                  );
                                  if (mounted) Navigator.pop(context);
                                } catch (e) {
                                  if (mounted) {
                                    setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
                                  }
                                }
                              } else if (amount <= 0) {
                                setState(() => _errorMessage = "Amount must be greater than zero");
                              } else if (_sourceWallet == null) {
                                setState(() => _errorMessage = "Please select a source wallet");
                              }
                            },
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
