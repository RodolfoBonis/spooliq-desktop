import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/observability/app_logger.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_repository.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_status.dart';
import 'package:spooliq_desktop/features/payments/domain/budget_payment.dart';
import 'package:spooliq_desktop/features/payments/domain/payment_repository.dart';

class BudgetDetailState extends Equatable {
  const BudgetDetailState({
    this.budget,
    this.history = const [],
    this.payments = const [],
    this.paymentsEnabled = false,
    this.loading = true,
    this.error,
    this.deleted = false,
  });

  final Budget? budget;
  final List<StatusChange> history;

  /// Pagamentos do orçamento (vazio quando não há integração/cobranças).
  final List<BudgetPayment> payments;

  /// A integração está conectada e ligada (habilita gerar link).
  final bool paymentsEnabled;
  final bool loading;
  final String? error;
  final bool deleted;

  BudgetDetailState copyWith({
    Budget? budget,
    List<StatusChange>? history,
    List<BudgetPayment>? payments,
    bool? paymentsEnabled,
    bool? loading,
    String? Function()? error,
    bool? deleted,
  }) => BudgetDetailState(
    budget: budget ?? this.budget,
    history: history ?? this.history,
    payments: payments ?? this.payments,
    paymentsEnabled: paymentsEnabled ?? this.paymentsEnabled,
    loading: loading ?? this.loading,
    error: error == null ? this.error : error(),
    deleted: deleted ?? this.deleted,
  );

  @override
  List<Object?> get props => [
    budget,
    history,
    payments,
    paymentsEnabled,
    loading,
    error,
    deleted,
  ];
}

class BudgetDetailCubit extends Cubit<BudgetDetailState> {
  BudgetDetailCubit(this._repository, this._payments, this.id)
    : super(const BudgetDetailState());

  final BudgetRepository _repository;
  final PaymentRepository _payments;
  final String id;

  /// A configuração da integração é buscada uma única vez por tela.
  bool _settingsLoaded = false;

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
      if (_hasPaymentContext(budget)) unawaited(_loadPayments());
    } on ApiError catch (e) {
      if (isClosed) return;
      emit(state.copyWith(loading: false, error: () => e.message));
    }
  }

  /// Só busca pagamentos quando o orçamento pode ter cobranças — evita
  /// chamadas em rascunhos/enviados que nunca tiveram pagamento.
  static bool _hasPaymentContext(Budget b) =>
      b.paymentStatus != PaymentStatus.unpaid ||
      const {
        BudgetStatus.approved,
        BudgetStatus.printing,
        BudgetStatus.completed,
        BudgetStatus.cancelled,
      }.contains(b.status);

  Future<void> _loadHistory() async {
    try {
      final page = await _repository.history(id);
      if (isClosed || page.items.isEmpty) return;
      emit(state.copyWith(history: page.items));
    } on ApiError {
      // O histórico embutido no orçamento continua sendo exibido.
    }
  }

  Future<void> _loadPayments() async {
    try {
      final payments = await _payments.budgetPayments(id);
      if (isClosed) return;
      emit(state.copyWith(payments: payments));
    } on ApiError catch (e) {
      AppLogger.warning(
        'Falha ao carregar pagamentos do orçamento',
        category: 'payments',
        error: e,
      );
    }
    // A configuração da integração muda raramente: busca uma vez por tela.
    if (_settingsLoaded) return;
    try {
      final settings = await _payments.getSettings();
      _settingsLoaded = true;
      if (isClosed) return;
      emit(state.copyWith(paymentsEnabled: settings.isActive));
    } on ApiError catch (e) {
      AppLogger.warning(
        'Falha ao carregar a integração de pagamentos',
        category: 'payments',
        error: e,
      );
    }
  }

  /// Atualização vinda de uma ação (status, share…).
  void replace(Budget budget) {
    emit(state.copyWith(budget: budget));
    unawaited(_loadHistory());
    if (_hasPaymentContext(budget)) unawaited(_loadPayments());
  }

  void markDeleted() => emit(state.copyWith(deleted: true));
}
