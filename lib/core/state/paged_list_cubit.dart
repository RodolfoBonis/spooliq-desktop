import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';

typedef PageFetcher<T> = Future<Paginated<T>> Function(PageQuery query);

class PagedListState<T> extends Equatable {
  const PagedListState({
    this.page = const Paginated.empty(),
    this.query = const PageQuery(),
    this.loading = true,
    this.error,
  });

  final Paginated<T> page;
  final PageQuery query;
  final bool loading;
  final String? error;

  List<T> get items => page.items;

  bool get isEmpty => !loading && error == null && items.isEmpty;

  bool get isSearching => query.search != null && query.search!.isNotEmpty;

  PagedListState<T> copyWith({
    Paginated<T>? page,
    PageQuery? query,
    bool? loading,
    String? Function()? error,
  }) => PagedListState<T>(
    page: page ?? this.page,
    query: query ?? this.query,
    loading: loading ?? this.loading,
    error: error == null ? this.error : error(),
  );

  @override
  List<Object?> get props => [page, query, loading, error];
}

/// Lista paginada genérica: busca, ordenação, paginação e atualizações locais.
///
/// Usada por todas as telas de listagem simples (marcas, materiais,
/// clientes, usuários…). Respostas fora de ordem são descartadas.
class PagedListCubit<T> extends Cubit<PagedListState<T>> {
  PagedListCubit(
    this._fetch, {
    required Object Function(T item) idOf,
    PageQuery initialQuery = const PageQuery(),
  }) : _idOf = idOf,
       super(PagedListState<T>(query: initialQuery));

  final PageFetcher<T> _fetch;
  final Object Function(T item) _idOf;
  int _request = 0;

  Future<void> load([PageQuery? query]) async {
    final q = query ?? state.query;
    final request = ++_request;
    emit(state.copyWith(query: q, loading: true, error: () => null));
    try {
      final page = await _fetch(q);
      if (isClosed || request != _request) return;
      emit(state.copyWith(page: page, loading: false));
    } on ApiError catch (e) {
      if (isClosed || request != _request) return;
      emit(state.copyWith(loading: false, error: () => e.message));
    }
  }

  Future<void> refresh() => load();

  void search(String text) => unawaited(
    load(
      state.query.copyWith(
        page: 1,
        search: text,
        clearSearch: text.trim().isEmpty,
      ),
    ),
  );

  void goToPage(int page) => unawaited(load(state.query.copyWith(page: page)));

  // Assinatura imposta por FormaDataTable.onSort.
  // ignore: avoid_positional_boolean_parameters
  void sort(String column, bool ascending) => unawaited(
    load(
      state.query.copyWith(sortBy: column, sortAscending: ascending, page: 1),
    ),
  );

  /// Insere ou substitui um item sem recarregar.
  void upsert(T item) {
    final id = _idOf(item);
    final items = [...state.items];
    final index = items.indexWhere((e) => _idOf(e) == id);
    final created = index < 0;
    if (created) {
      items.insert(0, item);
    } else {
      items[index] = item;
    }
    final p = state.page;
    emit(
      state.copyWith(
        page: Paginated(
          items: items,
          total: p.total + (created ? 1 : 0),
          page: p.page,
          pageSize: p.pageSize,
          totalPages: p.totalPages == 0 ? 1 : p.totalPages,
        ),
      ),
    );
  }

  void remove(Object id) {
    final p = state.page;
    final items = state.items.where((e) => _idOf(e) != id).toList();
    if (items.length == p.items.length) return;
    emit(
      state.copyWith(
        page: Paginated(
          items: items,
          total: p.total - 1,
          page: p.page,
          pageSize: p.pageSize,
          totalPages: p.totalPages,
        ),
      ),
    );
  }
}
