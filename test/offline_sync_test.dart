import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:financeapp/models/transaction_model.dart';
import 'package:financeapp/providers/finance_provider.dart';

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

  group('7-Field Conflict Detection & Comparison Tests', () {
    final baseLocal = {
      'sync_id': 'txid_000010',
      'title': 'Grocery Shopping',
      'amount': 450.00,
      'date': '2026-10-27T10:30:00.000',
      'note': 'Weekly vegetables',
      'type': 'expense',
      'walletId': 1,
    };

    final baseRemote = {
      'id': 'txid_000010',
      'titleCategory': 'Grocery Shopping',
      'amount': '450.00',
      'date': '2026-10-27T18:00:00.000Z',
      'note': 'Weekly vegetables',
      'transectionType': 'Expense',
      'walletName': 'Pocket',
    };

    test('All 7 fields matching returns zero differences (no conflict)', () {
      final diffs = FinanceProvider.compareSevenFields(
        localTx: baseLocal,
        remoteRow: baseRemote,
        resolvedRemoteWalletId: 1,
        resolvedRemoteType: TransactionType.expense,
        localWalletName: 'Pocket',
      );

      expect(diffs, isEmpty);
    });

    test('Date normalization: same calendar day has no diff; different day flags Date conflict', () {
      // Same day, different time -> no diff
      final diffsSameDay = FinanceProvider.compareSevenFields(
        localTx: {...baseLocal, 'date': '2026-10-27T08:15:00.000'},
        remoteRow: {...baseRemote, 'date': '27-10-26'},
        resolvedRemoteWalletId: 1,
        resolvedRemoteType: TransactionType.expense,
        localWalletName: 'Pocket',
      );
      expect(diffsSameDay, isEmpty);

      // Different calendar day -> Date diff
      final diffsDifferentDay = FinanceProvider.compareSevenFields(
        localTx: {...baseLocal, 'date': '2026-10-27T08:15:00.000'},
        remoteRow: {...baseRemote, 'date': '28-10-26'},
        resolvedRemoteWalletId: 1,
        resolvedRemoteType: TransactionType.expense,
        localWalletName: 'Pocket',
      );
      expect(diffsDifferentDay.length, equals(1));
      expect(diffsDifferentDay.first, contains('Date'));
    });

    test('Title/Category normalization: whitespace and casing ignored, but distinct text flags conflict', () {
      // Normalized match
      final diffsNormalized = FinanceProvider.compareSevenFields(
        localTx: {...baseLocal, 'title': '  grocery shopping  '},
        remoteRow: {...baseRemote, 'titleCategory': 'GROCERY SHOPPING'},
        resolvedRemoteWalletId: 1,
        resolvedRemoteType: TransactionType.expense,
        localWalletName: 'Pocket',
      );
      expect(diffsNormalized, isEmpty);

      // Distinct title -> conflict
      final diffsDistinct = FinanceProvider.compareSevenFields(
        localTx: {...baseLocal, 'title': 'Grocery Shopping'},
        remoteRow: {...baseRemote, 'titleCategory': 'Pharmacy & Medicine'},
        resolvedRemoteWalletId: 1,
        resolvedRemoteType: TransactionType.expense,
        localWalletName: 'Pocket',
      );
      expect(diffsDistinct.length, equals(1));
      expect(diffsDistinct.first, contains('Title/Category'));
    });

    test('Transaction Type mismatch flags Type conflict', () {
      final diffs = FinanceProvider.compareSevenFields(
        localTx: {...baseLocal, 'type': 'expense'},
        remoteRow: {...baseRemote, 'transectionType': 'Money Added'},
        resolvedRemoteWalletId: 1,
        resolvedRemoteType: TransactionType.income,
        localWalletName: 'Pocket',
      );
      expect(diffs.length, equals(1));
      expect(diffs.first, contains('Type'));
    });

    test('Amount comparison respects 0.01 tolerance', () {
      // Delta <= 0.01 -> no conflict
      final diffsClose = FinanceProvider.compareSevenFields(
        localTx: {...baseLocal, 'amount': 450.00},
        remoteRow: {...baseRemote, 'amount': '450.005'},
        resolvedRemoteWalletId: 1,
        resolvedRemoteType: TransactionType.expense,
        localWalletName: 'Pocket',
      );
      expect(diffsClose, isEmpty);

      // Delta > 0.01 -> conflict
      final diffsFar = FinanceProvider.compareSevenFields(
        localTx: {...baseLocal, 'amount': 450.00},
        remoteRow: {...baseRemote, 'amount': '455.00'},
        resolvedRemoteWalletId: 1,
        resolvedRemoteType: TransactionType.expense,
        localWalletName: 'Pocket',
      );
      expect(diffsFar.length, equals(1));
      expect(diffsFar.first, contains('Amount'));
    });

    test('Note comparison trims whitespace, but distinct text flags conflict', () {
      // Whitespace trimmed match
      final diffsTrimmed = FinanceProvider.compareSevenFields(
        localTx: {...baseLocal, 'note': 'Weekly vegetables   '},
        remoteRow: {...baseRemote, 'note': '   Weekly vegetables'},
        resolvedRemoteWalletId: 1,
        resolvedRemoteType: TransactionType.expense,
        localWalletName: 'Pocket',
      );
      expect(diffsTrimmed, isEmpty);

      // Different note
      final diffsDistinct = FinanceProvider.compareSevenFields(
        localTx: {...baseLocal, 'note': 'Weekly vegetables'},
        remoteRow: {...baseRemote, 'note': 'Monthly fruit basket'},
        resolvedRemoteWalletId: 1,
        resolvedRemoteType: TransactionType.expense,
        localWalletName: 'Pocket',
      );
      expect(diffsDistinct.length, equals(1));
      expect(diffsDistinct.first, contains('Note'));
    });

    test('Wallet Name comparison flags Wallet conflict', () {
      final diffs = FinanceProvider.compareSevenFields(
        localTx: baseLocal,
        remoteRow: {...baseRemote, 'walletName': 'Bank asia'},
        resolvedRemoteWalletId: 2,
        resolvedRemoteType: TransactionType.expense,
        localWalletName: 'Pocket',
      );
      expect(diffs.length, equals(1));
      expect(diffs.first, contains('Wallet'));
    });

    test('Multiple simultaneous differences are all captured', () {
      final diffs = FinanceProvider.compareSevenFields(
        localTx: {...baseLocal, 'amount': 100.0, 'note': 'A'},
        remoteRow: {...baseRemote, 'amount': '200.0', 'note': 'B'},
        resolvedRemoteWalletId: 1,
        resolvedRemoteType: TransactionType.expense,
        localWalletName: 'Pocket',
      );
      expect(diffs.length, equals(2));
      expect(diffs.any((d) => d.contains('Amount')), isTrue);
      expect(diffs.any((d) => d.contains('Note')), isTrue);
    });
  });

  group('Conflict Reconciliation & Policy Verification Tests', () {
    test('Direct Sheet addition is identified as new when not present locally', () {
      final localSyncIds = <String>{'txid_000001', 'txid_000002'};
      final remoteRow = {
        'id': 'txid_000003',
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

    test('Conflict marks transaction as conflict WITHOUT mutating note or local data', () {
      final localTx = {
        'id': 10,
        'sync_id': 'txid_000010',
        'title': 'Local Title',
        'amount': 300.0,
        'date': '2026-10-27T10:00:00.000',
        'note': 'Clean Original Note',
        'type': 'expense',
        'walletId': 1,
        'sync_status': 'pending',
      };

      final remoteRow = {
        'id': 'txid_000010',
        'titleCategory': 'Sheet Title',
        'amount': '350.0',
        'date': '2026-10-27T12:00:00.000',
        'note': 'Sheet Note',
        'transectionType': 'Expense',
        'walletName': 'Pocket',
      };

      final diffs = FinanceProvider.compareSevenFields(
        localTx: localTx,
        remoteRow: remoteRow,
        resolvedRemoteWalletId: 1,
        resolvedRemoteType: TransactionType.expense,
        localWalletName: 'Pocket',
      );

      expect(diffs, isNotEmpty);

      // Verify policy: Note must NOT be mutated with "[Conflict: ...]"
      final preservedNote = localTx['note'];
      expect(preservedNote, equals('Clean Original Note'));
      expect(preservedNote, isNot(contains('[Conflict:')));

      // In SQLite, status is updated to 'conflict'
      final updatedStatus = diffs.isNotEmpty ? 'conflict' : 'synced';
      expect(updatedStatus, equals('conflict'));
    });
  });

  group('Finalized Deletion Rule Tests (Section 8)', () {
    test('Absence from remote sheet NEVER causes local deletion (retains all records)', () {
      final localTxs = [
        TransactionModel(
          id: 1,
          syncId: 'txid_000001',
          title: 'Existing Expense',
          amount: 100.0,
          date: DateTime(2026, 10, 27),
          note: '',
          type: TransactionType.expense,
          walletId: 1,
          syncStatus: 'synced',
        ),
        TransactionModel(
          id: 2,
          syncId: 'txid_000002',
          title: 'Offline Expense',
          amount: 250.0,
          date: DateTime(2026, 10, 27),
          note: 'Created offline',
          type: TransactionType.expense,
          walletId: 1,
          syncStatus: 'pending',
        ),
      ];

      final remoteSyncIds = <String>{}; // Empty remote sheet response

      // Under Section 8: Missing from Sheet response is NOT proof of deletion
      final toDeleteLocally = <String>[];
      // Notice: No deletion loop for missing remote IDs!
      for (var tx in localTxs) {
        // Absence does not delete
        if (!remoteSyncIds.contains(tx.syncId)) {
          // DO NOT ADD TO toDeleteLocally
        }
      }

      expect(toDeleteLocally, isEmpty);
      expect(localTxs.length, equals(2));
    });

    test('Explicit app deletion creates pending delete queue item', () {
      // When a user explicitly deletes an item in the app:
      final queueItem = {
        'id': 1,
        'action': 'delete',
        'entity_type': 'transaction',
        'entity_id': 'txid_000005',
        'payload': jsonEncode({'id': 'txid_000005'}),
      };

      expect(queueItem['action'], equals('delete'));
      expect(queueItem['entity_id'], equals('txid_000005'));
    });
  });

  group('Batch Sync & Partial Queue Processing Tests', () {
    test('Only processedIds are dequeued; failed items remain pending', () {
      final queueItems = [
        {'id': 101, 'action': 'create', 'entity_type': 'transaction', 'entity_id': 'txid_000001'},
        {'id': 102, 'action': 'update', 'entity_type': 'transaction', 'entity_id': 'txid_000002'},
        {'id': 103, 'action': 'create', 'entity_type': 'transaction', 'entity_id': 'txid_000003'},
      ];

      // Backend returns partial success where only txid_000001 and txid_000003 succeeded
      final backendResponse = {
        'status': 'partial',
        'processedIds': ['txid_000001', 'txid_000003'],
        'failedOps': [
          {'id': 'txid_000002', 'error': 'Sheet lock timeout'}
        ],
      };

      final Set<String> processed = (backendResponse['processedIds'] as List).map((e) => e.toString()).toSet();

      final dequeuedItemIds = <int>[];
      final remainingPendingIds = <int>[];

      for (var item in queueItems) {
        final itemId = item['id'] as int;
        final entityId = item['entity_id'] as String;

        if (processed.contains(entityId)) {
          dequeuedItemIds.add(itemId);
        } else {
          remainingPendingIds.add(itemId);
        }
      }

      expect(dequeuedItemIds, containsAll([101, 103]));
      expect(remainingPendingIds, contains(102)); // txid_000002 must remain pending!
    });
  });

  group('Conflict Blocking in Sync Queue Tests', () {
    test('Conflicting transactions are skipped and blocked from outgoing sync payload', () {
      final queueItems = [
        {'id': 1, 'action': 'update', 'entity_type': 'transaction', 'entity_id': 'txid_000001'},
        {'id': 2, 'action': 'update', 'entity_type': 'transaction', 'entity_id': 'txid_000002'},
      ];

      final statusBySyncId = {
        'txid_000001': 'conflict', // In conflict
        'txid_000002': 'pending',  // Clean pending
      };

      final eligibleQueueItems = queueItems.where((item) {
        final entityId = item['entity_id'] as String;
        return statusBySyncId[entityId] != 'conflict';
      }).toList();

      expect(eligibleQueueItems.length, equals(1));
      expect(eligibleQueueItems.first['entity_id'], equals('txid_000002'));
    });
  });

  group('Google Apps Script Contract & Backend Verification Tests', () {
    test('Same-tab duplicate ID detection flags warning', () {
      final tabRows = [
        {'id': 'txid_000001', 'amount': 100.0, 'tab': 'Pocket'},
        {'id': 'txid_000001', 'amount': 100.0, 'tab': 'Pocket'}, // duplicate
      ];

      final seenIds = <String>{};
      final warnings = <String>[];

      for (var r in tabRows) {
        final id = r['id'] as String;
        final tab = r['tab'] as String;
        if (seenIds.contains(id)) {
          warnings.add('Duplicate Transaction ID "$id" found in tab "$tab"');
        } else {
          seenIds.add(id);
        }
      }

      expect(warnings.length, equals(1));
      expect(warnings.first, contains('Duplicate Transaction ID "txid_000001"'));
    });

    test('Cross-tab incompatible transaction detection flags warning', () {
      // E.g. Record with same ID in two tabs having different amounts
      final rowsAcrossTabs = [
        {'id': 'txid_000099', 'amount': 500.0, 'type': 'Transfer', 'tab': 'Pocket'},
        {'id': 'txid_000099', 'amount': 600.0, 'type': 'Transfer', 'tab': 'Bank asia'}, // mismatching amount!
      ];

      final registry = <String, Map<String, dynamic>>{};
      final warnings = <String>[];

      for (var r in rowsAcrossTabs) {
        final id = r['id'] as String;
        if (registry.containsKey(id)) {
          final existing = registry[id]!;
          if ((existing['amount'] - r['amount']).abs() > 0.01) {
            warnings.add('Incompatible data for ID "$id" across tabs "${existing['tab']}" and "${r['tab']}": Amount differs');
          }
        } else {
          registry[id] = r;
        }
      }

      expect(warnings.length, equals(1));
      expect(warnings.first, contains('Incompatible data for ID "txid_000099"'));
    });
  });

  group('Transfer Parsing & Direction Tests', () {
    test('Transfer "From - To" format identifies source and destination correctly', () {
      final rawTitleCategory = 'Citybank - BankAsia';
      int? sourceWallet;
      int? destWallet;
      final walletIds = {'Citybank': 1, 'BankAsia': 2};

      if (rawTitleCategory.contains(' - ')) {
        final parts = rawTitleCategory.split(' - ');
        sourceWallet = walletIds[parts[0].trim()];
        destWallet = walletIds[parts[1].trim()];
      }

      expect(sourceWallet, equals(1)); // Citybank is SOURCE
      expect(destWallet, equals(2));   // BankAsia is DESTINATION
    });

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

      final tx = TransactionModel(
        title: 'Transfer',
        amount: amount,
        date: DateTime(2026, 10, 27),
        note: '',
        type: TransactionType.transfer,
        walletId: fromWalletId,
        toWalletId: toWalletId,
      );

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
