import 'package:flutter_test/flutter_test.dart';
import 'package:spooliq_desktop/core/network/json.dart';

void main() {
  group('JsonRead', () {
    final json = <String, dynamic>{
      'i': 3,
      'd': 2.6,
      'si': '7',
      'b': true,
      'bs': 'true',
      'null': null,
      'empty': '',
      'date': '2026-01-02T03:04:05Z',
      'zero_date': '0001-01-01T00:00:00Z',
      'obj': {'a': 1},
      'list': [
        {'a': 1},
        'x',
        {'a': 2},
      ],
      'data': {'id': 'wrapped'},
    };

    test('numbers are coerced leniently', () {
      expect(json.integer('i'), 3);
      expect(json.integer('d'), 3);
      expect(json.integer('si'), 7);
      expect(json.integer('missing', 9), 9);
      expect(json.dbl('i'), 3.0);
      expect(json.dblOrNull('null'), isNull);
    });

    test('strings treat empty as null in strOrNull', () {
      expect(json.str('null'), '');
      expect(json.strOrNull('empty'), isNull);
      expect(json.str('i'), '3');
    });

    test('booleans accept bool and string', () {
      expect(json.boolean('b'), isTrue);
      expect(json.boolean('bs'), isTrue);
      expect(json.boolean('missing', fallback: true), isTrue);
    });

    test('dates ignore Go zero values', () {
      expect(json.date('date'), DateTime.utc(2026, 1, 2, 3, 4, 5).toLocal());
      expect(json.date('zero_date'), isNull);
      expect(json.date('empty'), isNull);
    });

    test('list skips non-map entries', () {
      expect(json.list('list', (j) => j.integer('a')), [1, 2]);
      expect(json.list('missing', (j) => j), isEmpty);
    });

    test('unwrapData returns inner object', () {
      expect(json.unwrapData().str('id'), 'wrapped');
      expect(<String, dynamic>{'id': 'x'}.unwrapData().str('id'), 'x');
    });

    test('compactJson drops nulls', () {
      expect(compactJson({'a': 1, 'b': null}), {'a': 1});
    });
  });
}
