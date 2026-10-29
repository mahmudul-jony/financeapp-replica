import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'auth_service.dart';

class DriveResourceResult {
  final bool isSuccess;
  final String? folderId;
  final String? spreadsheetId;
  final String? errorMessage;

  const DriveResourceResult({
    required this.isSuccess,
    this.folderId,
    this.spreadsheetId,
    this.errorMessage,
  });
}

/// Service to manage the user's dedicated Google Drive folder ('Financedatabase')
/// and spreadsheet ('Financedatasheet') using Google Drive v3 and Sheets v4 APIs.
class DriveResourceService {
  static final DriveResourceService instance = DriveResourceService._internal();
  factory DriveResourceService() => instance;
  DriveResourceService._internal();

  static const String folderName = "Financedatabase";
  static const String sheetName = "Financedatasheet";

  static const String driveFileScope = "https://www.googleapis.com/auth/drive.file";
  static const String spreadsheetsScope = "https://www.googleapis.com/auth/spreadsheets";

  static const List<String> requiredScopes = [
    driveFileScope,
    spreadsheetsScope,
  ];

  static const List<String> defaultHeaders = [
    "ID",
    "Date",
    "Title / Category",
    "Transection Type",
    "Amount",
    "Note",
    "Wallet Name",
  ];

  static const List<String> defaultTabs = [
    "Main Wallet",
    "Loans",
  ];

  String? _cachedSpreadsheetId;
  String? _cachedFolderId;
  bool _isInitializing = false;

  String? get spreadsheetId => _cachedSpreadsheetId;
  String? get folderId => _cachedFolderId;

  /// Requests the necessary Google Drive and Google Sheets OAuth scopes.
  Future<bool> ensureRequiredScopes() async {
    final authService = AuthService();
    final hasAccess = await authService.hasScopes(requiredScopes);
    if (hasAccess) return true;
    return await authService.requestAdditionalScopes(requiredScopes);
  }

  /// Returns cached spreadsheetId or loads from disk/network.
  Future<String?> getSpreadsheetId() async {
    if (_cachedSpreadsheetId != null && _cachedSpreadsheetId!.isNotEmpty) {
      return _cachedSpreadsheetId;
    }
    await _loadFromLocalCache();
    if (_cachedSpreadsheetId != null && _cachedSpreadsheetId!.isNotEmpty) {
      return _cachedSpreadsheetId;
    }
    final res = await getOrCreateResources();
    return res.spreadsheetId;
  }

  /// Automatically locates/creates folder, spreadsheet, and default tabs upon user sign-in.
  Future<DriveResourceResult> getOrCreateResources() async {
    if (_isInitializing) {
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
      if (_cachedSpreadsheetId != null) {
        return DriveResourceResult(
          isSuccess: true,
          folderId: _cachedFolderId,
          spreadsheetId: _cachedSpreadsheetId,
        );
      }
    }

    _isInitializing = true;
    try {
      final authService = AuthService();
      final hasScopes = await ensureRequiredScopes();
      if (!hasScopes) {
        return const DriveResourceResult(
          isSuccess: false,
          errorMessage: "Google Drive and Sheets permissions were not granted.",
        );
      }

      final headers = await authService.getAuthHeaders();
      if (headers == null) {
        return const DriveResourceResult(
          isSuccess: false,
          errorMessage: "User is not authenticated with Google.",
        );
      }

      // Try local cache first
      await _loadFromLocalCache();

      // 1. Verify or find/create 'Financedatabase' folder
      String? folderId = _cachedFolderId;
      if (folderId == null || !await _verifyFileExists(headers, folderId)) {
        folderId = await _findOrCreateFolder(headers);
        if (folderId == null) {
          return const DriveResourceResult(
            isSuccess: false,
            errorMessage: "Failed to locate or create 'Financedatabase' folder in Google Drive.",
          );
        }
      }

      // 2. Verify or find/create 'Financedatasheet' spreadsheet inside folder
      String? spreadsheetId = _cachedSpreadsheetId;
      if (spreadsheetId == null || !await _verifyFileExists(headers, spreadsheetId)) {
        spreadsheetId = await _findOrCreateSpreadsheet(headers, folderId);
        if (spreadsheetId == null) {
          return DriveResourceResult(
            isSuccess: false,
            folderId: folderId,
            errorMessage: "Failed to locate or create 'Financedatasheet' spreadsheet.",
          );
        }
      }

      _cachedFolderId = folderId;
      _cachedSpreadsheetId = spreadsheetId;
      await _saveToLocalCache(folderId, spreadsheetId);

      // 3. Ensure default tabs and header rows exist in the spreadsheet
      await _ensureSpreadsheetStructure(headers, spreadsheetId);

      return DriveResourceResult(
        isSuccess: true,
        folderId: folderId,
        spreadsheetId: spreadsheetId,
      );
    } catch (e) {
      debugPrint("DriveResourceService Error: $e");
      return DriveResourceResult(
        isSuccess: false,
        errorMessage: "Drive resource error: $e",
      );
    } finally {
      _isInitializing = false;
    }
  }

  Future<bool> _verifyFileExists(Map<String, String> headers, String fileId) async {
    try {
      final uri = Uri.parse("https://www.googleapis.com/drive/v3/files/$fileId?fields=id,trashed");
      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['trashed'] != true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _findOrCreateFolder(Map<String, String> headers) async {
    final query = "name = '$folderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
    final searchUri = Uri.parse("https://www.googleapis.com/drive/v3/files?q=${Uri.encodeComponent(query)}&fields=files(id,name)");

    final searchRes = await http.get(searchUri, headers: headers).timeout(const Duration(seconds: 12));
    if (searchRes.statusCode == 200) {
      final data = jsonDecode(searchRes.body);
      final List files = data['files'] ?? [];
      if (files.isNotEmpty) {
        return files.first['id'] as String;
      }
    }

    // Create folder
    final createUri = Uri.parse("https://www.googleapis.com/drive/v3/files");
    final createRes = await http.post(
      createUri,
      headers: {
        ...headers,
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "name": folderName,
        "mimeType": "application/vnd.google-apps.folder",
      }),
    ).timeout(const Duration(seconds: 15));

    if (createRes.statusCode == 200 || createRes.statusCode == 201) {
      final createdData = jsonDecode(createRes.body);
      return createdData['id'] as String?;
    }

    debugPrint("Failed to create folder: ${createRes.statusCode} - ${createRes.body}");
    return null;
  }

  Future<String?> _findOrCreateSpreadsheet(Map<String, String> headers, String folderId) async {
    final query = "name = '$sheetName' and '$folderId' in parents and mimeType = 'application/vnd.google-apps.spreadsheet' and trashed = false";
    final searchUri = Uri.parse("https://www.googleapis.com/drive/v3/files?q=${Uri.encodeComponent(query)}&fields=files(id,name)");

    final searchRes = await http.get(searchUri, headers: headers).timeout(const Duration(seconds: 12));
    if (searchRes.statusCode == 200) {
      final data = jsonDecode(searchRes.body);
      final List files = data['files'] ?? [];
      if (files.isNotEmpty) {
        return files.first['id'] as String;
      }
    }

    // Create spreadsheet inside the folder
    final createUri = Uri.parse("https://www.googleapis.com/drive/v3/files");
    final createRes = await http.post(
      createUri,
      headers: {
        ...headers,
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "name": sheetName,
        "mimeType": "application/vnd.google-apps.spreadsheet",
        "parents": [folderId],
      }),
    ).timeout(const Duration(seconds: 15));

    if (createRes.statusCode == 200 || createRes.statusCode == 201) {
      final createdData = jsonDecode(createRes.body);
      return createdData['id'] as String?;
    }

    debugPrint("Failed to create spreadsheet: ${createRes.statusCode} - ${createRes.body}");
    return null;
  }

  /// Ensures default tabs ('Pocket', 'Bank asia', 'Loans', 'Savings', 'Investments') exist
  /// and each has the 7 standard columns in row 1.
  Future<void> _ensureSpreadsheetStructure(Map<String, String> headers, String spreadsheetId) async {
    try {
      final metaUri = Uri.parse("https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId?fields=sheets.properties(sheetId,title)");
      final metaRes = await http.get(metaUri, headers: headers).timeout(const Duration(seconds: 12));
      if (metaRes.statusCode != 200) return;

      final metaData = jsonDecode(metaRes.body);
      final List sheets = metaData['sheets'] ?? [];
      final Map<String, int> existingTabs = {};
      for (var s in sheets) {
        final props = s['properties'];
        if (props != null) {
          existingTabs[props['title'].toString()] = props['sheetId'] as int;
        }
      }

      final List<Map<String, dynamic>> requests = [];

      // If new spreadsheet only has "Sheet1" or legacy "Pocket", rename to "Main Wallet"
      if (existingTabs.containsKey("Sheet1") && !existingTabs.containsKey("Main Wallet")) {
        final sheet1Id = existingTabs["Sheet1"]!;
        requests.add({
          "updateSheetProperties": {
            "properties": {
              "sheetId": sheet1Id,
              "title": "Main Wallet",
            },
            "fields": "title",
          }
        });
        existingTabs.remove("Sheet1");
        existingTabs["Main Wallet"] = sheet1Id;
      } else if (existingTabs.containsKey("Pocket") && !existingTabs.containsKey("Main Wallet")) {
        final pocketId = existingTabs["Pocket"]!;
        requests.add({
          "updateSheetProperties": {
            "properties": {
              "sheetId": pocketId,
              "title": "Main Wallet",
            },
            "fields": "title",
          }
        });
        existingTabs.remove("Pocket");
        existingTabs["Main Wallet"] = pocketId;
      }

      // Add missing tabs from defaultTabs
      for (var tab in defaultTabs) {
        if (!existingTabs.containsKey(tab)) {
          requests.add({
            "addSheet": {
              "properties": {
                "title": tab,
              }
            }
          });
        }
      }

      if (requests.isNotEmpty) {
        final batchUri = Uri.parse("https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId:batchUpdate");
        await http.post(
          batchUri,
          headers: {
            ...headers,
            "Content-Type": "application/json",
          },
          body: jsonEncode({"requests": requests}),
        ).timeout(const Duration(seconds: 15));
      }

      // Ensure headers in Row 1 for each tab
      final List<String> rangesToFetch = defaultTabs.map((t) => "'$t'!A1:G1").toList();
      final batchGetUri = Uri.parse("https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values:batchGet?${rangesToFetch.map((r) => 'ranges=${Uri.encodeComponent(r)}').join('&')}");
      final batchGetRes = await http.get(batchGetUri, headers: headers).timeout(const Duration(seconds: 12));

      final List<Map<String, dynamic>> headerDataUpdates = [];
      if (batchGetRes.statusCode == 200) {
        final batchData = jsonDecode(batchGetRes.body);
        final List valRanges = batchData['valueRanges'] ?? [];

        for (var i = 0; i < defaultTabs.length; i++) {
          final tab = defaultTabs[i];
          bool hasHeader = false;
          if (i < valRanges.length) {
            final List rows = valRanges[i]['values'] ?? [];
            if (rows.isNotEmpty && (rows.first as List).isNotEmpty) {
              hasHeader = true;
            }
          }
          if (!hasHeader) {
            headerDataUpdates.add({
              "range": "'$tab'!A1:G1",
              "values": [defaultHeaders],
            });
          }
        }
      }

      if (headerDataUpdates.isNotEmpty) {
        final batchUpdateUri = Uri.parse("https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values:batchUpdate");
        await http.post(
          batchUpdateUri,
          headers: {
            ...headers,
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            "valueInputOption": "USER_ENTERED",
            "data": headerDataUpdates,
          }),
        ).timeout(const Duration(seconds: 15));
      }
    } catch (e) {
      debugPrint("Error ensuring spreadsheet structure: $e");
    }
  }

  // --- Local Cache Management ---
  Future<void> _loadFromLocalCache() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/drive_config.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content);
        final currentEmail = AuthService().currentUser?.email;
        if (currentEmail != null && data['user_email'] == currentEmail) {
          _cachedFolderId = data['folder_id'] as String?;
          _cachedSpreadsheetId = data['spreadsheet_id'] as String?;
        }
      }
    } catch (_) {}
  }

  Future<void> _saveToLocalCache(String folderId, String spreadsheetId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/drive_config.json');
      final currentEmail = AuthService().currentUser?.email ?? '';
      await file.writeAsString(jsonEncode({
        "user_email": currentEmail,
        "folder_id": folderId,
        "spreadsheet_id": spreadsheetId,
      }));
    } catch (_) {}
  }

  /// Clears cache when user logs out
  void clearCache() {
    _cachedFolderId = null;
    _cachedSpreadsheetId = null;
  }
}
