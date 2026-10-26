import 'package:flutter_test/flutter_test.dart';
import 'package:financeapp/services/update_service.dart';

void main() {
  group('UpdateService.isVersionNewer Tests', () {
    test('Detects update when build number increases on same version', () {
      final isNewer = UpdateService.isVersionNewer(
        latestStr: 'v1.0.1+3',
        currentVersionStr: '1.0.1',
        currentBuildStr: '2',
      );
      expect(isNewer, isTrue);
    });

    test('Detects no update when version and build number are identical', () {
      final isNewer = UpdateService.isVersionNewer(
        latestStr: 'v1.0.1+3',
        currentVersionStr: '1.0.1',
        currentBuildStr: '3',
      );
      expect(isNewer, isFalse);
    });

    test('Detects update when semantic patch version increases', () {
      final isNewer = UpdateService.isVersionNewer(
        latestStr: 'v1.0.2+1',
        currentVersionStr: '1.0.1',
        currentBuildStr: '5',
      );
      expect(isNewer, isTrue);
    });

    test('Detects update when semantic minor version increases', () {
      final isNewer = UpdateService.isVersionNewer(
        latestStr: 'v1.1.0',
        currentVersionStr: '1.0.9',
        currentBuildStr: '99',
      );
      expect(isNewer, isTrue);
    });

    test('Detects update when semantic major version increases', () {
      final isNewer = UpdateService.isVersionNewer(
        latestStr: '2.0.0',
        currentVersionStr: '1.9.9',
        currentBuildStr: '999',
      );
      expect(isNewer, isTrue);
    });

    test('Detects no update when current version is ahead of latest (local dev)', () {
      final isNewer = UpdateService.isVersionNewer(
        latestStr: 'v1.0.1+3',
        currentVersionStr: '1.0.2',
        currentBuildStr: '1',
      );
      expect(isNewer, isFalse);
    });

    test('Handles tags without v prefix', () {
      final isNewer = UpdateService.isVersionNewer(
        latestStr: '1.0.1+4',
        currentVersionStr: '1.0.1',
        currentBuildStr: '3',
      );
      expect(isNewer, isTrue);
    });
  });
}
