import 'package:equatable/equatable.dart';
import 'package:spooliq_desktop/core/network/json.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/features/company/domain/company.dart';
import 'package:spooliq_desktop/features/subscription/domain/billing.dart';

class AdminStats extends Equatable {
  const AdminStats({
    required this.companies,
    required this.active,
    required this.trial,
    required this.overdue,
    required this.mrrCents,
    required this.churnRate,
  });

  factory AdminStats.fromJson(Json j) => AdminStats(
    companies: j.integer('total_companies'),
    active: j.integer('active_subscriptions'),
    trial: j.integer('trial_subscriptions'),
    overdue: j.integer('overdue_subscriptions'),
    mrrCents: j.integer('total_mrr'),
    churnRate: j.dbl('churn_rate'),
  );

  final int companies;
  final int active;
  final int trial;
  final int overdue;
  final int mrrCents;
  final double churnRate;

  @override
  List<Object?> get props => [
    companies,
    active,
    trial,
    overdue,
    mrrCents,
    churnRate,
  ];
}

class AdminCompany extends Equatable {
  const AdminCompany({
    required this.organizationId,
    required this.name,
    required this.status,
    this.email,
    this.phone,
    this.plan,
    this.trialEndsAt,
    this.startedAt,
    this.createdAt,
    this.logoUrl,
    this.isPlatform = false,
  });

  factory AdminCompany.fromJson(Json json) {
    final j = json.unwrapData();
    return AdminCompany(
      organizationId: j.str('organization_id'),
      name: j.str('name', j.str('company_name')),
      email: j.strOrNull('email'),
      phone: j.strOrNull('phone'),
      status: SubscriptionStatus.fromValue(j.strOrNull('subscription_status')),
      plan: planNameOf(j),
      trialEndsAt: j.date('trial_ends_at'),
      startedAt: j.date('subscription_started_at'),
      createdAt: j.date('created_at'),
      logoUrl: j.strOrNull('logo_url'),
      isPlatform: j.boolean('is_platform_company'),
    );
  }

  final String organizationId;
  final String name;
  final String? email;
  final String? phone;
  final SubscriptionStatus status;
  final String? plan;
  final DateTime? trialEndsAt;
  final DateTime? startedAt;
  final DateTime? createdAt;
  final String? logoUrl;
  final bool isPlatform;

  @override
  List<Object?> get props => [organizationId, name, status, plan];
}

class PlanStats extends Equatable {
  const PlanStats({
    required this.companies,
    required this.active,
    required this.trial,
    required this.users,
    required this.monthlyRevenue,
    required this.annualRevenue,
    required this.churnRate,
    required this.conversionRate,
  });

  factory PlanStats.fromJson(Json j) => PlanStats(
    companies: j.integer('total_companies'),
    active: j.integer('active_companies'),
    trial: j.integer('trial_companies'),
    users: j.integer('total_active_users'),
    monthlyRevenue: j.dbl('monthly_revenue'),
    annualRevenue: j.dbl('annual_revenue'),
    churnRate: j.dbl('churn_rate'),
    conversionRate: j.dbl('conversion_rate'),
  );

  final int companies;
  final int active;
  final int trial;
  final int users;
  final double monthlyRevenue;
  final double annualRevenue;
  final double churnRate;
  final double conversionRate;

  @override
  List<Object?> get props => [companies, monthlyRevenue];
}

class PlanTemplate extends Equatable {
  const PlanTemplate({
    required this.id,
    required this.name,
    this.description,
    this.category,
  });

  factory PlanTemplate.fromJson(Json j) => PlanTemplate(
    id: j.str('id'),
    name: j.str('name'),
    description: j.strOrNull('description'),
    category: j.strOrNull('category'),
  );

  final String id;
  final String name;
  final String? description;
  final String? category;

  @override
  List<Object?> get props => [id];
}

enum ReportPeriod {
  monthly('monthly', 'Mensal'),
  quarterly('quarterly', 'Trimestral'),
  yearly('yearly', 'Anual');

  const ReportPeriod(this.value, this.label);

  final String value;
  final String label;
}

/// Relatório financeiro de um plano (valores em reais).
class PlanFinancialReport extends Equatable {
  const PlanFinancialReport({
    required this.current,
    required this.previous,
    required this.growth,
    required this.averagePerUser,
    required this.lifetime,
    required this.newSubscriptions,
    required this.cancelled,
    required this.churnRate,
    required this.retentionRate,
    required this.conversionRate,
    required this.nextMonth,
    required this.nextQuarter,
    required this.nextYear,
    required this.trends,
    this.methodology,
  });

  factory PlanFinancialReport.fromJson(Json json) {
    final j = json.unwrapData();
    final r = j.obj('revenue') ?? const <String, dynamic>{};
    final s = j.obj('subscriptions') ?? const <String, dynamic>{};
    final p = j.obj('projections') ?? const <String, dynamic>{};
    return PlanFinancialReport(
      current: r.dbl('current_period'),
      previous: r.dbl('previous_period'),
      growth: r.dbl('growth_percentage'),
      averagePerUser: r.dbl('average_per_user'),
      lifetime: r.dbl('total_lifetime'),
      newSubscriptions: s.integer('new_subscriptions'),
      cancelled: s.integer('cancelled_subscriptions'),
      churnRate: s.dbl('churn_rate'),
      retentionRate: s.dbl('retention_rate'),
      conversionRate: s.dbl('conversion_rate'),
      nextMonth: p.dbl('next_month'),
      nextQuarter: p.dbl('next_quarter'),
      nextYear: p.dbl('next_year'),
      methodology: p.strOrNull('methodology'),
      trends: j.list(
        'trends',
        (t) => (
          period: t.str('period'),
          revenue: t.dbl('revenue'),
          subscriptions: t.integer('subscriptions'),
        ),
      ),
    );
  }

  final double current;
  final double previous;
  final double growth;
  final double averagePerUser;
  final double lifetime;
  final int newSubscriptions;
  final int cancelled;
  final double churnRate;
  final double retentionRate;
  final double conversionRate;
  final double nextMonth;
  final double nextQuarter;
  final double nextYear;
  final String? methodology;
  final List<({String period, double revenue, int subscriptions})> trends;

  @override
  List<Object?> get props => [current, previous, growth, trends];
}

/// Resultado de uma migração de empresas entre planos.
class PlanMigration extends Equatable {
  const PlanMigration({
    required this.id,
    required this.status,
    required this.total,
    required this.successful,
    required this.failed,
    this.fromPlan,
    this.toPlan,
    this.summary,
    this.scheduledFor,
    this.completedAt,
    this.results = const [],
  });

  factory PlanMigration.fromJson(Json json) {
    final j = json.unwrapData();
    return PlanMigration(
      id: j.str('migration_id'),
      status: j.str('status'),
      total: j.integer('total_companies'),
      successful: j.integer('successful'),
      failed: j.integer('failed'),
      fromPlan: j.strOrNull('from_plan_name'),
      toPlan: j.strOrNull('to_plan_name'),
      summary: j.strOrNull('summary'),
      scheduledFor: j.date('scheduled_for'),
      completedAt: j.date('completed_at'),
      results: j.list('results', MigrationCompanyResult.fromJson),
    );
  }

  final String id;
  final String status;
  final int total;
  final int successful;
  final int failed;
  final String? fromPlan;
  final String? toPlan;
  final String? summary;
  final DateTime? scheduledFor;
  final DateTime? completedAt;

  /// Resultado por empresa (preenchido após a execução).
  final List<MigrationCompanyResult> results;

  bool get canExecute => status == 'scheduled';

  String get statusLabel => switch (status) {
    'scheduled' => 'Agendada',
    'in_progress' => 'Em andamento',
    'completed' => 'Concluída',
    'failed' => 'Falhou',
    _ => status,
  };

  @override
  List<Object?> get props => [id, status, successful, failed, results];
}

class MigrationCompanyResult extends Equatable {
  const MigrationCompanyResult({
    required this.companyName,
    required this.success,
    this.error,
  });

  factory MigrationCompanyResult.fromJson(Json j) => MigrationCompanyResult(
    companyName: j.str('company_name'),
    success: j.boolean('success'),
    error: j.strOrNull('error'),
  );

  final String companyName;
  final bool success;
  final String? error;

  @override
  List<Object?> get props => [companyName, success, error];
}

/// Recurso do catálogo da plataforma, usado nos planos.
class AvailableFeature extends Equatable {
  const AvailableFeature({
    required this.name,
    this.description,
    this.category,
    this.isActive = true,
  });

  factory AvailableFeature.fromJson(Json j) => AvailableFeature(
    name: j.str('name'),
    description: j.strOrNull('description'),
    category: j.strOrNull('category'),
    isActive: j.boolean('is_active', fallback: true),
  );

  final String name;
  final String? description;
  final String? category;
  final bool isActive;

  PlanFeature toPlanFeature() =>
      PlanFeature(name: name, description: description);

  @override
  List<Object?> get props => [name, category, isActive];
}

/// Entrada do histórico de alterações de um plano.
class PlanAuditEntry extends Equatable {
  const PlanAuditEntry({
    required this.id,
    required this.action,
    this.userEmail,
    this.reason,
    this.changedFields = const [],
    this.createdAt,
  });

  factory PlanAuditEntry.fromJson(Json j) => PlanAuditEntry(
    id: j.str('id'),
    action: j.str('action'),
    userEmail: j.strOrNull('user_email'),
    reason: j.strOrNull('reason'),
    changedFields: (j.obj('changes')?.keys.toList() ?? const <String>[])
      ..sort(),
    createdAt: j.date('created_at'),
  );

  final String id;

  /// created, updated, deleted, activated, deactivated (e migrações).
  final String action;
  final String? userEmail;
  final String? reason;
  final List<String> changedFields;
  final DateTime? createdAt;

  String get actionLabel => switch (action) {
    'created' => 'Criado',
    'updated' => 'Atualizado',
    'deleted' => 'Excluído',
    'activated' => 'Ativado',
    'deactivated' => 'Desativado',
    'migrated' || 'migration' => 'Migração',
    _ => action,
  };

  @override
  List<Object?> get props => [id, action, createdAt];
}

/// Dados de cobrança de `GET /admin/subscriptions/{org}`.
class SubscriptionDetail extends Equatable {
  const SubscriptionDetail({
    this.planName,
    this.planPrice,
    this.planCycle,
    this.statusUpdatedAt,
  });

  factory SubscriptionDetail.fromJson(Json json) {
    final j = json.unwrapData();
    final plan = j.obj('current_plan');
    return SubscriptionDetail(
      planName: plan?.strOrNull('name'),
      planPrice: plan?.dblOrNull('price'),
      planCycle: plan?.strOrNull('cycle'),
      statusUpdatedAt: j.date('status_updated_at'),
    );
  }

  final String? planName;
  final double? planPrice;
  final String? planCycle;
  final DateTime? statusUpdatedAt;

  @override
  List<Object?> get props => [planName, planPrice, planCycle, statusUpdatedAt];
}

abstract interface class AdminRepository {
  Future<AdminStats> stats();
  Future<Paginated<AdminCompany>> companies({
    PageQuery page = const PageQuery(),
    String? status,
  });
  Future<AdminCompany> company(String organizationId);
  Future<void> setCompanyStatus(
    String organizationId,
    SubscriptionStatus status, {
    String? reason,
  });
  Future<Paginated<AdminCompany>> subscriptions({
    PageQuery page = const PageQuery(),
    String? status,
  });
  Future<List<Payment>> companyPayments(String organizationId);
  Future<List<Plan>> plans();
  Future<Plan> savePlan(Plan plan, {bool create = false});
  Future<void> deletePlan(String id);
  Future<(bool, String?)> canDeletePlan(String id);
  Future<void> setPlansActive(List<String> ids, {required bool active});
  Future<PlanStats> planStats(String id);
  Future<List<AdminCompany>> planCompanies(String id);
  Future<List<PlanTemplate>> planTemplates();
  Future<void> planFromTemplate(String templateId);
  Future<PlanFinancialReport> planFinancialReport(
    String id, {
    ReportPeriod period = ReportPeriod.monthly,
  });
  Future<PlanMigration> createMigration({
    required String fromPlanId,
    required String toPlanId,
    required String reason,
    bool notifyUsers = true,
    DateTime? scheduledFor,
  });
  Future<PlanMigration> executeMigration(String migrationId);
  Future<PlanMigration> migration(String migrationId);
  Future<List<AvailableFeature>> availableFeatures();
  Future<Paginated<PlanAuditEntry>> planHistory(String id, {int page = 1});
  Future<SubscriptionDetail> subscriptionDetail(String organizationId);
}
