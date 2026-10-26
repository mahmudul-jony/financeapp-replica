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
              
              // Map icon code back to Icons for tree shaking compatibility
              IconData categoryIcon;
              switch (category.iconCode) {
                case 0xe1af: categoryIcon = Icons.payments_rounded; break;
                case 0xe25a: categoryIcon = Icons.restaurant_rounded; break;
                case 0xe1d1: categoryIcon = Icons.directions_bus_rounded; break;
                case 0xe59c: categoryIcon = Icons.shopping_cart_rounded; break;
                default: categoryIcon = Icons.category_rounded;
              }

              return Container(
                color: Colors.white,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                  leading: Icon(categoryIcon),
                  title: Text(category.name, style: AppTypography.body),
                  onTap: () => Navigator.pop(context, category),
                ),
              );
            },
          ),
    );
  }
}
