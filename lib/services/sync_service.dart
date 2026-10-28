import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/transaction_model.dart';
import 'auth_service.dart';
import 'drive_resource_service.dart';

class SheetFetchResult {
  final bool isSuccess;
  final List<Map<String, dynamic>> data;
  final List<String> warnings;
  final String? errorMessage;

  const SheetFetchResult({
    required this.isSuccess,
    required this.data,
    this.warnings = const [],
    this.errorMessage,
  });
}

/// Direct Google Sheets v4 and Google Drive v3 synchronization service.
/// Eliminates dependency on Google Apps Script and manual web app deployments.
class SyncService {
  static const String _sheetsBaseUrl = "https://sheets.googleapis.com/v4/spreadsheets";

  static Future<bool> isBackendReachable() async {
    final headers = await AuthService().getAuthHeaders();
    if (headers == null) return false;
    final spreadsheetId = await DriveResourceService.instance.getSpreadsheetId();
    return spreadsheetId != null && spreadsheetId.isNotEmpty;
  }

  /// Synchronizes a single transaction directly to the user's Google Sheet
  static Future<bool> syncTransaction(
    TransactionModel tx, 
    String walletName, 
    String titleCategory, 
    String typeLabel, {
    String action = 'create',
    String? secondaryTabName,
  }) async {
    final headers = await AuthService().getAuthHeaders();
    final spreadsheetId = await DriveResourceService.instance.getSpreadsheetId();
    if (headers == null || spreadsheetId == null) return false;

    try {
      final targetTab = _determinePrimaryTab(tx.type, walletName);
      final ok1 = await _syncSingleRow(
        headers: headers,
        spreadsheetId: spreadsheetId,
        tabName: targetTab,
        tx: tx,
        titleCategory: titleCategory,
        typeLabel: typeLabel,
        walletName: walletName,
        action: action,
      );

      bool ok2 = true;
      if (secondaryTabName != null && secondaryTabName.isNotEmpty && secondaryTabName != targetTab) {
        ok2 = await _syncSingleRow(
          headers: headers,
          spreadsheetId: spreadsheetId,
          tabName: secondaryTabName,
          tx: tx,
          titleCategory: titleCategory,
          typeLabel: typeLabel,
          walletName: secondaryTabName,
          action: action,
        );
      }

      return ok1 && ok2;
    } catch (e) {
      debugPrint("Direct Sheet syncTransaction Error: $e");
      return false;
    }
  }

  static String _determinePrimaryTab(TransactionType type, String walletName) {
    if (type == TransactionType.loanGiven ||
        type == TransactionType.loanTaken ||
        type == TransactionType.loanGivenMore ||
        type == TransactionType.loanTakenMore ||
        type == TransactionType.loanRecovered ||
        type == TransactionType.loanRepaid) {
      return "Loans";
    }
    if (type == TransactionType.savingsCreated ||
        type == TransactionType.savingsIncreased ||
        type == TransactionType.savingsWithdrawal) {
      return "Savings";
    }
    if (type == TransactionType.investmentCreated ||
        type == TransactionType.investmentIncreased ||
        type == TransactionType.investmentProfit ||
        type == TransactionType.investmentWithdraw ||
        type == TransactionType.investmentExpense ||
        type == TransactionType.investmentAdjustment) {
      return "Investments";
    }
    return walletName.isNotEmpty ? walletName : "Pocket";
  }

  static Future<bool> _syncSingleRow({
    required Map<String, String> headers,
    required String spreadsheetId,
    required String tabName,
    required TransactionModel tx,
    required String titleCategory,
    required String typeLabel,
    required String walletName,
    required String action,
  }) async {
    // 1. Ensure tab exists
    await createTab(tabName);

    final dateStr = "${tx.date.day.toString().padLeft(2, '0')}-${tx.date.month.toString().padLeft(2, '0')}-${tx.date.year.toString().substring(2)}";
    final rowValues = [
      tx.syncId,
      dateStr,
      titleCategory,
      typeLabel,
      tx.amount,
      tx.note,
      walletName,
    ];

    if (action == 'delete') {
      return await deleteTransaction(tx.syncId);
    }

    // 2. Search for existing row with syncId in Column A of tab
    final existingRowIndex = await _findRowIndexById(headers, spreadsheetId, tabName, tx.syncId);

    if (existingRowIndex != null) {
      // Update existing row
      final updateUri = Uri.parse("$_sheetsBaseUrl/$spreadsheetId/values/'$tabName'!A$existingRowIndex:G$existingRowIndex?valueInputOption=USER_ENTERED");
      final res = await http.put(
        updateUri,
        headers: {
          ...headers,
          "Content-Type": "application/json",
        },
        body: jsonEncode({"values": [rowValues]}),
      ).timeout(const Duration(seconds: 15));
      return res.statusCode == 200;
    } else {
      // Append new row
      final appendUri = Uri.parse("$_sheetsBaseUrl/$spreadsheetId/values/'$tabName'!A:G:append?valueInputOption=USER_ENTERED");
      final res = await http.post(
        appendUri,
        headers: {
          ...headers,
          "Content-Type": "application/json",
        },
        body: jsonEncode({"values": [rowValues]}),
      ).timeout(const Duration(seconds: 15));
      return res.statusCode == 200;
    }
  }

  static Future<int?> _findRowIndexById(
    Map<String, String> headers,
    String spreadsheetId,
    String tabName,
    String syncId,
  ) async {
    try {
      final uri = Uri.parse("$_sheetsBaseUrl/$spreadsheetId/values/'$tabName'!A:A");
      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List rows = data['values'] ?? [];
        for (var i = 0; i < rows.length; i++) {
          if (rows[i] is List && (rows[i] as List).isNotEmpty) {
            final cellId = rows[i][0].toString().trim();
            if (cellId == syncId.trim()) {
              return i + 1; // 1-based row index
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Deletes matching row(s) by syncId across all tabs
  static Future<bool> deleteTransaction(String syncId) async {
    final headers = await AuthService().getAuthHeaders();
    final spreadsheetId = await DriveResourceService.instance.getSpreadsheetId();
    if (headers == null || spreadsheetId == null) return false;

    try {
      final metaUri = Uri.parse("$_sheetsBaseUrl/$spreadsheetId?fields=sheets.properties(sheetId,title)");
      final metaRes = await http.get(metaUri, headers: headers).timeout(const Duration(seconds: 12));
      if (metaRes.statusCode != 200) return false;

      final metaData = jsonDecode(metaRes.body);
      final List sheets = metaData['sheets'] ?? [];

      final List<Map<String, dynamic>> deleteRequests = [];

      for (var s in sheets) {
        final props = s['properties'];
        if (props == null) continue;
        final sheetId = props['sheetId'] as int;
        final title = props['title'].toString();

        final rowIndex = await _findRowIndexById(headers, spreadsheetId, title, syncId);
        if (rowIndex != null && rowIndex > 1) { // Never delete row 1 header
          deleteRequests.add({
            "deleteDimension": {
              "range": {
                "sheetId": sheetId,
                "dimension": "ROWS",
                "startIndex": rowIndex - 1, // 0-based inclusive
                "endIndex": rowIndex,       // 0-based exclusive
              }
            }
          });
        }
      }

      if (deleteRequests.isNotEmpty) {
        final batchUri = Uri.parse("$_sheetsBaseUrl/$spreadsheetId:batchUpdate");
        final batchRes = await http.post(
          batchUri,
          headers: {
            ...headers,
            "Content-Type": "application/json",
          },
          body: jsonEncode({"requests": deleteRequests}),
        ).timeout(const Duration(seconds: 15));
        return batchRes.statusCode == 200;
      }
      return true;
    } catch (e) {
      debugPrint("Delete Tx Error: $e");
      return false;
    }
  }

  /// Executes batch sync operations directly against Google Sheets API
  static Future<Map<String, dynamic>> batchSync(List<Map<String, dynamic>> operations) async {
    final headers = await AuthService().getAuthHeaders();
    final spreadsheetId = await DriveResourceService.instance.getSpreadsheetId();
    if (headers == null || spreadsheetId == null || operations.isEmpty) {
      return {"success": false, "processedIds": <String>[]};
    }

    final List<String> processedIds = [];

    for (var op in operations) {
      try {
        final action = op['action']?.toString() ?? 'create';
        final payload = op['payload'];
        if (payload is! Map) continue;

        final id = payload['id']?.toString() ?? '';
        if (id.isEmpty) continue;

        if (action == 'delete') {
          final deleted = await deleteTransaction(id);
          if (deleted) processedIds.add(id);
        } else {
          final titleCat = payload['titleCategory']?.toString() ?? 'General';
          final typeLabel = payload['transectionType']?.toString() ?? 'Expense';
          final amount = double.tryParse(payload['amount']?.toString() ?? '0') ?? 0.0;
          final note = payload['note']?.toString() ?? '';
          final walletName = payload['walletName']?.toString() ?? 'Pocket';
          final secTab = payload['secondaryTabName']?.toString();

          final tx = TransactionModel(
            syncId: id,
            title: titleCat,
            amount: amount,
            date: DateTime.now(),
            note: note,
            type: TransactionType.expense,
            walletId: 1,
          );

          final success = await syncTransaction(
            tx,
            walletName,
            titleCat,
            typeLabel,
            action: action,
            secondaryTabName: secTab,
          );

          if (success) {
            processedIds.add(id);
          }
        }
      } catch (e) {
        debugPrint("Error executing batch item: $e");
      }
    }

    return {
      "success": processedIds.length == operations.length,
      "partial": processedIds.isNotEmpty && processedIds.length < operations.length,
      "processedIds": processedIds,
    };
  }

  /// Fetches all transaction data across all tabs from Google Sheets
  static Future<SheetFetchResult> fetchFromSheet() async {
    final headers = await AuthService().getAuthHeaders();
    final spreadsheetId = await DriveResourceService.instance.getSpreadsheetId();
    if (headers == null || spreadsheetId == null) {
      return const SheetFetchResult(
        isSuccess: false,
        data: [],
        errorMessage: "Google session or spreadsheet not ready.",
      );
    }

    try {
      // 1. Get list of all sheet tabs
      final metaUri = Uri.parse("$_sheetsBaseUrl/$spreadsheetId?fields=sheets.properties(sheetId,title)");
      final metaRes = await http.get(metaUri, headers: headers).timeout(const Duration(seconds: 12));
      if (metaRes.statusCode != 200) {
        return SheetFetchResult(
          isSuccess: false,
          data: [],
          errorMessage: "Failed to read spreadsheet metadata: HTTP ${metaRes.statusCode}",
        );
      }

      final metaData = jsonDecode(metaRes.body);
      final List sheets = metaData['sheets'] ?? [];
      final List<String> tabTitles = [];
      for (var s in sheets) {
        final props = s['properties'];
        if (props != null && props['title'] != null) {
          tabTitles.add(props['title'].toString());
        }
      }

      if (tabTitles.isEmpty) {
        return const SheetFetchResult(isSuccess: true, data: []);
      }

      // 2. Batch get data rows A2:G for all tabs
      final rangesQuery = tabTitles.map((t) => "ranges=${Uri.encodeComponent("'$t'!A2:G")}").join('&');
      final batchGetUri = Uri.parse("$_sheetsBaseUrl/$spreadsheetId/values:batchGet?$rangesQuery");
      final batchGetRes = await http.get(batchGetUri, headers: headers).timeout(const Duration(seconds: 20));

      if (batchGetRes.statusCode != 200) {
        return SheetFetchResult(
          isSuccess: false,
          data: [],
          errorMessage: "Failed to read sheet data: HTTP ${batchGetRes.statusCode}",
        );
      }

      final batchData = jsonDecode(batchGetRes.body);
      final List valueRanges = batchData['valueRanges'] ?? [];

      final List<Map<String, dynamic>> allData = [];
      final List<String> warnings = [];
      final Map<String, Set<String>> tabIdsMap = {};
      final Map<String, Map<String, dynamic>> globalRegistry = {};

      for (var i = 0; i < tabTitles.length; i++) {
        final tabName = tabTitles[i];
        final valRange = i < valueRanges.length ? valueRanges[i] : null;
        final List rows = (valRange != null && valRange['values'] is List) ? valRange['values'] : [];
        tabIdsMap[tabName] = {};

        for (var row in rows) {
          if (row is! List || row.isEmpty) continue;
          final id = row[0]?.toString().trim() ?? '';
          if (id.isEmpty) continue;

          // Same-tab duplicate ID check
          if (tabIdsMap[tabName]!.contains(id)) {
            warnings.add('Duplicate Transaction ID "$id" found in tab "$tabName"');
          } else {
            tabIdsMap[tabName]!.add(id);
          }

          final date = row.length > 1 ? row[1]?.toString() ?? '' : '';
          final titleCat = row.length > 2 ? row[2]?.toString() ?? 'General' : 'General';
          final typeLabel = row.length > 3 ? row[3]?.toString() ?? 'Expense' : 'Expense';
          final amount = row.length > 4 ? (double.tryParse(row[4]?.toString() ?? '0') ?? 0.0) : 0.0;
          final note = row.length > 5 ? row[5]?.toString() ?? '' : '';
          final walletName = row.length > 6 ? row[6]?.toString() ?? tabName : tabName;

          final record = {
            'id': id,
            'date': date,
            'titleCategory': titleCat,
            'transectionType': typeLabel,
            'amount': amount,
            'note': note,
            'walletName': walletName,
          };

          // Cross-tab consistency check
          if (globalRegistry.containsKey(id)) {
            final prev = globalRegistry[id]!;
            final prevAmount = prev['amount'] as double? ?? 0.0;
            if ((prevAmount - amount).abs() > 0.01) {
              warnings.add('Incompatible data for ID "$id" across tabs: Amount differs ($prevAmount vs $amount)');
            }
          } else {
            globalRegistry[id] = {...record, 'tab': tabName};
            allData.add(record);
          }
        }
      }

      return SheetFetchResult(
        isSuccess: true,
        data: allData,
        warnings: warnings,
      );
    } catch (e) {
      debugPrint("fetchFromSheet Error: $e");
      return SheetFetchResult(
        isSuccess: false,
        data: [],
        errorMessage: e.toString(),
      );
    }
  }

  /// Creates a new tab with default 7-column header row
  static Future<bool> createTab(String tabName) async {
    final headers = await AuthService().getAuthHeaders();
    final spreadsheetId = await DriveResourceService.instance.getSpreadsheetId();
    if (headers == null || spreadsheetId == null) return false;

    try {
      final metaUri = Uri.parse("$_sheetsBaseUrl/$spreadsheetId?fields=sheets.properties(sheetId,title)");
      final metaRes = await http.get(metaUri, headers: headers).timeout(const Duration(seconds: 12));
      if (metaRes.statusCode == 200) {
        final metaData = jsonDecode(metaRes.body);
        final List sheets = metaData['sheets'] ?? [];
        for (var s in sheets) {
          if (s['properties']?['title']?.toString() == tabName) {
            return true; // Already exists
          }
        }
      }

      // Add sheet
      final batchUri = Uri.parse("$_sheetsBaseUrl/$spreadsheetId:batchUpdate");
      final addRes = await http.post(
        batchUri,
        headers: {
          ...headers,
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "requests": [
            {
              "addSheet": {
                "properties": {
                  "title": tabName,
                }
              }
            }
          ]
        }),
      ).timeout(const Duration(seconds: 15));

      if (addRes.statusCode == 200) {
        // Write header row
        final headerUri = Uri.parse("$_sheetsBaseUrl/$spreadsheetId/values/'$tabName'!A1:G1?valueInputOption=USER_ENTERED");
        await http.put(
          headerUri,
          headers: {
            ...headers,
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            "values": [DriveResourceService.defaultHeaders]
          }),
        ).timeout(const Duration(seconds: 15));
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Create Tab Error: $e");
      return false;
    }
  }

  /// Renames an existing tab
  static Future<bool> renameTab(String oldTabName, String newTabName) async {
    final headers = await AuthService().getAuthHeaders();
    final spreadsheetId = await DriveResourceService.instance.getSpreadsheetId();
    if (headers == null || spreadsheetId == null) return false;

    try {
      final metaUri = Uri.parse("$_sheetsBaseUrl/$spreadsheetId?fields=sheets.properties(sheetId,title)");
      final metaRes = await http.get(metaUri, headers: headers).timeout(const Duration(seconds: 12));
      if (metaRes.statusCode != 200) return false;

      final metaData = jsonDecode(metaRes.body);
      final List sheets = metaData['sheets'] ?? [];
      int? sheetIdToRename;
      for (var s in sheets) {
        if (s['properties']?['title']?.toString() == oldTabName) {
          sheetIdToRename = s['properties']['sheetId'] as int;
          break;
        }
      }

      if (sheetIdToRename == null) return false;

      final batchUri = Uri.parse("$_sheetsBaseUrl/$spreadsheetId:batchUpdate");
      final renameRes = await http.post(
        batchUri,
        headers: {
          ...headers,
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "requests": [
            {
              "updateSheetProperties": {
                "properties": {
                  "sheetId": sheetIdToRename,
                  "title": newTabName,
                },
                "fields": "title",
              }
            }
          ]
        }),
      ).timeout(const Duration(seconds: 15));
      return renameRes.statusCode == 200;
    } catch (e) {
      debugPrint("Rename Tab Error: $e");
      return false;
    }
  }

  static Future<bool> updateWalletName(String oldName, String newName) => renameTab(oldName, newName);

  static Future<bool> updateCategoryName(String oldName, String newName) async => true;

  /// Clears all data rows (row 2 downwards) in all tabs, preserving headers in row 1
  static Future<bool> resetSheet() async {
    final headers = await AuthService().getAuthHeaders();
    final spreadsheetId = await DriveResourceService.instance.getSpreadsheetId();
    if (headers == null || spreadsheetId == null) return false;

    try {
      final metaUri = Uri.parse("$_sheetsBaseUrl/$spreadsheetId?fields=sheets.properties(sheetId,title)");
      final metaRes = await http.get(metaUri, headers: headers).timeout(const Duration(seconds: 12));
      if (metaRes.statusCode != 200) return false;

      final metaData = jsonDecode(metaRes.body);
      final List sheets = metaData['sheets'] ?? [];
      final List<String> rangesToClear = [];
      for (var s in sheets) {
        final title = s['properties']?['title']?.toString();
        if (title != null && title.isNotEmpty) {
          rangesToClear.add("'$title'!A2:G");
        }
      }

      if (rangesToClear.isNotEmpty) {
        final clearUri = Uri.parse("$_sheetsBaseUrl/$spreadsheetId/values:batchClear");
        final clearRes = await http.post(
          clearUri,
          headers: {
            ...headers,
            "Content-Type": "application/json",
          },
          body: jsonEncode({"ranges": rangesToClear}),
        ).timeout(const Duration(seconds: 15));
        return clearRes.statusCode == 200;
      }
      return true;
    } catch (e) {
      debugPrint("Reset Sheet Error: $e");
      return false;
    }
  }
}
