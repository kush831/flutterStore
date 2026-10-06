import 'package:flutter_test/flutter_test.dart';

import 'package:apporio_store_30sept/core/network/json_reader.dart';
import 'package:apporio_store_30sept/core/network/paging.dart';

void main() {
  test('reads loosely typed values', () {
    final r = JsonReader({'id': '12', 'price': 150.0, 'name': 'null', 'open': '1', 'stock': 12.5, 'storeName': 'A'});
    expect(r.integer('id'), 12);
    expect(r.str('price'), '150'); // never "150.0"
    expect(r.str('name'), isNull);
    expect(r.flag('open'), isTrue);
    expect(r.integer('stock'), 12);
    expect(r.str('store_name'), 'A'); // snake_case finds a camelCase key
  });

  test('missing lists and objects are empty, never null', () {
    final r = JsonReader({'data': 'oops'});
    expect(r.list('items', (e) => e.str('a')), isEmpty);
    expect(r.sub('data').isEmpty, isTrue);
  });

  test('a next page needs a url AND items', () {
    expect(nextPageOf(1, 'http://x?page=2', gotItems: true), 2);
    expect(nextPageOf(1, '', gotItems: true), isNull);
    expect(nextPageOf(1, 'null', gotItems: true), isNull);
    expect(nextPageOf(1, 'http://x?page=2', gotItems: false), isNull);
  });
}