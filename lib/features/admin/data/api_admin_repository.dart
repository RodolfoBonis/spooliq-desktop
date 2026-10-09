import 'package:spooliq_desktop/core/network/api_client.dart';
import 'package:spooliq_desktop/core/network/json.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/features/admin/domain/admin.dart';
import 'package:spooliq_desktop/features/company/domain/company.dart';
import 'package:spooliq_desktop/features/subscription/domain/billing.dart';

class ApiAdminRepository implements AdminRepository {
  const ApiAdminRepository(this._api);

  final ApiClient _api;

  @override
  Future<AdminStats> stats() async =>
      AdminStats.fromJson((await _api.getJson('/admin/stats')).unwrapData());

  @override
  Future<Paginated<AdminCompany>> companies({
    PageQuery page = const PageQuery(),
    String? status,
  }) async => Paginated.fromJson(
    await _api.get(
      '/admin/companies',
      query: {...page.toQuery(), 'status': status},
    ),
    AdminCompany.fromJson,
  );

  @override
  Future<AdminCompany> company(String id) async =>
      AdminCompany.fromJson(await _api.getJson('/admin/companies/$id'));

  @override
  Future<void> setCompanyStatus(
    String id,
    SubscriptionStatus status, {
    String? reason,
  }) => _api.patch(
    '/admin/companies/$id/status',
    body: compactJson({'status': status.value, 'reason': reason}),
  );

  @override
  Future<Paginated<AdminCompany>> subscriptions({
    PageQuery page = const PageQuery(),
    String? status,
  }) async => Paginated.fromJson(
    await _api.get(
      '/admin/subscriptions',
      query: {...page.toQuery(), 'status': status},
    ),
    AdminCompany.fromJson,
  );

  @override
  Future<List<Payment>> companyPayments(String id) async => looseList(
    await _api.get('/admin/subscriptions/$id/payments'),
    Payment.fromJson,
    'payments',
  );

  @override
  Future<List<Plan>> plans() async => looseList(
    await _api.get('/admin/subscription-plans'),
    Plan.fromJson,
    'plans',
  );

  @override
  Future<Plan> savePlan(Plan plan, {bool create = false}) async {
    final body = {
      'name': plan.name.trim(),
      'description': plan.description ?? '',
      'price': plan.price,
      'cycle': plan.cycle,
      'features': [for (final f in plan.features) f.toJson()],
      if (!create) 'is_active': plan.isActive,
    };
    final json = create
        ? await _api.postJson('/admin/subscription-plans', body: body)
        : await _api.putJson(
            '/admin/subscription-plans/${plan.id}',
            body: body,
          );
    return Plan.fromJson(json);
  }

  @override
  Future<void> deletePlan(String id) =>
      _api.delete('/admin/subscription-plans/$id');

  @override
  Future<(bool, String?)> canDeletePlan(String id) async {
    final j = (await _api.getJson(
      '/admin/subscription-plans/$id/can-delete',
    )).unwrapData();
    return (j.boolean('can_delete'), j.strOrNull('reason'));
  }

  @override
  Future<void> setPlansActive(
    List<String> ids, {
    required bool active,
  }) => _api.put(
    '/admin/subscription-plans/${active ? 'bulk-activate' : 'bulk-deactivate'}',
    body: {
      'plan_ids': ids,
      'reason': active ? 'Ativado pelo admin' : 'Desativado pelo admin',
    },
  );

  @override
  Future<PlanStats> planStats(String id) async => PlanStats.fromJson(
    (await _api.getJson('/admin/subscription-plans/$id/stats')).unwrapData(),
  );

  @override
  Future<List<AdminCompany>> planCompanies(String id) async => looseList(
    await _api.get('/admin/subscription-plans/$id/companies'),
    AdminCompany.fromJson,
    'companies',
  );

  @override
  Future<List<PlanTemplate>> planTemplates() async => looseList(
    await _api.get('/admin/subscription-plans/templates'),
    PlanTemplate.fromJson,
    'templates',
  );

  @override
  Future<void> planFromTemplate(String templateId) => _api.post(
    '/admin/subscription-plans/from-template',
    body: {'template_id': templateId, 'reason': 'Criado a partir de template'},
  );

  @override
  Future<PlanFinancialReport> planFinancialReport(
    String id, {
    ReportPeriod period = ReportPeriod.monthly,
  }) async => PlanFinancialReport.fromJson(
    await _api.getJson(
      '/admin/subscription-plans/$id/financial-report',
      query: {'period': period.value},
    ),
  );

  @override
  Future<PlanMigration> createMigration({
    required String fromPlanId,
    required String toPlanId,
    required String reason,
    bool notifyUsers = true,
    DateTime? scheduledFor,
  }) async => PlanMigration.fromJson(
    await _api.postJson(
      '/admin/subscription-plans/migrate',
      body: compactJson({
        'from_plan_id': fromPlanId,
        'to_plan_id': toPlanId,
        'reason': reason.trim(),
        'notify_users': notifyUsers,
        'scheduled_for': scheduledFor?.toUtc().toIso8601String(),
      }),
    ),
  );

  @override
  Future<PlanMigration> executeMigration(String migrationId) async =>
      PlanMigration.fromJson(
        await _api.postJson(
          '/admin/subscription-plans/migrations/$migrationId/execute',
        ),
      );

  @override
  Future<PlanMigration> migration(String migrationId) async =>
      PlanMigration.fromJson(
        await _api.getJson(
          '/admin/subscription-plans/migrations/$migrationId',
        ),
      );

  @override
  Future<List<AvailableFeature>> availableFeatures() async => looseList(
    await _api.get('/admin/features/available', query: {'page_size': 100}),
    AvailableFeature.fromJson,
    'features',
  );

  @override
  Future<FeatureValidation> validateFeatures(
    List<PlanFeature> features,
  ) async => FeatureValidation.fromJson(
    await _api.postJson(
      '/admin/features/validate',
      body: {
        'features': [for (final f in features) f.toJson()],
      },
    ),
  );

  @override
  Future<Paginated<PlanAuditEntry>> planHistory(
    String id, {
    int page = 1,
  }) async => Paginated.fromJson(
    await _api.get(
      '/admin/subscription-plans/$id/history',
      query: {'page': page, 'page_size': 20},
    ),
    PlanAuditEntry.fromJson,
  );

  @override
  Future<SubscriptionDetail> subscriptionDetail(String organizationId) async =>
      SubscriptionDetail.fromJson(
        await _api.getJson('/admin/subscriptions/$organizationId'),
      );
}
