import 'package:flutter/material.dart';
import 'package:financeapp/app_constants.dart';
import 'package:financeapp/widgets/app_components.dart';
import 'package:provider/provider.dart';
import 'package:financeapp/providers/finance_provider.dart';
import 'package:financeapp/models/wallet_model.dart';

class CreateWalletScreen extends StatefulWidget {
  const CreateWalletScreen({super.key});

  @override
  State<CreateWalletScreen> createState() => _CreateWalletScreenState();
}

class _CreateWalletScreenState extends State<CreateWalletScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _balanceController = TextEditingController();
  Color _selectedColor = AppColors.primaryPurple;
  String? _errorMessage;

  final List<Color> _colors = [
    AppColors.primaryPurple, AppColors.incomeGreen, Colors.orange, Colors.blue, Colors.red, Colors.teal
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.primaryText), onPressed: () => Navigator.pop(context)),
        title: const Text('Add Wallet', style: AppTypography.title), centerTitle: false,
      ),
      body: Column(
        children: [
          AppErrorBanner(
            message: _errorMessage,
            onDismissed: () => setState(() => _errorMessage = null),
          ),
          Expanded(
            child: Padding(
              padding: AppSpacing.screenPaddingInsets,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(hint: 'Wallet name', controller: _nameController),
                  AppSpacing.verticalGap,
                  AppTextField(hint: 'Initial Balance', controller: _balanceController, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                  AppSpacing.largeVerticalGap,
                  const Text('Choose Color', style: AppTypography.subTitle),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 50,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _colors.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final color = _colors[index];
                        final isSelected = _selectedColor == color;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedColor = color),
                          child: Container(
                            width: 50, height: 50,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                              boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, spreadRadius: 2)] : null,
                            ),
                            child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
                          ),
                        );
                      },
                    ),
                  ),
                  const Spacer(),
                  AppButton(
                    label: 'Add Wallet',
                    onTap: () {
                      setState(() => _errorMessage = null);
                      final balanceText = _balanceController.text.trim();
                      final balance = balanceText.isEmpty ? 0.0 : (double.tryParse(balanceText) ?? 0.0);
                      
                      if (_nameController.text.isNotEmpty) {
                        final wallet = Wallet(
                          name: _nameController.text,
                          balance: balance,
                          color: _selectedColor.value,
                        );
                        context.read<FinanceProvider>().addWallet(wallet);
                        Navigator.pop(context);
                      } else if (_nameController.text.isEmpty) {
                        setState(() => _errorMessage = "Please enter a wallet name");
                      }
                    }
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EditWalletScreen extends StatefulWidget {
  final Wallet wallet;
  const EditWalletScreen({required this.wallet, super.key});

  @override
  State<EditWalletScreen> createState() => _EditWalletScreenState();
}

class _EditWalletScreenState extends State<EditWalletScreen> {
  late final TextEditingController _nameController;
  late Color _selectedColor;

  final List<Color> _colors = [
    AppColors.primaryPurple, AppColors.incomeGreen, Colors.orange, Colors.blue, Colors.red, Colors.teal
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.wallet.name);
    _selectedColor = Color(widget.wallet.color);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.primaryText), onPressed: () => Navigator.pop(context)),
        title: const Text('Edit Wallet', style: AppTypography.title), centerTitle: false,
        actions: [
          if (!widget.wallet.isDefault)
            AppDeleteIconButton(onTap: () => _showDeleteConfirmation(context)),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: AppSpacing.screenPaddingInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(hint: 'Wallet name', controller: _nameController),
            AppSpacing.largeVerticalGap,
            const Text('Choose Color', style: AppTypography.subTitle),
            const SizedBox(height: 8),
            SizedBox(
              height: 50,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _colors.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final color = _colors[index];
                  final isSelected = _selectedColor == color;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                        boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, spreadRadius: 2)] : null,
                      ),
                      child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
                    ),
                  );
                },
              ),
            ),
            const Spacer(),
            AppButton(
              label: 'Update Wallet', 
              onTap: () {
                if (_nameController.text.isNotEmpty) {
                  final updatedWallet = Wallet(
                    id: widget.wallet.id,
                    name: _nameController.text,
                    balance: widget.wallet.balance,
                    frozenAmount: widget.wallet.frozenAmount,
                    color: _selectedColor.value,
                    isDefault: widget.wallet.isDefault,
                  );
                  context.read<FinanceProvider>().updateWallet(updatedWallet);
                  Navigator.pop(context);
                }
              }
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(widget.wallet.balance > 0 || widget.wallet.frozenAmount > 0 ? 'Archive Wallet?' : 'Delete Wallet?'),
        content: Text(widget.wallet.balance > 0 || widget.wallet.frozenAmount > 0 
            ? 'This wallet has a balance or history. It will be archived and hidden from selection but preserved in reports.'
            : 'This will permanently delete this wallet.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText))),
          TextButton(
            onPressed: () { 
              context.read<FinanceProvider>().deleteWallet(widget.wallet.id!);
              Navigator.pop(context); 
              Navigator.pop(context); 
            }, 
            child: Text(widget.wallet.balance > 0 || widget.wallet.frozenAmount > 0 ? 'Archive' : 'Delete', 
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }
}
