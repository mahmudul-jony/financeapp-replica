import 'package:flutter/material.dart';
import 'package:financeapp/app_constants.dart';
import 'package:provider/provider.dart';
import 'package:financeapp/providers/finance_provider.dart';
import 'package:financeapp/models/category_model.dart';

class CategorySelectionScreen extends StatelessWidget {
  final CategoryType type;
  const CategorySelectionScreen({required this.type, super.key});

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<FinanceProvider>().activeCategories.where((c) => c.type == type).toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primaryText, size: 20), onPressed: () => Navigator.pop(context)),
        title: Text('Select ${type == CategoryType.income ? "Income" : "Expense"} Category', style: AppTypography.title), centerTitle: false,
      ),
      body: categories.isEmpty 
        ? const Center(child: Text('No categories found. Create one first!'))
        : ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: categories.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.borderGrey),
            itemBuilder: (context, index) {
              final category = categories[index];

              return Container(
                color: Colors.white,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                  title: Text(category.name, style: AppTypography.body),
                  onTap: () => Navigator.pop(context, category),
                ),
              );
            },
          ),
    );
  }
}
