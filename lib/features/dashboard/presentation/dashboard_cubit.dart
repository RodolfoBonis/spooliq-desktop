import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/features/dashboard/domain/dashboard.dart';

/// Estado de um card do dashboard (carrega de forma independente).
class Section<T> extends Equatable {
  const Section.loading() : data = null, error = null, loading = true;
  const Section.data(T this.data) : error = null, loading = false;
  const Section.error(String this.error) : data = null, loading = false;

  final T? data;
  final String? error;
  final bool loading;

  @override
  List<Object?> get props => [data, error, loading];
}

class DashboardState extends Equatable {
  const DashboardState({
    this.period = DashboardPeriod.d30,
    this.overview = const Section.loading(),
    this.trend = const Section.loading(),
    this.funnel = const Section.loading(),
    this.materials = const Section.loading(),
    this.goals = const Section.loading(),
    this.operations = const Section.loading(),
    this.profitability = const Section.loading(),
    this.responseTimes = const Section.loading(),
    this.insights = const Section.loading(),
    this.lowStock = const Section.loading(),
    this.activity = const Section.loading(),
  });

  final DashboardPeriod period;
  final Section<Overview> overview;
  final Section<List<TrendPoint>> trend;
  final Section<List<FunnelStep>> funnel;
  final Section<List<RankedItem>> materials;
  final Section<GoalsSummary> goals;
  final Section<Operations> operations;
  final Section<Profitability> profitability;
  final Section<ResponseTimes> responseTimes;
  final Section<List<Insight>> insights;
  final Section<List<RankedItem>> lowStock;
  final Section<List<Activity>> activity;

  /// Alguma seção ainda carregando (ex.: exportar agora sairia incompleto).
  bool get anyLoading => [
    overview,
    trend,
    funnel,
    materials,
    goals,
    operations,
    profitability,
    responseTimes,
    insights,
    lowStock,
    activity,
  ].any((s) => s.loading);

  DashboardState copyWith({
    DashboardPeriod? period,
    Section<Overview>? overview,
    Section<List<TrendPoint>>? trend,
    Section<List<FunnelStep>>? funnel,
    Section<List<RankedItem>>? materials,
    Section<GoalsSummary>? goals,
    Section<Operations>? operations,
    Section<Profitability>? profitability,
    Section<ResponseTimes>? responseTimes,
    Section<List<Insight>>? insights,
    Section<List<RankedItem>>? lowStock,
    Section<List<Activity>>? activity,
  }) => DashboardState(
    period: period ?? this.period,
    overview: overview ?? this.overview,
    trend: trend ?? this.trend,
    funnel: funnel ?? this.funnel,
    materials: materials ?? this.materials,
    goals: goals ?? this.goals,
    operations: operations ?? this.operations,
    profitability: profitability ?? this.profitability,
    responseTimes: responseTimes ?? this.responseTimes,
    insights: insights ?? this.insights,
    lowStock: lowStock ?? this.lowStock,
    activity: activity ?? this.activity,
  );

  @override
  List<Object?> get props => [
    period,
    overview,
    trend,
    funnel,
    materials,
    goals,
    operations,
    profitability,
    responseTimes,
    insights,
    lowStock,
    activity,
  ];
}

class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit(this._repo) : super(const DashboardState());

  final DashboardRepository _repo;
  int _generation = 0;

  Future<void> load([DashboardPeriod? period]) async {
    final p = period ?? state.period;
    final gen = ++_generation;
    emit(DashboardState(period: p));
    Future<void> run<T>(
      Future<T> Function() fetch,
      DashboardState Function(Section<T>) put,
    ) => _run(gen, fetch, put);

    await Future.wait([
      run(() => _repo.overview(p), (s) => state.copyWith(overview: s)),
      run(() => _repo.revenueTrend(p), (s) => state.copyWith(trend: s)),
      run(() => _repo.funnel(p), (s) => state.copyWith(funnel: s)),
      run(() => _repo.topMaterials(p), (s) => state.copyWith(materials: s)),
      run(_repo.goals, (s) => state.copyWith(goals: s)),
      run(() => _repo.operations(p), (s) => state.copyWith(operations: s)),
      run(
        () => _repo.profitability(p),
        (s) => state.copyWith(profitability: s),
      ),
      run(
        () => _repo.responseTimes(p),
        (s) => state.copyWith(responseTimes: s),
      ),
      run(() => _repo.insights(p), (s) => state.copyWith(insights: s)),
      run(_repo.lowStock, (s) => state.copyWith(lowStock: s)),
      run(_repo.recentActivity, (s) => state.copyWith(activity: s)),
    ]);
  }

  /// Salva as metas do mês e recarrega metas e insights (que dependem delas).
  /// Erros da API sobem para o diálogo mostrar.
  Future<void> saveGoals(Map<GoalMetric, double> targets) async {
    await _repo.saveGoals(targets);
    final gen = _generation;
    final p = state.period;
    await Future.wait([
      _run(gen, _repo.goals, (s) => state.copyWith(goals: s)),
      _run(gen, () => _repo.insights(p), (s) => state.copyWith(insights: s)),
    ]);
  }

  Future<void> _run<T>(
    int gen,
    Future<T> Function() fetch,
    DashboardState Function(Section<T>) put,
  ) async {
    Section<T> section;
    try {
      section = Section.data(await fetch());
    } on ApiError catch (e) {
      section = Section.error(e.message);
    }
    if (!isClosed && gen == _generation) emit(put(section));
  }
}
