import 'package:flutter/material.dart';
import 'package:financeapp/app_constants.dart';
import 'package:financeapp/models/account_model.dart';

class AccountCard extends StatelessWidget {
  final AccountCardData data;
  final bool compact;

  const AccountCard({required this.data, this.compact = false, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 180 : 204,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: AppRadius.borderRadiusLarge,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Withdrawable Balance',
                      style: AppTypography.captionMuted,
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        data.balance,
                        style: AppTypography.largeAmount.copyWith(color: Colors.white, fontSize: 28),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Frozen Balance',
                      style: AppTypography.captionMuted,
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        data.frozenAmount,
                        style: AppTypography.bodyWhite.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  data.maskedNumber,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyWhite.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                data.bankName,
                style: AppTypography.bodyWhite.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
