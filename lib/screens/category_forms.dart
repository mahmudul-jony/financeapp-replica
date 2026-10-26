import 'package:flutter/material.dart';
import 'package:financeapp/app_constants.dart';
import 'package:financeapp/widgets/app_components.dart';
import 'package:provider/provider.dart';
import 'package:financeapp/providers/finance_provider.dart';
import 'package:financeapp/models/category_model.dart';

class CreateCategoryScreen extends StatefulWidget {
  final CategoryType? initialType;
  const CreateCategoryScreen({this.initialType, super.key});

  @override
  State<CreateCategoryScreen> createState() => _CreateCategoryScreenState();
}

class _CreateCategoryScreenState extends State<CreateCategoryScreen> {
  final TextEditingController _nameController = TextEditingController();
  late CategoryType _selectedType;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType ?? CategoryType.expense;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.primaryText), onPressed: () => Navigator.pop(context)),
        title: const Text('Add Category', style: AppTypography.title), centerTitle: false,
      ),
      body: Padding(
        padding: AppSpacing.screenPaddingInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(hint: 'Category name', controller: _nameController),
            AppSpacing.largeVerticalGap,
            const Text('Category Type', style: AppTypography.subTitle),
            AppSpacing.smallVerticalGap,
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderGrey)),
              child: Column(
                children: [
                  RadioListTile<CategoryType>(
                    title: const Text('Expense'),
                    value: CategoryType.expense,
                    groupValue: _selectedType,
                    activeColor: AppColors.expenseAlertText,
                    onChanged: (v) => setState(() => _selectedType = v!),
                  ),
                  const Divider(height: 1),
                  RadioListTile<CategoryType>(
                    title: const Text('Income'),
                    value: CategoryType.income,
                    groupValue: _selectedType,
                    activeColor: AppColors.incomeGreen,
                    onChanged: (v) => setState(() => _selectedType = v!),
                  ),
                ],
              ),
            ),
            const Spacer(),
            AppButton(
              label: 'Add Category',
              onTap: () {
                if (_nameController.text.isNotEmpty) {
                  final cat = Category(
                    name: _nameController.text,
                    iconCode: Icons.category.codePoint,
                    type: _selectedType,
                  );
                  context.read<FinanceProvider>().addCategory(cat);
                  Navigator.pop(context);
                }
              }
            ),
          ],
        ),
      ),
    );
  }
}

class EditCategoryScreen extends StatefulWidget {
  final Category category;
  const EditCategoryScreen({required this.category, super.key});

  @override
  State<EditCategoryScreen> createState() => _EditCategoryScreenState();
}

class _EditCategoryScreenState extends State<EditCategoryScreen> {
  late final TextEditingController _nameController;
  late CategoryType _selectedType;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category.name);
    _selectedType = widget.category.type;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.primaryText), onPressed: () => Navigator.pop(context)),
        title: const Text('Edit Category', style: AppTypography.title), centerTitle: false,
        actions: [
          AppDeleteIconButton(onTap: () => _showDeleteConfirmation(context)),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: AppSpacing.screenPaddingInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(hint: 'Category name', controller: _nameController),
            AppSpacing.largeVerticalGap,
            const Text('Category Type', style: AppTypography.subTitle),
            AppSpacing.smallVerticalGap,
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderGrey)),
              child: Column(
                children: [
                  RadioListTile<CategoryType>(
                    title: const Text('Expense'),
                    value: CategoryType.expense,
                    groupValue: _selectedType,
                    activeColor: AppColors.expenseAlertText,
                    onChanged: (v) => setState(() => _selectedType = v!),
                  ),
                  const Divider(height: 1),
                  RadioListTile<CategoryType>(
                    title: const Text('Income'),
                    value: CategoryType.income,
                    groupValue: _selectedType,
                    activeColor: AppColors.incomeGreen,
                    onChanged: (v) => setState(() => _selectedType = v!),
                  ),
                ],
              ),
            ),
            const Spacer(),
            AppButton(
              label: 'Update Category', 
              onTap: () {
                if (_nameController.text.isNotEmpty) {
                  final updatedCat = Category(
                    id: widget.category.id,
                    name: _nameController.text,
                    iconCode: widget.category.iconCode,
                    type: _selectedType,
                  );
                  context.read<FinanceProvider>().updateCategory(updatedCat);
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
        title: const Text('Delete Category?'),
        content: const Text('If this category has history, it will be archived. Otherwise, it will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText))),
          TextButton(
            onPressed: () { 
              context.read<FinanceProvider>().deleteCategory(widget.category.id!);
              Navigator.pop(context); 
              Navigator.pop(context); 
            }, 
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }
}
