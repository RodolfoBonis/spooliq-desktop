import 'package:spooliq_desktop/core/format/formatters.dart';
import 'package:spooliq_desktop/core/network/api_client.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/network/json.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_draft.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_repository.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_status.dart';

class ApiBudgetRepository implements BudgetRepository {
  const ApiBudgetRepository(this._api);

  final ApiClient _api;

  @override
  Future<Paginated<Budget>> list({
    BudgetFilter filter = const BudgetFilter(),
    PageQuery page = const PageQuery(),
  }) async {
    final body = await _api.get(
      '/budgets',
      query: {
        ...page.toQuery(),
        if (filter.search != null) 'q': filter.search,
        'status': filter.status?.value,
        'customer_id': filter.customerId,
        if (filter.from != null) 'from': Fmt.apiDate(filter.from!),
        if (filter.to != null) 'to': Fmt.apiDate(filter.to!),
      },
    );
    return Paginated.fromJson(body, Budget.fromJson);
  }

  @override
  Future<Budget> get(String id) async =>
      Budget.fromJson((await _api.getJson('/budgets/$id')).unwrapData());

  @override
  Future<Budget> create(BudgetDraft draft) async => Budget.fromJson(
    await _api.postJson('/budgets', body: draft.toCreateJson()),
  );

  @override
  Future<Budget> update(String id, BudgetDraft draft) async => Budget.fromJson(
    await _api.putJson('/budgets/$id', body: draft.toUpdateJson()),
  );

  @override
  Future<Budget> preview(BudgetDraft draft) async => Budget.fromJson(
    await _api.postJson('/budgets/preview', body: draft.toPreviewJson()),
  );

  @override
  Future<Budget> changeStatus(
    String id,
    BudgetStatus status, {
    String? notes,
  }) async => Budget.fromJson(
    await _api.patchJson(
      '/budgets/$id/status',
      body: compactJson({
        'status': status.value,
        'notes': (notes == null || notes.trim().isEmpty) ? null : notes.trim(),
      }),
    ),
  );

  @override
  Future<Budget> duplicate(String id) async =>
      Budget.fromJson(await _api.postJson('/budgets/$id/duplicate'));

  @override
  Future<Budget> recalculate(String id) async =>
      Budget.fromJson(await _api.postJson('/budgets/$id/recalculate'));

  @override
  Future<void> delete(String id) => _api.delete('/budgets/$id');

  @override
  Future<BudgetShare> share(String id) async {
    final json = await _api.postJson('/budgets/$id/share');
    return BudgetShare(
      token: json.str('public_token'),
      status: BudgetStatus.fromValue(json.strOrNull('status')),
      validUntil: json.date('valid_until'),
    );
  }

  @override
  Future<void> revokeShare(String id) => _api.delete('/budgets/$id/share');

  @override
  Future<BudgetPdf> pdf(String id, {bool force = false}) async {
    final res = await _api.getJsonOrBytes(
      '/budgets/$id/pdf',
      query: {if (force) 'force': 'true'},
    );
    return switch (res) {
      final BinaryResponse bin => BudgetPdfBytes(bin.bytes),
      final Json json when json.strOrNull('pdf_url') != null => BudgetPdfUrl(
        json.str('pdf_url'),
      ),
      _ => throw const ServerError('Não foi possível gerar o PDF.'),
    };
  }

  @override
  Future<Paginated<StatusChange>> history(String id, {int page = 1}) async {
    final body = await _api.get(
      '/budgets/$id/history',
      query: {'page': page, 'page_size': 50},
    );
    return Paginated.fromJson(body, StatusChange.fromJson);
  }
}
