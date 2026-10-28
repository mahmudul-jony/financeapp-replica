import 'package:flutter_test/flutter_test.dart';
import 'package:financeapp/services/sync_service.dart';

void main() {
  test('Fetch data from sheet', () async {
    final result = await SyncService.fetchFromSheet();
    expect(result, isNotNull);
  });
}
