import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
/// and spreadsheet ('Financedatasheet').
///
/// Kept completely isolated from production SyncService until migration approval.
class DriveResourceService {
  static const String folderName = "Financedatabase";
  static const String sheetName = "Financedatasheet";

  static const String driveFileScope = "https://www.googleapis.com/auth/drive.file";
  static const String spreadsheetsScope = "https://www.googleapis.com/auth/spreadsheets";

  static const List<String> requiredScopes = [
    driveFileScope,
    spreadsheetsScope,
  ];

  final AuthService _authService;

  DriveResourceService({AuthService? authService})
      : _authService = authService ?? AuthService();

  /// Requests the necessary Google Drive and Google Sheets OAuth scopes.
  Future<bool> ensureRequiredScopes() async {
    final hasAccess = await _authService.hasScopes(requiredScopes);
    if (hasAccess) return true;
    return await _authService.requestAdditionalScopes(requiredScopes);
  }

  /// Finds or creates the dedicated 'Financedatabase' folder and 'Financedatasheet' spreadsheet.
  Future<DriveResourceResult> getOrCreateResources() async {
    final hasScopes = await ensureRequiredScopes();
    if (!hasScopes) {
      return const DriveResourceResult(
        isSuccess: false,
        errorMessage: "Google Drive and Sheets permissions were not granted.",
      );
    }

    final headers = await _authService.getAuthHeaders();
    if (headers == null) {
      return const DriveResourceResult(
        isSuccess: false,
        errorMessage: "User is not authenticated with Google.",
      );
    }

    try {
      // 1. Find or create folder 'Financedatabase'
      final folderId = await _findOrCreateFolder(headers);
      if (folderId == null) {
        return const DriveResourceResult(
          isSuccess: false,
          errorMessage: "Failed to locate or create 'Financedatabase' folder in Google Drive.",
        );
      }

      // 2. Find or create spreadsheet 'Financedatasheet' inside the folder
      final spreadsheetId = await _findOrCreateSpreadsheet(headers, folderId);
      if (spreadsheetId == null) {
        return DriveResourceResult(
          isSuccess: false,
          folderId: folderId,
          errorMessage: "Failed to locate or create 'Financedatasheet' spreadsheet.",
        );
      }

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
    }
  }

  Future<String?> _findOrCreateFolder(Map<String, String> headers) async {
    // Search for existing active folder
    final query = "name = '$folderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
    final searchUri = Uri.parse("https://www.googleapis.com/drive/v3/files?q=${Uri.encodeComponent(query)}&fields=files(id,name)");

    final searchRes = await http.get(searchUri, headers: headers);
    if (searchRes.statusCode == 200) {
      final data = jsonDecode(searchRes.body);
      final List files = data['files'] ?? [];
      if (files.isNotEmpty) {
        return files.first['id'] as String;
      }
    }

    // Folder does not exist -> Create it
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
    );

    if (createRes.statusCode == 200 || createRes.statusCode == 201) {
      final createdData = jsonDecode(createRes.body);
      return createdData['id'] as String?;
    }

    debugPrint("Failed to create folder: ${createRes.statusCode} - ${createRes.body}");
    return null;
  }

  Future<String?> _findOrCreateSpreadsheet(Map<String, String> headers, String folderId) async {
    // Search for existing active spreadsheet in the folder
    final query = "name = '$sheetName' and '$folderId' in parents and mimeType = 'application/vnd.google-apps.spreadsheet' and trashed = false";
    final searchUri = Uri.parse("https://www.googleapis.com/drive/v3/files?q=${Uri.encodeComponent(query)}&fields=files(id,name)");

    final searchRes = await http.get(searchUri, headers: headers);
    if (searchRes.statusCode == 200) {
      final data = jsonDecode(searchRes.body);
      final List files = data['files'] ?? [];
      if (files.isNotEmpty) {
        return files.first['id'] as String;
      }
    }

    // Spreadsheet does not exist in folder -> Create it
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
    );

    if (createRes.statusCode == 200 || createRes.statusCode == 201) {
      final createdData = jsonDecode(createRes.body);
      return createdData['id'] as String?;
    }

    debugPrint("Failed to create spreadsheet: ${createRes.statusCode} - ${createRes.body}");
    return null;
  }
}
