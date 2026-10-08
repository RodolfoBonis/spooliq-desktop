import 'package:flutter_test/flutter_test.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';

void main() {
  test('parses the standard envelope', () {
    final page = Paginated.fromJson(const {
      'data': [
        {'v': 1},
        {'v': 2},
      ],
      'total': 45,
      'page': 2,
      'page_size': 20,
      'total_pages': 3,
    }, (j) => j['v'] as int);
    expect(page.items, [1, 2]);
    expect(page.total, 45);
    expect(page.hasMore, isTrue);
  });

  test('accepts a bare list', () {
    final page = Paginated.fromJson(const [
      {'v': 1},
    ], (j) => j['v'] as int);
    expect(page.items, [1]);
    expect(page.totalPages, 1);
    expect(page.hasMore, isFalse);
  });

  test('derives total_pages when missing', () {
    final page = Paginated.fromJson(const {
      'data': <Object>[],
      'total': 41,
      'page_size': 20,
    }, (j) => j);
    expect(page.totalPages, 3);
  });

  test('PageQuery builds API query params', () {
    const q = PageQuery(
      page: 3,
      search: '  bambu ',
      sortBy: 'name',
      sortAscending: true,
    );
    expect(q.toQuery(), {
      'page': 3,
      'page_size': 20,
      'q': 'bambu',
      'sort_by': 'name',
      'sort_dir': 'asc',
    });
    expect(q.copyWith(clearSearch: true).search, isNull);
  });
}
