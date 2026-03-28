import 'package:flutter_test/flutter_test.dart';
import 'package:hozyain_barin/services/manticore_search_service.dart';

void main() {
  test('uses HTTPS bridge endpoints by default', () {
    final service = ManticoreSearchService();

    expect(
      service.endpoint,
      'https://hozyain-barin.ru/native/bridge/manticore_sql.php',
    );
    expect(
      service.suggestEndpoint,
      'https://hozyain-barin.ru/native/bridge/manticore_cli_json.php',
    );
  });

  test('derives bridge suggest endpoint from custom sql endpoint', () {
    final service = ManticoreSearchService(
      endpoint: 'https://example.com/native/bridge/manticore_sql.php',
    );

    expect(
      service.suggestEndpoint,
      'https://example.com/native/bridge/manticore_cli_json.php',
    );
  });
}
