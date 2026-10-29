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

  static String walletTabName(String walletName) {
    final trimmed = walletName.trim();
    if (trimmed.startsWith('Wallet-')) return trimmed;
    return 'Wallet-$trimmed';
  }

  static String savingsTabName(String savingsName) {
    final trimmed = savingsName.trim();
    if (trimmed.startsWith('Saving-')) return trimmed;
    return 'Saving-$trimmed';
  }

  static String investmentTabName(String investmentName) {
    final trimmed = investmentName.trim();
    if (trimmed.startsWith('Invest-')) return trimmed;
    return 'Invest-$trimmed';
  }

  static const String loansTabName = 'Loans';

  static String stripTabPrefix(String tabName) {
    final trimmed = tabName.trim();
    if (trimmed.startsWith('Wallet-')) return trimmed.substring('Wallet-'.length);
    if (trimmed.startsWith('Saving-')) return trimmed.substring('Saving-'.length);
    if (trimmed.startsWith('Invest-')) return trimmed.substring('Invest-'.length);
    return trimmed;
  }

  static List<String> getTabsForTransaction(TransactionType type, String walletName, {String? secondaryTabName}) {
    final List<String> tabs = [];

    final wName = walletName.trim();
    final sName = secondaryTabName?.trim();

    if (type == TransactionType.transfer) {
      if (wName.isNotEmpty && wName != 'N/A') {
        tabs.add(walletTabName(wName));
      }
      if (sName != null && sName.isNotEmpty && sName != 'N/A' && sName.toLowerCase() != wName.toLowerCase()) {
        tabs.add(walletTabName(sName));
      }
    } else if (type == TransactionType.loanGiven ||
        type == TransactionType.loanTaken ||
        type == TransactionType.loanGivenMore ||
        type == TransactionType.loanTakenMore ||
        type == TransactionType.loanRecovered ||
        type == TransactionType.loanRepaid) {
      tabs.add(loansTabName);
      if (wName.isNotEmpty && wName != 'N/A' && wName != 'Loans') {
        tabs.add(walletTabName(wName));
      }
    } else if (type == TransactionType.savingsCreated ||
        type == TransactionType.savingsIncreased ||
        type == TransactionType.savingsWithdrawal) {
      if (sName != null && sName.isNotEmpty) {
        tabs.add(savingsTabName(sName));
      }
      if (wName.isNotEmpty && wName != 'N/A' && wName != 'Savings') {
        tabs.add(walletTabName(wName));
      }
    } else if (type == TransactionType.investmentCreated ||
        type == TransactionType.investmentIncreased ||
        type == TransactionType.investmentProfit ||
        type == TransactionType.investmentWithdraw ||
        type == TransactionType.investmentExpense ||
        type == TransactionType.investmentAdjustment) {
      if (sName != null && sName.isNotEmpty) {
        tabs.add(investmentTabName(sName));
      }
      if (wName.isNotEmpty && wName != 'N/A' && wName != 'Investments' && wName != 'Investment Principal') {
        tabs.add(walletTabName(wName));
      }
    } else {
      final targetWallet = (wName.isNotEmpty && wName != 'N/A') ? wName : 'Main Wallet';
      tabs.add(walletTabName(targetWallet));
    }

    return tabs.toSet().toList();
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

    if (action == 'delete') {
      return await deleteTransaction(tx.syncId);
    }

    try {
      final targetTabs = getTabsForTransaction(tx.type, walletName, secondaryTabName: secondaryTabName);
      bool allSuccess = true;
      for (var tab in targetTabs) {
        final ok = await _syncSingleRow(
          headers: headers,
          spreadsheetId: spreadsheetId,
          tabName: tab,
          tx: tx,
          titleCategory: titleCategory,
          typeLabel: typeLabel,
          walletName: walletName,
          action: action,
        );
        if (!ok) allSuccess = false;
      }
      return allSuccess;
    } catch (e) {
      debugPrint("Direct Sheet syncTransaction Error: $e");
      return false;
    }
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
      final range = Uri.encodeComponent("'$tabName'!A$existingRowIndex:G$existingRowIndex");
      final updateUri = Uri.parse("$_sheetsBaseUrl/$spreadsheetId/values/$range?valueInputOption=USER_ENTERED");
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
      final range = Uri.encodeComponent("'$tabName'!A:G");
      final appendUri = Uri.parse("$_sheetsBaseUrl/$spreadsheetId/values/$range:append?valueInputOption=USER_ENTERED");
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
      final range = Uri.encodeComponent("'$tabName'!A:A");
      final uri = Uri.parse("$_sheetsBaseUrl/$spreadsheetId/values/$range");
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
            "_sheetId": sheetId,
            "_startIndex": rowIndex - 1,
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
        // Sort descending by startIndex so row indices don't shift when deleting in same sheet
        deleteRequests.sort((a, b) => (b['_startIndex'] as int).compareTo(a['_startIndex'] as int));
        final cleanRequests = deleteRequests.map((r) => {
          "deleteDimension": r["deleteDimension"],
        }).toList();

        final batchUri = Uri.parse("$_sheetsBaseUrl/$spreadsheetId:batchUpdate");
        final batchRes = await http.post(
          batchUri,
          headers: {
            ...headers,
            "Content-Type": "application/json",
          },
          body: jsonEncode({"requests": cleanRequests}),
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
          final walletName = payload['walletName']?.toString() ?? 'Main Wallet';
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
          final rawWallet = row.length > 6 ? (row[6]?.toString() ?? tabName) : tabName;
          final walletName = stripTabPrefix(rawWallet);

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
        final range = Uri.encodeComponent("'$tabName'!A1:G1");
        final headerUri = Uri.parse("$_sheetsBaseUrl/$spreadsheetId/values/$range?valueInputOption=USER_ENTERED");
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
        final title = s['properties']?['title']?.toString();
        if (title == oldTabName || (title != null && stripTabPrefix(title) == stripTabPrefix(oldTabName))) {
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

  /// Deletes a sheet tab by name
  static Future<bool> deleteTab(String tabName) async {
    final headers = await AuthService().getAuthHeaders();
    final spreadsheetId = await DriveResourceService.instance.getSpreadsheetId();
    if (headers == null || spreadsheetId == null) return false;

    try {
      final metaUri = Uri.parse("$_sheetsBaseUrl/$spreadsheetId?fields=sheets.properties(sheetId,title)");
      final metaRes = await http.get(metaUri, headers: headers).timeout(const Duration(seconds: 12));
      if (metaRes.statusCode != 200) return false;

      final metaData = jsonDecode(metaRes.body);
      final List sheets = metaData['sheets'] ?? [];
      int? sheetIdToDelete;
      for (var s in sheets) {
        final title = s['properties']?['title']?.toString();
        if (title == tabName || (title != null && stripTabPrefix(title) == stripTabPrefix(tabName))) {
          sheetIdToDelete = s['properties']['sheetId'] as int;
          break;
        }
      }

      if (sheetIdToDelete == null) return true; // Already deleted or doesn't exist

      // A spreadsheet must contain at least 1 sheet
      if (sheets.length <= 1) return false;

      final batchUri = Uri.parse("$_sheetsBaseUrl/$spreadsheetId:batchUpdate");
      final deleteRes = await http.post(
        batchUri,
        headers: {
          ...headers,
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "requests": [
            {
              "deleteSheet": {
                "sheetId": sheetIdToDelete,
              }
            }
          ]
        }),
      ).timeout(const Duration(seconds: 15));
      return deleteRes.statusCode == 200;
    } catch (e) {
      debugPrint("Delete Tab Error: $e");
      return false;
    }
  }

  /// Replaces text across all cells in all tabs of the spreadsheet using findReplace
  static Future<bool> replaceTextInSpreadsheet({
    required String find,
    required String replacement,
    bool matchEntireCell = true,
  }) async {
    if (find.isEmpty || find == replacement) return true;
    final headers = await AuthService().getAuthHeaders();
    final spreadsheetId = await DriveResourceService.instance.getSpreadsheetId();
    if (headers == null || spreadsheetId == null) return false;

    try {
      final batchUri = Uri.parse("$_sheetsBaseUrl/$spreadsheetId:batchUpdate");
      final res = await http.post(
        batchUri,
        headers: {
          ...headers,
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "requests": [
            {
              "findReplace": {
                "find": find,
                "replacement": replacement,
                "matchCase": false,
                "matchEntireCell": matchEntireCell,
                "allSheets": true,
              }
            }
          ]
        }),
      ).timeout(const Duration(seconds: 15));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint("replaceTextInSpreadsheet Error: $e");
      return false;
    }
  }

  static Future<bool> updateWalletName(String oldName, String newName) async {
    final oldTab = walletTabName(oldName);
    final newTab = walletTabName(newName);
    final renamed = await renameTab(oldTab, newTab);
    final replaced = await replaceTextInSpreadsheet(find: oldName, replacement: newName, matchEntireCell: true);
    return renamed || replaced;
  }

  static Future<bool> updateCategoryName(String oldName, String newName) async {
    return await replaceTextInSpreadsheet(find: oldName, replacement: newName, matchEntireCell: true);
  }

  static Future<bool> clearCategoryName(String categoryName) async {
    return await replaceTextInSpreadsheet(find: categoryName, replacement: "-", matchEntireCell: true);
  }

  /// Wipes all non-default tabs and clears all transaction rows (row 2 downwards),
  /// leaving only default tabs ('Wallet-Main Wallet', 'Loans') with row 1 headers.
  static Future<bool> resetSheet({String defaultWalletName = "Wallet-Main Wallet"}) async {
    final headers = await AuthService().getAuthHeaders();
    final spreadsheetId = await DriveResourceService.instance.getSpreadsheetId();
    if (headers == null || spreadsheetId == null) return false;

    try {
      final metaUri = Uri.parse("$_sheetsBaseUrl/$spreadsheetId?fields=sheets.properties(sheetId,title)");
      final metaRes = await http.get(metaUri, headers: headers).timeout(const Duration(seconds: 12));
      if (metaRes.statusCode != 200) return false;

      final metaData = jsonDecode(metaRes.body);
      final List sheets = metaData['sheets'] ?? [];
      final defTab = walletTabName(defaultWalletName);
      final Set<String> keepTabs = {defTab, "Loans"};

      // Ensure default tabs exist first before deleting others
      for (var tab in keepTabs) {
        await createTab(tab);
      }

      // Re-fetch sheet list to get up-to-date IDs
      final updatedMetaRes = await http.get(metaUri, headers: headers).timeout(const Duration(seconds: 12));
      final List updatedSheets = (updatedMetaRes.statusCode == 200)
          ? (jsonDecode(updatedMetaRes.body)['sheets'] ?? [])
          : sheets;

      final List<Map<String, dynamic>> deleteRequests = [];
      for (var s in updatedSheets) {
        final title = s['properties']?['title']?.toString();
        final sheetId = s['properties']?['sheetId'] as int?;
        if (title != null && !keepTabs.contains(title) && sheetId != null) {
          deleteRequests.add({
            "deleteSheet": {"sheetId": sheetId}
          });
        }
      }

      if (deleteRequests.isNotEmpty) {
        final batchUri = Uri.parse("$_sheetsBaseUrl/$spreadsheetId:batchUpdate");
        await http.post(
          batchUri,
          headers: {
            ...headers,
            "Content-Type": "application/json",
          },
          body: jsonEncode({"requests": deleteRequests}),
        ).timeout(const Duration(seconds: 15));
      }

      // Clear all rows from row 2 downwards in remaining default tabs
      final List<String> rangesToClear = keepTabs.map((t) => "'$t'!A2:G").toList();
      final clearUri = Uri.parse("$_sheetsBaseUrl/$spreadsheetId/values:batchClear");
      await http.post(
        clearUri,
        headers: {
          ...headers,
          "Content-Type": "application/json",
        },
        body: jsonEncode({"ranges": rangesToClear}),
      ).timeout(const Duration(seconds: 15));

      return true;
    } catch (e) {
      debugPrint("Reset Sheet Error: $e");
      return false;
    }
  }
}
