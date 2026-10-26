import 'package:flutter/material.dart';
import 'package:financeapp/app_constants.dart';
import 'package:financeapp/screens/category_forms.dart';
import 'package:financeapp/widgets/app_components.dart';
import 'package:provider/provider.dart';
import 'package:financeapp/providers/finance_provider.dart';
import 'package:financeapp/models/category_model.dart';

class CategoryListScreen extends StatefulWidget {
  const CategoryListScreen({super.key});

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primaryText, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('All Categories', style: AppTypography.title),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryPurple,
          unselectedLabelColor: AppColors.secondaryText,
          indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(width: 3, color: AppColors.primaryPurple),
            insets: EdgeInsets.symmetric(horizontal: 48),
          ),
          tabs: const [
            Tab(text: 'Income'),
            Tab(text: 'Expense'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCategoryListTab(CategoryType.income),
          _buildCategoryListTab(CategoryType.expense),
        ],
      ),
    );
  }

  Widget _buildCategoryListTab(CategoryType type) {
    final provider = context.watch<FinanceProvider>();
    final categories = provider.categories.where((c) => c.type == type).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: AppButton(
            label: 'Add Category', 
            onTap: () => Navigator.push(
              context, 
              MaterialPageRoute(builder: (_) => CreateCategoryScreen(initialType: type)),
            ),
          ),
        ),
        Expanded(
          child: categories.isEmpty
          ? Center(
              child: Text(
                'No ${type == CategoryType.income ? "income" : "expense"} categories found',
                style: AppTypography.caption,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: categories.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final category = categories[index];
                
                IconData categoryIcon;
                switch (category.iconCode) {
                  case 0xe1af: categoryIcon = Icons.payments_rounded; break;
                  case 0xe25a: categoryIcon = Icons.restaurant_rounded; break;
                  case 0xe1d1: categoryIcon = Icons.directions_bus_rounded; break;
                  case 0xe59c: categoryIcon = Icons.shopping_cart_rounded; break;
                  default: categoryIcon = Icons.category_rounded;
                }

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadius.borderRadiusMedium,
                    border: Border.all(color: AppColors.borderGrey),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.backgroundGrey,
                      child: Icon(
                        categoryIcon,
                        color: category.type == CategoryType.income ? AppColors.incomeGreen : AppColors.expenseAlertText,
                        size: 20,
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(category.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        if (category.isArchived)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                            child: const Text('ARCHIVED', style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      category.type.name.toUpperCase(), 
                      style: TextStyle(
                        fontSize: 10, 
                        fontWeight: FontWeight.bold,
                        color: category.type == CategoryType.income ? AppColors.incomeGreen : AppColors.expenseAlertText
                      )
                    ),
                    trailing: AppEditIconButton(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditCategoryScreen(category: category)))),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditCategoryScreen(category: category))),
                  ),
                );
              },
            ),
        ),
      ],
    );
  }
}
