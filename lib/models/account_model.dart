import 'package:flutter/material.dart';

class AccountCardData {
  final String bankName;
  final String balance;
  final String frozenAmount;
  final String maskedNumber;
  final Color accent;

  const AccountCardData({
    required this.bankName,
    required this.balance,
    required this.frozenAmount,
    required this.maskedNumber,
    required this.accent,
  });
}

enum DashboardCardType { summary, wallet }

class DashboardCardItem {
  final DashboardCardType type;
  final AccountCardData? walletData;
  final Map<String, dynamic>? summaryData;

  const DashboardCardItem.wallet(this.walletData) : type = DashboardCardType.wallet, summaryData = null;
  const DashboardCardItem.summary(this.summaryData) : type = DashboardCardType.summary, walletData = null;
}

class QuickAction {
  final String label;
  final IconData icon;

  const QuickAction(this.label, this.icon);
}
