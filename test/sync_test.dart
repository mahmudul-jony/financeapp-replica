import 'package:flutter_test/flutter_test.dart';
import 'package:financeapp/services/sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Fetch data from sheet when unauthenticated returns safe result', () async {
    final result = await SyncService.fetchFromSheet();
    expect(result, isNotNull);
    expect(result.data, isEmpty);
  });
}
