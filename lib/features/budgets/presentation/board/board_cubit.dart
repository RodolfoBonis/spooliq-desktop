import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/core/observability/app_logger.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_repository.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_status.dart';

/// Estado de uma coluna do quadro.
class BoardColumn extends Equatable {
  const BoardColumn({
    this.items = const [],
    this.total = 0,
    this.page = 0,
    this.totalPages = 0,
    this.loading = false,
    this.loadingMore = false,
    this.error,
  });

  final List<Budget> items;
  final int total;
  final int page;
  final int totalPages;
  final bool loading;
  final bool loadingMore;
  final String? error;

  bool get hasMore => page < totalPages;

  /// Soma dos totais carregados (exibida no cabeçalho da coluna).
  int get loadedValueCents => items.fold(0, (s, b) => s + b.totalCents);

  BoardColumn copyWith({
    List<Budget>? items,
    int? total,
    int? page,
    int? totalPages,
    bool? loading,
    bool? loadingMore,
    String? Function()? error,
  }) => BoardColumn(
    items: items ?? this.items,
    total: total ?? this.total,
    page: page ?? this.page,
    totalPages: totalPages ?? this.totalPages,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    error: error == null ? this.error : error(),
  );

  @override
  List<Object?> get props => [
    items,
    total,
    page,
    totalPages,
    loading,
    loadingMore,
    error,
  ];
}

/// Resultado de uma movimentação (para feedback na UI).
sealed class MoveResult {
  const MoveResult();
}

final class MoveSucceeded extends MoveResult {
  const MoveSucceeded(this.budget, this.from);

  final Budget budget;
  final BudgetStatus from;
}

final class MoveFailed extends MoveResult {
  const MoveFailed(this.error);

  final ApiError error;
}

class BoardState extends Equatable {
  const BoardState({
    this.columns = const {},
    this.filter = const BudgetFilter(),
    this.showArchived = false,
    this.moving = const {},
  });

  final Map<BudgetStatus, BoardColumn> columns;
  final BudgetFilter filter;

  /// Exibe as colunas Rejeitado/Expirado/Cancelado expandidas.
  final bool showArchived;

  /// IDs com mudança de status em andamento.
  final Set<String> moving;

  BoardColumn column(BudgetStatus s) =>
      columns[s] ?? const BoardColumn(loading: true);

  bool get isInitialLoading =>
      columns.isEmpty || columns.values.every((c) => c.loading);

  int get totalCount => columns.values.fold(0, (s, c) => s + c.total);

  BoardState copyWith({
    Map<BudgetStatus, BoardColumn>? columns,
    BudgetFilter? filter,
    bool? showArchived,
    Set<String>? moving,
  }) => BoardState(
    columns: columns ?? this.columns,
    filter: filter ?? this.filter,
    showArchived: showArchived ?? this.showArchived,
    moving: moving ?? this.moving,
  );

  @override
  List<Object?> get props => [columns, filter, showArchived, moving];
}

/// Quadro kanban de orçamentos. Cada coluna é uma consulta `status=X`
/// paginada; mover um card chama `PATCH /budgets/{id}/status`.
class BoardCubit extends Cubit<BoardState> {
  BoardCubit(this._repository, {this.pageSize = 20})
    : super(const BoardState());

  final BudgetRepository _repository;
  final int pageSize;
  int _generation = 0;

  static const List<BudgetStatus> _all = BudgetStatus.values;

  Future<void> load({BudgetFilter? filter}) async {
    final f = filter ?? state.filter;
    final generation = ++_generation;
    emit(
      state.copyWith(
        filter: f,
        columns: {
          for (final s in _all)
            s: state.column(s).copyWith(loading: true, error: () => null),
        },
      ),
    );
    await Future.wait(_all.map((s) => _loadColumn(s, f, generation)));
  }

  Future<void> refresh() => load();

  void setFilter(BudgetFilter filter) {
    if (filter == state.filter) return;
    unawaited(load(filter: filter));
  }

  void toggleArchived() =>
      emit(state.copyWith(showArchived: !state.showArchived));

  Future<void> _loadColumn(
    BudgetStatus status,
    BudgetFilter f,
    int generation,
  ) async {
    try {
      final page = await _repository.list(
        filter: f.copyWith(status: () => status),
        page: PageQuery(pageSize: pageSize),
      );
      if (isClosed || generation != _generation) return;
      _putColumn(status, (_) => _fromPage(page));
    } on ApiError catch (e) {
      if (isClosed || generation != _generation) return;
      _putColumn(
        status,
        (c) => c.copyWith(loading: false, error: () => e.message),
      );
    }
  }

  Future<void> loadMore(BudgetStatus status) async {
    final col = state.column(status);
    if (!col.hasMore || col.loadingMore || col.loading) return;
    final generation = _generation;
    _putColumn(status, (c) => c.copyWith(loadingMore: true));
    try {
      final page = await _repository.list(
        filter: state.filter.copyWith(status: () => status),
        page: PageQuery(page: col.page + 1, pageSize: pageSize),
      );
      if (isClosed || generation != _generation) return;
      _putColumn(status, (c) {
        final known = c.items.map((b) => b.id).toSet();
        return c.copyWith(
          items: [
            ...c.items,
            ...page.items.where((b) => !known.contains(b.id)),
          ],
          page: page.page,
          totalPages: page.totalPages,
          total: page.total,
          loadingMore: false,
        );
      });
    } on ApiError catch (e) {
      if (isClosed) return;
      _putColumn(
        status,
        (c) => c.copyWith(loadingMore: false, error: () => e.message),
      );
    }
  }

  /// Move [budget] para [to] com atualização otimista.
  ///
  /// Em 400/409 o card volta à coluna de origem e o quadro é recarregado
  /// (o status pode ter sido alterado por outra pessoa ou pelo job de
  /// expiração).
  Future<MoveResult> move(
    Budget budget,
    BudgetStatus to, {
    String? notes,
  }) async {
    final from = budget.status;
    if (from == to) return MoveSucceeded(budget, from);
    if (!from.canTransitionTo(to)) {
      return const MoveFailed(
        BusinessError(
          'Essa mudança de status não é permitida.',
          code: 'invalid_status_transition',
        ),
      );
    }

    final optimistic = budget.copyWithStatus(to);
    _applyMove(budget.id, from: from, to: to, replacement: optimistic);
    emit(state.copyWith(moving: {...state.moving, budget.id}));

    try {
      final updated = await _repository.changeStatus(
        budget.id,
        to,
        notes: notes,
      );
      if (isClosed) return MoveSucceeded(updated, from);
      _replace(updated);
      emit(state.copyWith(moving: {...state.moving}..remove(budget.id)));
      AppLogger.info(
        'Orçamento movido',
        category: 'budgets',
        data: {'from': from.value, 'to': to.value},
      );
      return MoveSucceeded(updated, from);
    } on ApiError catch (e) {
      if (isClosed) return MoveFailed(e);
      _applyMove(budget.id, from: to, to: from, replacement: budget);
      emit(state.copyWith(moving: {...state.moving}..remove(budget.id)));
      if (e is ConflictError || e is BusinessError) unawaited(refresh());
      return MoveFailed(e);
    }
  }

  /// Insere/atualiza um orçamento vindo de outra tela (editor, detalhe).
  void upsert(Budget budget) {
    final existing = _find(budget.id);
    if (existing != null && existing.status != budget.status) {
      _applyMove(
        budget.id,
        from: existing.status,
        to: budget.status,
        replacement: budget,
      );
    } else if (existing != null) {
      _replace(budget);
    } else {
      _putColumn(
        budget.status,
        (c) => c.copyWith(items: [budget, ...c.items], total: c.total + 1),
      );
    }
  }

  void remove(String id) {
    final existing = _find(id);
    if (existing == null) return;
    _putColumn(
      existing.status,
      (c) => c.copyWith(
        items: c.items.where((b) => b.id != id).toList(),
        total: c.total - 1,
      ),
    );
  }

  Budget? _find(String id) {
    for (final c in state.columns.values) {
      for (final b in c.items) {
        if (b.id == id) return b;
      }
    }
    return null;
  }

  void _applyMove(
    String id, {
    required BudgetStatus from,
    required BudgetStatus to,
    required Budget replacement,
  }) {
    final columns = Map<BudgetStatus, BoardColumn>.of(state.columns);
    final source = columns[from] ?? const BoardColumn();
    final target = columns[to] ?? const BoardColumn();
    columns[from] = source.copyWith(
      items: source.items.where((b) => b.id != id).toList(),
      total: (source.total - 1).clamp(0, 1 << 31),
    );
    columns[to] = target.copyWith(
      items: [replacement, ...target.items.where((b) => b.id != id)],
      total: target.total + 1,
    );
    emit(state.copyWith(columns: columns));
  }

  void _replace(Budget budget) {
    _putColumn(
      budget.status,
      (c) => c.copyWith(
        items: [
          for (final b in c.items)
            if (b.id == budget.id) budget else b,
        ],
      ),
    );
  }

  void _putColumn(
    BudgetStatus status,
    BoardColumn Function(BoardColumn) update,
  ) {
    emit(
      state.copyWith(
        columns: {...state.columns, status: update(state.column(status))},
      ),
    );
  }

  BoardColumn _fromPage(Paginated<Budget> page) => BoardColumn(
    items: page.items,
    total: page.total,
    page: page.page,
    totalPages: page.totalPages,
  );
}
