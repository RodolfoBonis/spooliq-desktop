import 'package:equatable/equatable.dart';
import 'package:spooliq_desktop/core/network/json.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_status.dart';

enum DashboardPeriod {
  d7('7d', '7 dias'),
  d30('30d', '30 dias'),
  m3('3m', '3 meses'),
  m6('6m', '6 meses'),
  y1('1y', '12 meses'),
  all('all', 'Tudo');

  const DashboardPeriod(this.value, this.label);

  final String value;
  final String label;
}

class Overview extends Equatable {
  const Overview({
    required this.revenueCents,
    required this.revenueChange,
    required this.budgets,
    required this.budgetsChange,
    required this.avgTicketCents,
    required this.avgTicketChange,
    required this.approvalRate,
    required this.approvalRateChange,
    required this.profitMargin,
    required this.profitMarginChange,
    required this.newCustomers,
    required this.newCustomersChange,
    required this.byStatus,
  });

  factory Overview.fromJson(Json j) => Overview(
    revenueCents: j.integer('total_revenue'),
    revenueChange: j.dbl('revenue_change'),
    budgets: j.integer('total_budgets'),
    budgetsChange: j.dbl('budgets_change'),
    avgTicketCents: j.integer('avg_ticket'),
    avgTicketChange: j.dbl('avg_ticket_change'),
    approvalRate: j.dbl('approval_rate'),
    approvalRateChange: j.dbl('approval_rate_change'),
    profitMargin: j.dbl('avg_profit_margin'),
    profitMarginChange: j.dbl('profit_margin_change'),
    newCustomers: j.integer('new_customers'),
    newCustomersChange: j.dbl('new_customers_change'),
    byStatus: {
      for (final e in j.list('budgets_by_status', (x) => x))
        BudgetStatus.fromValue(e.str('status')): e.integer('count'),
    },
  );

  final int revenueCents;
  final double revenueChange;
  final int budgets;
  final double budgetsChange;
  final int avgTicketCents;
  final double avgTicketChange;
  final double approvalRate;
  final double approvalRateChange;
  final double profitMargin;
  final double profitMarginChange;
  final int newCustomers;
  final double newCustomersChange;
  final Map<BudgetStatus, int> byStatus;

  @override
  List<Object?> get props => [
    revenueCents,
    budgets,
    avgTicketCents,
    approvalRate,
    byStatus,
  ];
}

class TrendPoint extends Equatable {
  const TrendPoint({
    required this.date,
    required this.revenueCents,
    required this.costCents,
    required this.profitCents,
    required this.budgets,
  });

  factory TrendPoint.fromJson(Json j) => TrendPoint(
    date: DateTime.tryParse(j.str('date')) ?? DateTime.now(),
    revenueCents: j.integer('revenue'),
    costCents: j.integer('cost'),
    profitCents: j.integer('profit'),
    budgets: j.integer('budget_count'),
  );

  final DateTime date;
  final int revenueCents;
  final int costCents;
  final int profitCents;
  final int budgets;

  @override
  List<Object?> get props => [date, revenueCents, costCents, profitCents];
}

class FunnelStep extends Equatable {
  const FunnelStep({
    required this.status,
    required this.count,
    required this.rate,
  });

  factory FunnelStep.fromJson(Json j) => FunnelStep(
    status: BudgetStatus.fromValue(j.str('status')),
    count: j.integer('count'),
    rate: j.dbl('conversion_rate'),
  );

  final BudgetStatus status;
  final int count;
  final double rate;

  @override
  List<Object?> get props => [status, count, rate];
}

class RankedItem extends Equatable {
  const RankedItem({
    required this.id,
    required this.name,
    required this.value,
    this.subtitle,
    this.colorHex,
    this.count = 0,
  });

  final String id;
  final String name;
  final String? subtitle;
  final String? colorHex;

  /// Centavos (clientes) ou gramas (filamentos/materiais).
  final num value;
  final int count;

  @override
  List<Object?> get props => [id, name, value, count];
}

class Goal extends Equatable {
  const Goal({
    required this.name,
    required this.current,
    required this.target,
    required this.progress,
    required this.unit,
  });

  factory Goal.fromJson(Json j) => Goal(
    name: j.str('name'),
    current: j.dbl('current'),
    target: j.dbl('target'),
    progress: j.dbl('progress'),
    unit: j.str('unit'),
  );

  final String name;
  final double current;
  final double target;
  final double progress;
  final String unit;

  @override
  List<Object?> get props => [name, current, target];
}

class DashboardAlert extends Equatable {
  const DashboardAlert({
    required this.severity,
    required this.message,
    this.entityType,
  });

  factory DashboardAlert.fromJson(Json j) => DashboardAlert(
    severity: j.str('severity'),
    message: j.str('message'),
    entityType: j.strOrNull('entity_type'),
  );

  final String severity;
  final String message;
  final String? entityType;

  @override
  List<Object?> get props => [severity, message];
}

class Insights extends Equatable {
  const Insights({
    required this.printHours,
    required this.printTimeChange,
    required this.rejectionRate,
    required this.rejectionRateChange,
    required this.breakdown,
  });

  factory Insights.fromJson(Json j) {
    final c = j.obj('cost_breakdown') ?? const <String, dynamic>{};
    return Insights(
      printHours: j.dbl('total_print_time_hours'),
      printTimeChange: j.dbl('print_time_change'),
      rejectionRate: j.dbl('rejection_rate'),
      rejectionRateChange: j.dbl('rejection_rate_change'),
      breakdown: {
        'Filamento': c.dbl('filament_pct'),
        'Desperdício': c.dbl('waste_pct'),
        'Energia': c.dbl('energy_pct'),
        'Setup': c.dbl('setup_pct'),
        'Mão de obra': c.dbl('labor_pct'),
        'Overhead': c.dbl('overhead_pct'),
      },
    );
  }

  final double printHours;
  final double printTimeChange;
  final double rejectionRate;
  final double rejectionRateChange;
  final Map<String, double> breakdown;

  @override
  List<Object?> get props => [printHours, rejectionRate, breakdown];
}

class Activity extends Equatable {
  const Activity({
    required this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.entityName,
    this.description,
    this.at,
  });

  factory Activity.fromJson(Json j) => Activity(
    id: j.str('id'),
    action: j.str('action'),
    entityType: j.str('entity_type'),
    entityId: j.str('entity_id'),
    entityName: j.str('entity_name'),
    description: j.strOrNull('description'),
    at: j.date('created_at'),
  );

  final String id;
  final String action;
  final String entityType;
  final String entityId;
  final String entityName;
  final String? description;
  final DateTime? at;

  @override
  List<Object?> get props => [id];
}

abstract interface class DashboardRepository {
  Future<Overview> overview(DashboardPeriod p);
  Future<List<TrendPoint>> revenueTrend(DashboardPeriod p);
  Future<List<FunnelStep>> funnel(DashboardPeriod p);
  Future<List<RankedItem>> topCustomers(DashboardPeriod p);
  Future<List<RankedItem>> topFilaments(DashboardPeriod p);
  Future<List<RankedItem>> topMaterials(DashboardPeriod p);
  Future<(List<Goal>, List<DashboardAlert>)> goalsAlerts(DashboardPeriod p);
  Future<Insights> insights(DashboardPeriod p);
  Future<List<RankedItem>> lowStock();
  Future<List<Activity>> recentActivity();
}
