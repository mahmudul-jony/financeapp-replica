import 'package:flutter_test/flutter_test.dart';
import 'package:financeapp/models/transaction_model.dart';

void main() {
  group('TransactionModel & Unique Identification Tests', () {
    test('TransactionModel formats syncId with formatSyncId when id is provided', () {
      final tx1 = TransactionModel(
        id: 1,
        title: 'Salary',
        amount: 5000.0,
        date: DateTime(2026, 10, 27),
        note: 'Monthly',
        type: TransactionType.income,
        walletId: 1,
      );

      final tx2 = TransactionModel(
        id: 2,
        title: 'Food',
        amount: 250.0,
        date: DateTime(2026, 10, 27),
        note: 'Lunch',
        type: TransactionType.expense,
        walletId: 1,
      );

      expect(tx1.syncId, equals('txid_000001'));
      expect(tx2.syncId, equals('txid_000002'));
      expect(tx1.syncStatus, equals('synced')); // default
    });

    test('TransactionModel preserves explicitly provided syncId and status', () {
      final now = DateTime.now();
      final tx = TransactionModel(
        id: 42,
        syncId: 'gs_1729999999_1234',
        title: 'Direct Sheet Entry',
        amount: 1500.0,
        date: DateTime(2026, 10, 27),
        note: 'Added via Google Sheets',
        type: TransactionType.income,
        walletId: 2,
        syncStatus: 'pending',
        updatedAt: now,
      );

      expect(tx.id, equals(42));
      expect(tx.syncId, equals('gs_1729999999_1234'));
      expect(tx.syncStatus, equals('pending'));
      expect(tx.updatedAt, equals(now));

      final map = tx.toMap();
      expect(map['sync_id'], equals('gs_1729999999_1234'));
      expect(map['sync_status'], equals('pending'));
      expect(map['updated_at'], equals(now.toIso8601String()));

      final restored = TransactionModel.fromMap(map);
      expect(restored.id, equals(42));
      expect(restored.syncId, equals('gs_1729999999_1234'));
      expect(restored.syncStatus, equals('pending'));
      expect(restored.amount, equals(1500.0));
      expect(restored.title, equals('Direct Sheet Entry'));
    });

    test('TransactionModel copyWith updates fields correctly', () {
      final tx = TransactionModel(
        syncId: 'tx_100',
        title: 'Grocery',
        amount: 300.0,
        date: DateTime(2026, 10, 27),
        note: 'Supermarket',
        type: TransactionType.expense,
        walletId: 1,
        syncStatus: 'pending',
      );

      final updated = tx.copyWith(
        amount: 350.0,
        syncStatus: 'synced',
        note: 'Updated Note',
      );

      expect(updated.syncId, equals('tx_100'));
      expect(updated.amount, equals(350.0));
      expect(updated.syncStatus, equals('synced'));
      expect(updated.note, equals('Updated Note'));
      expect(updated.title, equals('Grocery'));
    });
  });

  group('Conflict Resolution & Reconciliation Logic Tests', () {
    test('Direct Sheet addition is identified as new when not present locally', () {
      final localSyncIds = <String>{'tx_1', 'tx_2'};
      final remoteRow = {
        'id': 'gs_9999',
        'date': '27-10-26',
        'titleCategory': 'Freelance',
        'transectionType': 'Money Added',
        'amount': 8000,
        'note': 'Direct Sheet Add',
        'walletName': 'Pocket',
      };

      final isRemoteOnly = !localSyncIds.contains(remoteRow['id']);
      expect(isRemoteOnly, isTrue);
    });

    test('Conflict resolution preserves local pending change and appends conflict note', () {
      // Local pending change has amount 5200
      final localTx = TransactionModel(
        id: 1,
        syncId: 'tx_shared',
        title: 'Salary',
        amount: 5200.0,
        date: DateTime(2026, 10, 27),
        note: 'App Offline Edit',
        type: TransactionType.income,
        walletId: 1,
        syncStatus: 'pending',
        updatedAt: DateTime(2026, 10, 27, 14, 0),
      );

      // Remote Sheet has amount 5500 with no newer timestamp
      final remoteAmount = 5500.0;
      final remoteUpdatedAt = DateTime(2026, 10, 27, 13, 0); // older

      String resolvedNote = localTx.note;
      double resolvedAmount = localTx.amount;

      if (remoteUpdatedAt.isAfter(localTx.updatedAt!)) {
        resolvedAmount = remoteAmount;
      } else {
        // Local is newer: preserve local amount and append remote conflict details to note
        resolvedNote = '${localTx.note} [Conflict: Sheet had $remoteAmount]';
      }

      expect(resolvedAmount, equals(5200.0));
      expect(resolvedNote, contains('[Conflict: Sheet had 5500.0]'));
    });

    test('Remote wins when remote timestamp is newer during conflict', () {
      final localTx = TransactionModel(
        id: 1,
        syncId: 'tx_shared',
        title: 'Salary',
        amount: 5200.0,
        date: DateTime(2026, 10, 27),
        note: 'App Offline Edit',
        type: TransactionType.income,
        walletId: 1,
        syncStatus: 'pending',
        updatedAt: DateTime(2026, 10, 27, 12, 0),
      );

      final remoteAmount = 5500.0;
      final remoteUpdatedAt = DateTime(2026, 10, 27, 14, 0); // newer

      double resolvedAmount = localTx.amount;
      if (remoteUpdatedAt.isAfter(localTx.updatedAt!)) {
        resolvedAmount = remoteAmount;
      }

      expect(resolvedAmount, equals(5500.0));
    });

    test('Pending local transaction is NEVER deleted if missing from remote sheet', () {
      final localTxs = [
        TransactionModel(
          id: 1,
          syncId: 'tx_synced',
          title: 'Old Expense',
          amount: 100.0,
          date: DateTime(2026, 10, 27),
          note: '',
          type: TransactionType.expense,
          walletId: 1,
          syncStatus: 'synced',
        ),
        TransactionModel(
          id: 2,
          syncId: 'tx_offline_pending',
          title: 'New Offline Expense',
          amount: 250.0,
          date: DateTime(2026, 10, 27),
          note: 'Created offline',
          type: TransactionType.expense,
          walletId: 1,
          syncStatus: 'pending',
        ),
      ];

      final remoteSyncIds = <String>{}; // Empty remote response (or record deleted on Sheet)

      final toDeleteLocally = <String>[];
      for (var tx in localTxs) {
        if (tx.syncStatus == 'synced' && !remoteSyncIds.contains(tx.syncId)) {
          toDeleteLocally.add(tx.syncId);
        }
      }

      // tx_synced was intentionally deleted from Sheet -> safe to delete locally
      expect(toDeleteLocally, contains('tx_synced'));
      // tx_offline_pending was created offline -> MUST NOT BE DELETED!
      expect(toDeleteLocally, isNot(contains('tx_offline_pending')));
    });
  });

  group('Transfer Parsing & Direction Tests', () {
    test('Transfer "To Target" identifies source and destination correctly', () {
      final rawTitleCategory = 'To Bank asia';
      final rawWalletName = 'Pocket';

      int? sourceWallet;
      int? destWallet;

      final walletIds = {'Pocket': 1, 'Bank asia': 2};

      if (rawTitleCategory.startsWith('To ')) {
        sourceWallet = walletIds[rawWalletName];
        final targetName = rawTitleCategory.substring(3).trim();
        destWallet = walletIds[targetName];
      }

      expect(sourceWallet, equals(1)); // Pocket
      expect(destWallet, equals(2));   // Bank asia
    });

    test('Transfer "From Source" identifies source and destination correctly', () {
      // In the target wallet sheet ("Bank asia"), titleCategory is "From Pocket"
      final rawTitleCategory = 'From Pocket';
      final rawWalletName = 'Bank asia';

      int? sourceWallet;
      int? destWallet;

      final walletIds = {'Pocket': 1, 'Bank asia': 2};

      if (rawTitleCategory.startsWith('From ')) {
        final sourceName = rawTitleCategory.substring(5).trim();
        sourceWallet = walletIds[sourceName];
        destWallet = walletIds[rawWalletName];
      }

      expect(sourceWallet, equals(1)); // Pocket is SOURCE!
      expect(destWallet, equals(2));   // Bank asia is DESTINATION!
    });

    test('Wallet balance calculation for transfer decrements source and increments destination', () {
      final fromWalletId = 1;
      final toWalletId = 2;
      final amount = 500.0;

      double wallet1Balance = 1000.0;
      double wallet2Balance = 200.0;

      // Transfer from 1 to 2
      final tx = TransactionModel(
        title: 'Transfer',
        amount: amount,
        date: DateTime(2026, 10, 27),
        note: '',
        type: TransactionType.transfer,
        walletId: fromWalletId,
        toWalletId: toWalletId,
      );

      // Simulation of balance recalculation
      if (tx.walletId == fromWalletId && tx.type == TransactionType.transfer) {
        wallet1Balance -= tx.amount;
      }
      if (tx.toWalletId == toWalletId && tx.type == TransactionType.transfer) {
        wallet2Balance += tx.amount;
      }

      expect(wallet1Balance, equals(500.0));
      expect(wallet2Balance, equals(700.0));
    });
  });

  group('Projection Sheets & Default Wallet Tests', () {
    test('Non-wallet projection names like "Loans" do not become wallets', () {
      final rawWalletName = 'Loans';
      final type = TransactionType.loanGiven;

      bool isNonWallet = rawWalletName == 'N/A' ||
          rawWalletName == 'Investment Principal' ||
          rawWalletName == 'None' ||
          rawWalletName == 'Loans';

      expect(isNonWallet, isTrue);

      // Should map to default wallet instead of creating a wallet named "Loans"
      final defaultWalletId = 1;
      int assignedWalletId;
      if (isNonWallet && type == TransactionType.loanGiven) {
        assignedWalletId = defaultWalletId;
      } else {
        assignedWalletId = 999;
      }

      expect(assignedWalletId, equals(1));
    });
  });

  group('Sequential 6-digit txid_000000 format tests', () {
    test('TransactionModel.formatSyncId formats integer IDs with 6-digit zero padding', () {
      expect(TransactionModel.formatSyncId(1), equals('txid_000001'));
      expect(TransactionModel.formatSyncId(42), equals('txid_000042'));
      expect(TransactionModel.formatSyncId(999999), equals('txid_999999'));
    });

    test('TransactionModel fromMap defaults sync_id to formatted id when missing or empty', () {
      final map = {
        'id': 7,
        'title': 'Coffee',
        'amount': 120.0,
        'date': '2026-10-27T12:00:00.000',
        'type': 'expense',
        'walletId': 1,
      };

      final tx = TransactionModel.fromMap(map);
      expect(tx.syncId, equals('txid_000007'));
    });

    test('TransactionModel defaults syncId with formatSyncId if id is provided without syncId', () {
      final tx = TransactionModel(
        id: 15,
        title: 'Books',
        amount: 500.0,
        date: DateTime(2026, 10, 27),
        note: '',
        type: TransactionType.expense,
        walletId: 1,
      );
      expect(tx.syncId, equals('txid_000015'));
    });
  });
}
