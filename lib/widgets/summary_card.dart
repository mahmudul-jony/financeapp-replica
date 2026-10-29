import 'package:flutter/material.dart';
import 'package:financeapp/app_constants.dart';
import 'package:financeapp/widgets/custom_painters.dart';

class SummaryCard extends StatelessWidget {
  final double totalWithdrawable;
  final double totalExpense;
  final double expenseChangePercentage;
  final VoidCallback? onTapDashboard;

  const SummaryCard({
    super.key,
    required this.totalWithdrawable,
    required this.totalExpense,
    required this.expenseChangePercentage,
    this.onTapDashboard,
  });

  @override
  Widget build(BuildContext context) {
    final double totalAvailableBeforeExpense = totalWithdrawable + totalExpense;
    final double expenseRatio = totalAvailableBeforeExpense > 0 
        ? (totalExpense / totalAvailableBeforeExpense).clamp(0.0, 1.0) 
        : 0.0;
    
    final now = DateTime.now();
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June', 
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final String currentMonthYear = "${monthNames[now.month - 1]}, ${now.year}";

    double validPercentage = expenseChangePercentage;
    if (validPercentage.isNaN || validPercentage.isInfinite) {
      validPercentage = 0.0;
    }

    final bool isMoreExpense = validPercentage > 0;
    final Color indicatorColor = isMoreExpense ? const Color(0xFFD2E85A) : AppColors.incomeGreen;

    final double absValue = validPercentage.abs() * 100;
    final String percentStr = absValue % 1 == 0 ? absValue.toInt().toString() : absValue.toStringAsFixed(1);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTapDashboard,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left Side Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top Section: Withdrawable Balance
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Withdrawable Balance',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                AppFormat.currency(totalWithdrawable),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Bottom Section: Date, Expense, vs last week
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentMonthYear,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Total Expanse ${AppFormat.currency(totalExpense)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: "$percentStr% ${isMoreExpense ? '↑' : '↓'} ",
                                    style: TextStyle(
                                      color: indicatorColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const TextSpan(
                                    text: "vs last week",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Right Side Content: Donut Chart & Dashboard Link
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Donut Chart
                      SizedBox(
                        width: 105,
                        height: 105,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(105, 105),
                              painter: DonutChartPainter(
                                percentage: expenseRatio,
                                color: const Color(0xFF00A644),
                                backgroundColor: const Color(0xFF3C3737),
                                strokeWidth: 8,
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "${(expenseRatio * 100).toInt()}%",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  "Expanse of\nincome",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    height: 1.15,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Dashboard Action
                      InkWell(
                        onTap: onTapDashboard,
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Dashboard',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 17,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
