import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_draft.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_status.dart';

/// Filtros de listagem de orçamentos.
class BudgetFilter extends Equatable {
  const BudgetFilter({
    this.search,
    this.status,
    this.customerId,
    this.customerName,
    this.from,
    this.to,
  });

  final String? search;
  final BudgetStatus? status;
  final String? customerId;

  /// Apenas para exibição do filtro (não é enviado à API).
  final String? customerName;
  final DateTime? from;
  final DateTime? to;

  bool get isEmpty =>
      (search == null || search!.isEmpty) &&
      customerId == null &&
      from == null &&
      to == null;

  BudgetFilter copyWith({
    String? Function()? search,
    BudgetStatus? Function()? status,
    String? Function()? customerId,
    String? Function()? customerName,
    DateTime? Function()? from,
    DateTime? Function()? to,
  }) => BudgetFilter(
    search: search == null ? this.search : search(),
    status: status == null ? this.status : status(),
    customerId: customerId == null ? this.customerId : customerId(),
    customerName: customerName == null ? this.customerName : customerName(),
    from: from == null ? this.from : from(),
    to: to == null ? this.to : to(),
  );

  @override
  List<Object?> get props => [search, status, customerId, from, to];
}

/// PDF gerado: URL na CDN ou bytes (quando o upload na CDN falha).
sealed class BudgetPdf {
  const BudgetPdf();
}

final class BudgetPdfUrl extends BudgetPdf {
  const BudgetPdfUrl(this.url);

  final String url;
}

final class BudgetPdfBytes extends BudgetPdf {
  const BudgetPdfBytes(this.bytes);

  final Uint8List bytes;
}

/// Resultado do compartilhamento público.
class BudgetShare extends Equatable {
  const BudgetShare({
    required this.token,
    required this.status,
    this.validUntil,
  });

  final String token;
  final BudgetStatus status;
  final DateTime? validUntil;

  @override
  List<Object?> get props => [token, status, validUntil];
}

abstract interface class BudgetRepository {
  Future<Paginated<Budget>> list({
    BudgetFilter filter = const BudgetFilter(),
    PageQuery page = const PageQuery(),
  });

  Future<Budget> get(String id);

  Future<Budget> create(BudgetDraft draft);

  Future<Budget> update(String id, BudgetDraft draft);

  Future<Budget> preview(BudgetDraft draft);

  Future<Budget> changeStatus(String id, BudgetStatus status, {String? notes});

  Future<Budget> duplicate(String id);

  /// Recalcula os custos com os preços/presets atuais (só rascunhos).
  Future<Budget> recalculate(String id);

  Future<void> delete(String id);

  Future<BudgetShare> share(String id);

  Future<void> revokeShare(String id);

  Future<BudgetPdf> pdf(String id, {bool force = false});

  Future<Paginated<StatusChange>> history(String id, {int page = 1});
}
