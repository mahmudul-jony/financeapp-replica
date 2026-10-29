import 'package:flutter_test/flutter_test.dart';
import 'package:financeapp/models/transaction_model.dart';
import 'package:financeapp/services/sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Fetch data from sheet when unauthenticated returns safe result', () async {
    final result = await SyncService.fetchFromSheet();
    expect(result, isNotNull);
    expect(result.data, isEmpty);
  });

  group('SyncService Tab Naming & Prefix Tests (Requirement 6)', () {
    test('walletTabName formats prefix correctly', () {
      expect(SyncService.walletTabName('Main Wallet'), equals('Wallet-Main Wallet'));
      expect(SyncService.walletTabName('Wallet-Main Wallet'), equals('Wallet-Main Wallet'));
      expect(SyncService.walletTabName('bKash'), equals('Wallet-bKash'));
    });

    test('savingsTabName formats prefix correctly', () {
      expect(SyncService.savingsTabName('Emergency Fund'), equals('Saving-Emergency Fund'));
      expect(SyncService.savingsTabName('Saving-Emergency Fund'), equals('Saving-Emergency Fund'));
    });

    test('investmentTabName formats prefix correctly', () {
      expect(SyncService.investmentTabName('Crypto'), equals('Invest-Crypto'));
      expect(SyncService.investmentTabName('Invest-Crypto'), equals('Invest-Crypto'));
    });

    test('stripTabPrefix strips Wallet-, Saving-, and Invest- prefixes', () {
      expect(SyncService.stripTabPrefix('Wallet-Main Wallet'), equals('Main Wallet'));
      expect(SyncService.stripTabPrefix('Saving-Emergency Fund'), equals('Emergency Fund'));
      expect(SyncService.stripTabPrefix('Invest-Crypto'), equals('Crypto'));
      expect(SyncService.stripTabPrefix('Loans'), equals('Loans'));
      expect(SyncService.stripTabPrefix('Unprefixed'), equals('Unprefixed'));
    });
  });

  group('SyncService Multi-tab Transaction Resolution Tests (Requirements 1, 2)', () {
    test('Loan transactions map to Loans and Wallet tabs', () {
      final tabs = SyncService.getTabsForTransaction(TransactionType.loanGiven, 'Main Wallet');
      expect(tabs, contains('Loans'));
      expect(tabs, contains('Wallet-Main Wallet'));
    });

    test('Savings transactions map to dedicated Saving tab and Wallet tab', () {
      final tabs = SyncService.getTabsForTransaction(
        TransactionType.savingsCreated,
        'Main Wallet',
        secondaryTabName: 'Emergency Fund',
      );
      expect(tabs, contains('Saving-Emergency Fund'));
      expect(tabs, contains('Wallet-Main Wallet'));
    });

    test('Investment transactions map to dedicated Invest tab and Wallet tab', () {
      final tabs = SyncService.getTabsForTransaction(
        TransactionType.investmentCreated,
        'Main Wallet',
        secondaryTabName: 'Crypto Portfolio',
      );
      expect(tabs, contains('Invest-Crypto Portfolio'));
      expect(tabs, contains('Wallet-Main Wallet'));
    });

    test('Transfer transactions map to both source and destination wallet tabs', () {
      final tabs = SyncService.getTabsForTransaction(
        TransactionType.transfer,
        'Main Wallet',
        secondaryTabName: 'bKash',
      );
      expect(tabs, contains('Wallet-Main Wallet'));
      expect(tabs, contains('Wallet-bKash'));
    });

    test('Standard income/expense maps to single wallet tab', () {
      final tabs = SyncService.getTabsForTransaction(TransactionType.expense, 'Main Wallet');
      expect(tabs, equals(['Wallet-Main Wallet']));
    });
  });
}
