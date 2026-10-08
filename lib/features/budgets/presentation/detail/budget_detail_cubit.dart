import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_repository.dart';

class BudgetDetailState extends Equatable {
  const BudgetDetailState({
    this.budget,
    this.history = const [],
    this.loading = true,
    this.error,
    this.deleted = false,
  });

  final Budget? budget;
  final List<StatusChange> history;
  final bool loading;
  final String? error;
  final bool deleted;

  BudgetDetailState copyWith({
    Budget? budget,
    List<StatusChange>? history,
    bool? loading,
    String? Function()? error,
    bool? deleted,
  }) => BudgetDetailState(
    budget: budget ?? this.budget,
    history: history ?? this.history,
    loading: loading ?? this.loading,
    error: error == null ? this.error : error(),
    deleted: deleted ?? this.deleted,
  );

  @override
  List<Object?> get props => [budget, history, loading, error, deleted];
}

class BudgetDetailCubit extends Cubit<BudgetDetailState> {
  BudgetDetailCubit(this._repository, this.id)
    : super(const BudgetDetailState());

  final BudgetRepository _repository;
  final String id;

  Future<void> load() async {
    emit(state.copyWith(loading: true, error: () => null));
    try {
      final budget = await _repository.get(id);
      if (isClosed) return;
      emit(
        state.copyWith(
          budget: budget,
          history: budget.statusHistory,
          loading: false,
        ),
      );
      unawaited(_loadHistory());
    } on ApiError catch (e) {
      if (isClosed) return;
      emit(state.copyWith(loading: false, error: () => e.message));
    }
  }

  Future<void> _loadHistory() async {
    try {
      final page = await _repository.history(id);
      if (isClosed || page.items.isEmpty) return;
      emit(state.copyWith(history: page.items));
    } on ApiError {
      // O histórico embutido no orçamento continua sendo exibido.
    }
  }

  /// Atualização vinda de uma ação (status, share…).
  void replace(Budget budget) {
    emit(state.copyWith(budget: budget));
    unawaited(_loadHistory());
  }

  void markDeleted() => emit(state.copyWith(deleted: true));
}
