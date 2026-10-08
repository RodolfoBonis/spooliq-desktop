import 'package:equatable/equatable.dart';
import 'package:spooliq_desktop/core/network/json.dart';

/// Página de resultados: `{data, total, page, page_size, total_pages}`.
class Paginated<T> extends Equatable {
  const Paginated({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  const Paginated.empty({this.pageSize = 20})
    : items = const [],
      total = 0,
      page = 1,
      totalPages = 0;

  factory Paginated.fromJson(Object? body, T Function(Json json) parse) {
    if (body is List) {
      final items = [
        for (final e in body)
          if (e is Map) parse(Map<String, dynamic>.from(e)),
      ];
      return Paginated(
        items: items,
        total: items.length,
        page: 1,
        pageSize: items.length,
        totalPages: 1,
      );
    }
    final json = body is Map
        ? Map<String, dynamic>.from(body)
        : <String, dynamic>{};
    final items = json.list('data', parse);
    final pageSize = json.integer('page_size', items.length);
    final total = json.integer('total', items.length);
    return Paginated(
      items: items,
      total: total,
      page: json.integer('page', 1),
      pageSize: pageSize,
      totalPages: json.integer(
        'total_pages',
        pageSize == 0 ? 1 : (total / pageSize).ceil(),
      ),
    );
  }

  final List<T> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  bool get hasMore => page < totalPages;

  Paginated<T> append(Paginated<T> next) => Paginated(
    items: [...items, ...next.items],
    total: next.total,
    page: next.page,
    pageSize: next.pageSize,
    totalPages: next.totalPages,
  );

  @override
  List<Object?> get props => [items, total, page, pageSize, totalPages];
}

/// Parâmetros padrão de listagem.
class PageQuery extends Equatable {
  const PageQuery({
    this.page = 1,
    this.pageSize = 20,
    this.search,
    this.sortBy,
    this.sortAscending = false,
  });

  final int page;
  final int pageSize;
  final String? search;
  final String? sortBy;
  final bool sortAscending;

  PageQuery copyWith({
    int? page,
    int? pageSize,
    String? search,
    String? sortBy,
    bool? sortAscending,
    bool clearSearch = false,
  }) => PageQuery(
    page: page ?? this.page,
    pageSize: pageSize ?? this.pageSize,
    search: clearSearch ? null : (search ?? this.search),
    sortBy: sortBy ?? this.sortBy,
    sortAscending: sortAscending ?? this.sortAscending,
  );

  Map<String, dynamic> toQuery() => {
    'page': page,
    'page_size': pageSize,
    if (search != null && search!.trim().isNotEmpty) 'q': search!.trim(),
    if (sortBy != null) 'sort_by': sortBy,
    if (sortBy != null) 'sort_dir': sortAscending ? 'asc' : 'desc',
  };

  @override
  List<Object?> get props => [page, pageSize, search, sortBy, sortAscending];
}
