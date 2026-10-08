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
}
