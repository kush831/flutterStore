import 'package:flutter_test/flutter_test.dart';

import 'package:apporio_store_30sept/core/strings/app_strings.dart';

void main() {
  const loaded = AppStrings(
    code: 'en',
    strings: {'greeting': 'Hello %s', 'empty': '', 'swap': '%2\$s then %1\$s'},
  );

  test('returns the server text with placeholders', () {
    expect(loaded.get('greeting', ['Vishal']), 'Hello Vishal');
    expect(loaded.get('swap', ['1', '2']), '2 then 1');
  });

  test('a missing key shows the key, never blank', () {
    expect(loaded.get('does_not_exist'), 'does_not_exist');
    expect(loaded.get('empty'), 'empty'); // an empty server value counts as missing
  });

  test('before the first download nothing flickers', () {
    const notLoaded = AppStrings(code: 'en');
    expect(notLoaded.get('anything'), '');
  });

  test('a missing argument keeps the placeholder instead of crashing', () {
    expect(loaded.get('greeting'), 'Hello %s');
  });
}