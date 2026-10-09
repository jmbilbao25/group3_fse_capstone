import 'package:flutter_test/flutter_test.dart';
import 'package:aurabank_core/navigation/root_navigator.dart';

void main() {
  test('root navigator key is available', () {
    expect(rootNavigatorKey, isNotNull);
  });
}
