import 'package:flutter_test/flutter_test.dart';
import 'package:hozyain_barin/category_counter_service.dart';

void main() {
  test('getCount returns 0 when category is missing', () {
    expect(CategoryCounterService.getCount('unknown'), '0');
  });

  test('getCount is stable for different id types', () {
    expect(CategoryCounterService.getCount(123), '0');
    expect(CategoryCounterService.getCount('123'), '0');
  });
}
