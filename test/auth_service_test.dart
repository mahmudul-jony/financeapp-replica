import 'package:flutter_test/flutter_test.dart';
import 'package:financeapp/services/auth_service.dart';
import 'package:financeapp/services/drive_resource_service.dart';

void main() {
  group('AuthService Initialization & State Tests', () {
    test('AuthService initial state is not authenticated', () {
      final auth = AuthService();
      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentUser, isNull);
      expect(auth.isLoading, isFalse);
    });

    test('AuthService is a singleton', () {
      final a1 = AuthService();
      final a2 = AuthService();
      expect(identical(a1, a2), isTrue);
    });
  });

  group('DriveResourceService Constants & Scope Configuration Tests', () {
    test('Resource names strictly match required folder and sheet names', () {
      expect(DriveResourceService.folderName, equals('Financedatabase'));
      expect(DriveResourceService.sheetName, equals('Financedatasheet'));
    });

    test('Required OAuth scopes include minimal drive.file and spreadsheets scopes', () {
      expect(DriveResourceService.driveFileScope, equals('https://www.googleapis.com/auth/drive.file'));
      expect(DriveResourceService.spreadsheetsScope, equals('https://www.googleapis.com/auth/spreadsheets'));

      final scopes = DriveResourceService.requiredScopes;
      expect(scopes, contains('https://www.googleapis.com/auth/drive.file'));
      expect(scopes, contains('https://www.googleapis.com/auth/spreadsheets'));
      // Ensure broad invasive 'drive' scope is NOT used
      expect(scopes, isNot(contains('https://www.googleapis.com/auth/drive')));
    });

    test('DriveResourceResult encapsulates success, IDs, and error message', () {
      const resSuccess = DriveResourceResult(
        isSuccess: true,
        folderId: 'folder_123',
        spreadsheetId: 'sheet_456',
      );
      expect(resSuccess.isSuccess, isTrue);
      expect(resSuccess.folderId, equals('folder_123'));
      expect(resSuccess.spreadsheetId, equals('sheet_456'));
      expect(resSuccess.errorMessage, isNull);

      const resFail = DriveResourceResult(
        isSuccess: false,
        errorMessage: 'Scope denied',
      );
      expect(resFail.isSuccess, isFalse);
      expect(resFail.errorMessage, equals('Scope denied'));
    });
  });
}
