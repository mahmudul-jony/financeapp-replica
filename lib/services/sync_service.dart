import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/transaction_model.dart';

class SyncService {
  // TODO: Replace with your deployed Web App URL from Apps Scripts
  static const String _scriptUrl = "https://script.google.com/macros/s/AKfycbw0OCzz3ghCT5WOY13trQCuRb0brjmqnW99J93KCmHvVyVp05kRJz9ZpXC5DBGCCVdZwA/exec";

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
            "id": tx.id,
            "date": "${tx.date.day.toString().padLeft(2, '0')}-${tx.date.month.toString().padLeft(2, '0')}-${tx.date.year.toString().substring(2)}",
            "titleCategory": titleCategory,
            "transectionType": typeLabel,
            "amount": tx.amount,
            "note": tx.note,
            "walletName": walletName,
            if (secondaryTabName != null) "secondaryTabName": secondaryTabName,
          }
        }),
      );

      print("Sync Response: ${response.statusCode} - ${response.body}");
      return response.statusCode == 200 || response.statusCode == 302;
    } catch (e) {
      print("Sync Error: $e");
      return false;
    }
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
      );
      return response.statusCode == 200 || response.statusCode == 302;
    } catch (e) {
      print("Create Tab Error: $e");
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
      );
      return response.statusCode == 200 || response.statusCode == 302;
    } catch (e) {
      print("Update Category Name Error: $e");
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
      );
      return response.statusCode == 200 || response.statusCode == 302;
    } catch (e) {
      print("Rename Tab Error: $e");
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
      );
      return response.statusCode == 200 || response.statusCode == 302;
    } catch (e) {
      print("Update Wallet Name Error: $e");
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
      );
      return response.statusCode == 200 || response.statusCode == 302;
    } catch (e) {
      print("Reset Sheet Error: $e");
      return false;
    }
  }

  static Future<List<dynamic>> fetchFromSheet() async {
    if (_scriptUrl.isEmpty) return [];

    try {
      final response = await http.get(Uri.parse(_scriptUrl));
      if (response.statusCode == 200 || response.statusCode == 302) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Fetch Error: $e");
    }
    return [];
  }
}
