import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/transaction_model.dart';

class SyncService {
  // Deployed Web App URL from Apps Scripts
  static const String _scriptUrl = "https://script.google.com/macros/s/AKfycbw0OCzz3ghCT5WOY13trQCuRb0brjmqnW99J93KCmHvVyVp05kRJz9ZpXC5DBGCCVdZwA/exec";

  static Future<bool> isBackendReachable() async {
    if (_scriptUrl.isEmpty) return false;
    try {
      final response = await http.get(Uri.parse(_scriptUrl)).timeout(const Duration(seconds: 4));
      return response.statusCode == 200 || response.statusCode == 302;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> syncTransaction(
    TransactionModel tx, 
    String walletName, 
    String titleCategory, 
    String typeLabel, {
    String action = 'create',
    String? secondaryTabName,
  }) async {
    if (_scriptUrl.isEmpty) return false;

    try {
      final response = await http.post(
        Uri.parse(_scriptUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "action": action,
          "payload": {
            "id": tx.syncId,
            "date": "${tx.date.day.toString().padLeft(2, '0')}-${tx.date.month.toString().padLeft(2, '0')}-${tx.date.year.toString().substring(2)}",
            "titleCategory": titleCategory,
            "transectionType": typeLabel,
            "amount": tx.amount,
            "note": tx.note,
            "walletName": walletName,
            ...? (secondaryTabName != null ? {"secondaryTabName": secondaryTabName} : null),
            "updatedAt": (tx.updatedAt ?? DateTime.now()).toIso8601String(),
          }
        }),
      ).timeout(const Duration(seconds: 15));

      debugPrint("Sync Response: ${response.statusCode} - ${response.body}");
      return response.statusCode == 200 || response.statusCode == 302;
    } catch (e) {
      debugPrint("Sync Error: $e");
      return false;
    }
  }

  static Future<bool> deleteTransaction(String syncId) async {
    if (_scriptUrl.isEmpty) return false;

    try {
      final response = await http.post(
        Uri.parse(_scriptUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "action": "delete",
          "payload": {
            "id": syncId,
          }
        }),
      ).timeout(const Duration(seconds: 15));

      debugPrint("Delete Tx Response: ${response.statusCode} - ${response.body}");
      return response.statusCode == 200 || response.statusCode == 302;
    } catch (e) {
      debugPrint("Delete Tx Error: $e");
      return false;
    }
  }

  static Future<Map<String, dynamic>> batchSync(List<Map<String, dynamic>> operations) async {
    if (_scriptUrl.isEmpty || operations.isEmpty) {
      return {"success": false, "processedIds": <String>[]};
    }

    try {
      final response = await http.post(
        Uri.parse(_scriptUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "action": "batch_sync",
          "operations": operations,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 302) {
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['status'] == 'success') {
            final List<dynamic> ids = decoded['processedIds'] ?? [];
            return {
              "success": true,
              "processedIds": ids.map((e) => e.toString()).toList(),
            };
          }
        } catch (_) {}
        return {"success": true, "processedIds": <String>[]};
      }
    } catch (e) {
      debugPrint("Batch Sync Error: $e");
    }
    return {"success": false, "processedIds": <String>[]};
  }

  static Future<bool> createTab(String tabName) async {
    if (_scriptUrl.isEmpty) return false;

    try {
      final response = await http.post(
        Uri.parse(_scriptUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "action": "create_tab",
          "tabName": tabName,
        }),
      ).timeout(const Duration(seconds: 15));
      return response.statusCode == 200 || response.statusCode == 302;
    } catch (e) {
      debugPrint("Create Tab Error: $e");
      return false;
    }
  }

  static Future<bool> updateCategoryName(String oldName, String newName) async {
    if (_scriptUrl.isEmpty) return false;

    try {
      final response = await http.post(
        Uri.parse(_scriptUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "action": "update_category_name",
          "oldName": oldName,
          "newName": newName,
        }),
      ).timeout(const Duration(seconds: 15));
      return response.statusCode == 200 || response.statusCode == 302;
    } catch (e) {
      debugPrint("Update Category Name Error: $e");
      return false;
    }
  }

  static Future<bool> renameTab(String oldTabName, String newTabName) async {
    if (_scriptUrl.isEmpty) return false;

    try {
      final response = await http.post(
        Uri.parse(_scriptUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "action": "rename_tab",
          "oldTabName": oldTabName,
          "newTabName": newTabName,
        }),
      ).timeout(const Duration(seconds: 15));
      return response.statusCode == 200 || response.statusCode == 302;
    } catch (e) {
      debugPrint("Rename Tab Error: $e");
      return false;
    }
  }

  static Future<bool> updateWalletName(String oldName, String newName) async {
    if (_scriptUrl.isEmpty) return false;

    try {
      final response = await http.post(
        Uri.parse(_scriptUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "action": "update_wallet_name",
          "oldName": oldName,
          "newName": newName,
        }),
      ).timeout(const Duration(seconds: 15));
      return response.statusCode == 200 || response.statusCode == 302;
    } catch (e) {
      debugPrint("Update Wallet Name Error: $e");
      return false;
    }
  }

  static Future<bool> resetSheet() async {
    if (_scriptUrl.isEmpty) return false;

    try {
      final response = await http.post(
        Uri.parse(_scriptUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"action": "reset"}),
      ).timeout(const Duration(seconds: 20));
      return response.statusCode == 200 || response.statusCode == 302;
    } catch (e) {
      debugPrint("Reset Sheet Error: $e");
      return false;
    }
  }

  static Future<List<dynamic>> fetchFromSheet() async {
    if (_scriptUrl.isEmpty) return [];

    try {
      final response = await http.get(Uri.parse(_scriptUrl)).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200 || response.statusCode == 302) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded;
        }
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
    }
    return [];
  }
}
