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
      expect(SyncService.walletTabName('Cash'), equals('Wallet-Cash'));
      expect(SyncService.walletTabName('Wallet-Cash'), equals('Wallet-Cash'));
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
      expect(SyncService.stripTabPrefix('Wallet-Cash'), equals('Cash'));
      expect(SyncService.stripTabPrefix('Saving-Emergency Fund'), equals('Emergency Fund'));
      expect(SyncService.stripTabPrefix('Invest-Crypto'), equals('Crypto'));
      expect(SyncService.stripTabPrefix('Loans'), equals('Loans'));
      expect(SyncService.stripTabPrefix('Unprefixed'), equals('Unprefixed'));
    });
  });

  group('SyncService Type & Date Parsing Tests', () {
    test('parseType resolves from enum name string', () {
      expect(SyncService.parseType('loanGiven'), equals(TransactionType.loanGiven));
      expect(SyncService.parseType('loanTaken'), equals(TransactionType.loanTaken));
      expect(SyncService.parseType('savingsCreated'), equals(TransactionType.savingsCreated));
      expect(SyncService.parseType('investmentCreated'), equals(TransactionType.investmentCreated));
      expect(SyncService.parseType('income'), equals(TransactionType.income));
    });

    test('parseType resolves from label string', () {
      expect(SyncService.parseType(null, 'Loan Given'), equals(TransactionType.loanGiven));
      expect(SyncService.parseType(null, 'Loan Taken'), equals(TransactionType.loanTaken));
      expect(SyncService.parseType(null, 'More Loan Given'), equals(TransactionType.loanGivenMore));
      expect(SyncService.parseType(null, 'More Loan Taken'), equals(TransactionType.loanTakenMore));
      expect(SyncService.parseType(null, 'Loan Recovered'), equals(TransactionType.loanRecovered));
      expect(SyncService.parseType(null, 'Loan Repaid'), equals(TransactionType.loanRepaid));
      expect(SyncService.parseType(null, 'Savings Created'), equals(TransactionType.savingsCreated));
      expect(SyncService.parseType(null, 'Savings Increased'), equals(TransactionType.savingsIncreased));
      expect(SyncService.parseType(null, 'Savings Withdraw'), equals(TransactionType.savingsWithdrawal));
      expect(SyncService.parseType(null, 'Investment Created'), equals(TransactionType.investmentCreated));
      expect(SyncService.parseType(null, 'Profit Added'), equals(TransactionType.investmentProfit));
      expect(SyncService.parseType(null, 'Diposit'), equals(TransactionType.income));
      expect(SyncService.parseType(null, 'Transferred'), equals(TransactionType.transfer));
      expect(SyncService.parseType(null, 'Withdraw'), equals(TransactionType.cashWithdrawal));
      expect(SyncService.parseType(null, 'Cash Withdrawal'), equals(TransactionType.cashWithdrawal));
      expect(SyncService.parseType('cashWithdrawal', null), equals(TransactionType.cashWithdrawal));
    });

    test('parseDate handles various formats', () {
      final d1 = SyncService.parseDate('04-11-26');
      expect(d1.year, equals(2026));
      expect(d1.month, equals(11));
      expect(d1.day, equals(4));

      final d2 = SyncService.parseDate('04-11-2026');
      expect(d2.year, equals(2026));
      expect(d2.month, equals(11));
      expect(d2.day, equals(4));

      final d3 = SyncService.parseDate('2026-11-04');
      expect(d3.year, equals(2026));
      expect(d3.month, equals(11));
      expect(d3.day, equals(4));
    });
  });

  group('SyncService Multi-tab Transaction Resolution Tests (Requirements 1, 2)', () {
    test('All loan transaction types map to Loans and Wallet tabs', () {
      final loanTypes = [
        TransactionType.loanGiven,
        TransactionType.loanTaken,
        TransactionType.loanGivenMore,
        TransactionType.loanTakenMore,
        TransactionType.loanRecovered,
        TransactionType.loanRepaid,
      ];

      for (var type in loanTypes) {
        final tabs = SyncService.getTabsForTransaction(type, 'Cash');
        expect(tabs, contains('Loans'), reason: 'Failed for $type');
        expect(tabs, contains('Wallet-Cash'), reason: 'Failed for $type');
      }
    });

    test('Savings transactions map to dedicated Saving tab and Wallet tab', () {
      final tabs = SyncService.getTabsForTransaction(
        TransactionType.savingsCreated,
        'Cash',
        secondaryTabName: 'Emergency Fund',
      );
      expect(tabs, contains('Saving-Emergency Fund'));
      expect(tabs, contains('Wallet-Cash'));
    });

    test('Investment transactions map to dedicated Invest tab and Wallet tab', () {
      final tabs = SyncService.getTabsForTransaction(
        TransactionType.investmentCreated,
        'Cash',
        secondaryTabName: 'Crypto Portfolio',
      );
      expect(tabs, contains('Invest-Crypto Portfolio'));
      expect(tabs, contains('Wallet-Cash'));
    });

    test('Transfer transactions map to both source and destination wallet tabs', () {
      final tabs = SyncService.getTabsForTransaction(
        TransactionType.transfer,
        'Cash',
        secondaryTabName: 'bKash',
      );
      expect(tabs, contains('Wallet-Cash'));
      expect(tabs, contains('Wallet-bKash'));
    });

    test('Cash withdrawal transactions map to both source and destination wallet tabs', () {
      final tabs = SyncService.getTabsForTransaction(
        TransactionType.cashWithdrawal,
        'City Bank',
        secondaryTabName: 'Cash',
      );
      expect(tabs, contains('Wallet-City Bank'));
      expect(tabs, contains('Wallet-Cash'));
    });

    test('Standard income/expense maps to single wallet tab', () {
      final tabs = SyncService.getTabsForTransaction(TransactionType.expense, 'Cash');
      expect(tabs, equals(['Wallet-Cash']));
    });
  });
}
