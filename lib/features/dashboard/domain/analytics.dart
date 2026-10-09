import 'package:equatable/equatable.dart';
import 'package:spooliq_desktop/core/network/json.dart';
import 'package:spooliq_desktop/features/dashboard/domain/dashboard.dart';

/// Métrica de uma meta mensal. Dinheiro em centavos; aprovação em %.
enum GoalMetric {
  revenue('revenue', 'Receita líquida', GoalUnit.cents),
  profit('profit', 'Lucro', GoalUnit.cents),
  budgets('budgets', 'Vendas', GoalUnit.count),
  approvalRate('approval_rate', 'Taxa de aprovação', GoalUnit.percent);

  const GoalMetric(this.value, this.label, this.unit);

  final String value;
  final String label;
  final GoalUnit unit;

  static GoalMetric? fromValue(String v) {
    for (final m in values) {
      if (m.value == v) return m;
    }
    return null;
  }
}

enum GoalUnit { cents, count, percent }

/// Meta do mês corrente com progresso e projeção para o fim do mês.
class Goal extends Equatable {
  const Goal({
    required this.metric,
    required this.configured,
    required this.current,
    required this.target,
    required this.progress,
    required this.projected,
    required this.projectedProgress,
    required this.requiredPerDay,
    required this.daysLeft,
  });

  factory Goal.fromJson(Json j) => Goal(
    metric: GoalMetric.fromValue(j.str('metric')) ?? GoalMetric.revenue,
    configured: j.boolean('configured'),
    current: j.dbl('current'),
    target: j.dbl('target'),
    progress: j.dbl('progress'),
    projected: j.dbl('projected'),
    projectedProgress: j.dbl('projected_progress'),
    requiredPerDay: j.dbl('required_per_day'),
    daysLeft: j.integer('days_left'),
  );

  final GoalMetric metric;

  /// Sem meta cadastrada: o card oferece "Definir meta".
  final bool configured;
  final double current;
  final double target;
  final double progress;
  final double projected;
  final double projectedProgress;
  final double requiredPerDay;
  final int daysLeft;

  /// A projeção indica que a meta não será batida no ritmo atual.
  bool get offPace =>
      configured && progress < 100 && projectedProgress < 90 && daysLeft > 0;

  @override
  List<Object?> get props => [metric, configured, current, target, projected];
}

class GoalsSummary extends Equatable {
  const GoalsSummary({
    required this.goals,
    required this.alerts,
    required this.month,
  });

  factory GoalsSummary.fromJson(Json j) => GoalsSummary(
    goals: j.list('goals', Goal.fromJson),
    alerts: j.list('alerts', DashboardAlert.fromJson),
    month: j.str('month'),
  );

  final List<Goal> goals;
  final List<DashboardAlert> alerts;

  /// Mês das metas no formato AAAA-MM.
  final String month;

  Goal? of(GoalMetric metric) {
    for (final g in goals) {
      if (g.metric == metric) return g;
    }
    return null;
  }

  @override
  List<Object?> get props => [goals, alerts, month];
}

/// Uma linha de rentabilidade (material, filamento, cliente, máquina...).
class ProfitRow extends Equatable {
  const ProfitRow({
    required this.id,
    required this.name,
    required this.revenueCents,
    required this.profitCents,
    required this.margin,
    this.subtitle,
    this.colorHex,
    this.count = 0,
    this.grams = 0,
    this.hours = 0,
    this.profitPerHourCents = 0,
    this.discountRate = 0,
    this.repeat = false,
  });

  factory ProfitRow.fromJson(Json j) => ProfitRow(
    id: j.str('id'),
    name: j.str('name'),
    subtitle: j.strOrNull('subtitle'),
    colorHex: j.strOrNull('color_hex'),
    revenueCents: j.integer('revenue'),
    profitCents: j.integer('profit'),
    margin: j.dbl('margin'),
    count: j.integer('count'),
    grams: j.dbl('grams'),
    hours: j.dbl('hours'),
    profitPerHourCents: j.integer('profit_per_hour'),
    discountRate: j.dbl('discount_rate'),
    repeat: j.boolean('repeat'),
  );

  final String id;
  final String name;
  final String? subtitle;
  final String? colorHex;
  final int revenueCents;
  final int profitCents;
  final double margin;
  final int count;
  final double grams;
  final double hours;
  final int profitPerHourCents;
  final double discountRate;
  final bool repeat;

  @override
  List<Object?> get props => [id, revenueCents, profitCents, margin];
}

class Profitability extends Equatable {
  const Profitability({
    required this.byMaterial,
    required this.byFilament,
    required this.byCustomer,
    required this.byMachine,
    required this.averageMargin,
  });

  factory Profitability.fromJson(Json j) => Profitability(
    byMaterial: j.list('by_material', ProfitRow.fromJson),
    byFilament: j.list('by_filament', ProfitRow.fromJson),
    byCustomer: j.list('by_customer', ProfitRow.fromJson),
    byMachine: j.list('by_machine', ProfitRow.fromJson),
    averageMargin: j.dbl('average_margin'),
  );

  final List<ProfitRow> byMaterial;
  final List<ProfitRow> byFilament;
  final List<ProfitRow> byCustomer;
  final List<ProfitRow> byMachine;
  final double averageMargin;

  @override
  List<Object?> get props => [
    byMaterial,
    byFilament,
    byCustomer,
    byMachine,
    averageMargin,
  ];
}

class ResponseBucket extends Equatable {
  const ResponseBucket(this.label, this.count);

  factory ResponseBucket.fromJson(Json j) =>
      ResponseBucket(j.str('label'), j.integer('count'));

  final String label;
  final int count;

  @override
  List<Object?> get props => [label, count];
}

class RejectionReason extends Equatable {
  const RejectionReason({
    required this.budgetId,
    required this.budgetName,
    required this.customer,
    required this.reason,
    this.at,
  });

  factory RejectionReason.fromJson(Json j) => RejectionReason(
    budgetId: j.str('budget_id'),
    budgetName: j.str('budget_name'),
    customer: j.str('customer'),
    reason: j.str('reason'),
    at: j.date('at'),
  );

  final String budgetId;
  final String budgetName;
  final String customer;
  final String reason;
  final DateTime? at;

  @override
  List<Object?> get props => [budgetId, reason];
}

class ResponseTimes extends Equatable {
  const ResponseTimes({
    required this.approvalMedianHours,
    required this.approvalP75Hours,
    required this.rejectionMedianHours,
    required this.approved,
    required this.rejected,
    required this.expired,
    required this.expirationRate,
    required this.rejectionRate,
    required this.buckets,
    required this.recentRejections,
  });

  factory ResponseTimes.fromJson(Json j) => ResponseTimes(
    approvalMedianHours: j.dbl('approval_median_hours'),
    approvalP75Hours: j.dbl('approval_p75_hours'),
    rejectionMedianHours: j.dbl('rejection_median_hours'),
    approved: j.integer('approved'),
    rejected: j.integer('rejected'),
    expired: j.integer('expired'),
    expirationRate: j.dbl('expiration_rate'),
    rejectionRate: j.dbl('rejection_rate'),
    buckets: j.list('approval_buckets', ResponseBucket.fromJson),
    recentRejections: j.list('recent_rejections', RejectionReason.fromJson),
  );

  final double approvalMedianHours;
  final double approvalP75Hours;
  final double rejectionMedianHours;
  final int approved;
  final int rejected;
  final int expired;
  final double expirationRate;
  final double rejectionRate;
  final List<ResponseBucket> buckets;
  final List<RejectionReason> recentRejections;

  int get decided => approved + rejected + expired;

  @override
  List<Object?> get props => [
    approvalMedianHours,
    approved,
    rejected,
    expired,
    buckets,
    recentRejections,
  ];
}

enum InsightSeverity {
  critical,
  warning,
  info,
  positive;

  static InsightSeverity fromValue(String v) => switch (v) {
    'critical' => critical,
    'warning' => warning,
    'positive' => positive,
    _ => info,
  };
}

/// Destino da ação sugerida por um insight (independente de rota).
class InsightAction extends Equatable {
  const InsightAction({
    required this.label,
    required this.target,
    this.id,
    this.filter,
  });

  factory InsightAction.fromJson(Json j) => InsightAction(
    label: j.str('label'),
    target: j.str('target'),
    id: j.strOrNull('id'),
    filter: j.strOrNull('filter'),
  );

  final String label;
  final String target;
  final String? id;
  final String? filter;

  @override
  List<Object?> get props => [label, target, id, filter];
}

/// Recomendação gerada por regras no backend, já em pt-BR.
class Insight extends Equatable {
  const Insight({
    required this.kind,
    required this.severity,
    required this.title,
    required this.detail,
    this.metric,
    this.action,
  });

  factory Insight.fromJson(Json j) {
    final action = j.obj('action');
    return Insight(
      kind: j.str('kind'),
      severity: InsightSeverity.fromValue(j.str('severity')),
      title: j.str('title'),
      detail: j.str('detail'),
      metric: j.strOrNull('metric'),
      action: action == null ? null : InsightAction.fromJson(action),
    );
  }

  final String kind;
  final InsightSeverity severity;
  final String title;
  final String detail;
  final String? metric;
  final InsightAction? action;

  @override
  List<Object?> get props => [kind, severity, title, detail, metric, action];
}
