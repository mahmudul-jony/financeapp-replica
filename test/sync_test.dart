import 'package:flutter_test/flutter_test.dart';
import 'package:financeapp/services/sync_service.dart';

void main() {
  test('Fetch data from sheet', () async {
    final data = await SyncService.fetchFromSheet();
    print("FETCHED DATA FROM SHEET: $data");
  });
}
