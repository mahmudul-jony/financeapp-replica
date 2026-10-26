import 'package:flutter/material.dart';
import 'package:financeapp/app_constants.dart';
import 'package:financeapp/widgets/custom_painters.dart';

class WeeklyAnalyticsSection extends StatelessWidget {
  const WeeklyAnalyticsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          height: 1,
          width: double.infinity,
          child: CustomPaint(painter: DashedLinePainter()),
        ),
        const SizedBox(height: 16),
        const Text(
          'Weekly Analytics',
          style: AppTypography.title,
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.softLightPurple,
            borderRadius: AppRadius.borderRadiusLarge,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Expense',
                        style: AppTypography.subTitle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\u09F3 372,546',
                        style: AppTypography.largeAmount.copyWith(fontSize: 28),
                      ),
                    ],
                  ),
                  const TrendBadge(),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 112,
                width: double.infinity,
                child: CustomPaint(painter: const AnalyticsChartPainter()),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const ['Sun', 'Mon', 'Tue', 'Wed', 'Thr', 'Fri', 'Sat']
                    .map((day) => Text(
                          day,
                          style: AppTypography.caption,
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TrendBadge extends StatelessWidget {
  const TrendBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.expenseAlertBackground,
        borderRadius: BorderRadius.circular(AppRadius.circular),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.trending_up, color: AppColors.expenseAlertText, size: 16),
          SizedBox(width: 4),
          Text(
            '+4.8%',
            style: TextStyle(
              color: AppColors.expenseAlertText,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
