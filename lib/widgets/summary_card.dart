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
    double totalAvailableBeforeExpense = totalWithdrawable + totalExpense;
    double expenseRatio = totalAvailableBeforeExpense > 0 
        ? (totalExpense / totalAvailableBeforeExpense).clamp(0.0, 1.0) 
        : 0.0;
    
    final now = DateTime.now();
    final monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
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
        borderRadius: AppRadius.borderRadiusLarge,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTapDashboard,
          borderRadius: AppRadius.borderRadiusLarge,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Withdrawable Balance',
                            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w400),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              AppFormat.currency(totalWithdrawable),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 38,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            currentMonthYear,
                            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w400),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Total Expense ${AppFormat.currency(totalExpense)}',
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                isMoreExpense ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                color: indicatorColor,
                                size: 15,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "$percentStr%",
                                style: TextStyle(
                                  color: indicatorColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                " vs last week",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: Stack(
                        children: [
                          Center(
                            child: CustomPaint(
                              size: const Size(90, 90),
                              painter: DonutChartPainter(
                                percentage: expenseRatio,
                                color: AppColors.incomeGreen,
                                backgroundColor: Colors.white.withOpacity(0.1),
                              ),
                            ),
                          ),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "${(expenseRatio * 100).toInt()}%",
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                                const Text(
                                  "Expense",
                                  style: TextStyle(color: Colors.white70, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Dashed Divider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: CustomPaint(
                  size: const Size(double.infinity, 1),
                  painter: DashedLinePainter(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              // Dashboard Button at the bottom
              if (onTapDashboard != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      const Text(
                        'Dashboard',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashedLinePainter extends CustomPainter {
  final Color color;
  DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    double dashWidth = 5, dashSpace = 3, startX = 0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
