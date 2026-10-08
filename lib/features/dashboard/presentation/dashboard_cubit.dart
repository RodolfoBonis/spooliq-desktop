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
    this.customers = const Section.loading(),
    this.filaments = const Section.loading(),
    this.materials = const Section.loading(),
    this.goals = const Section.loading(),
    this.insights = const Section.loading(),
    this.lowStock = const Section.loading(),
    this.activity = const Section.loading(),
  });

  final DashboardPeriod period;
  final Section<Overview> overview;
  final Section<List<TrendPoint>> trend;
  final Section<List<FunnelStep>> funnel;
  final Section<List<RankedItem>> customers;
  final Section<List<RankedItem>> filaments;
  final Section<List<RankedItem>> materials;
  final Section<(List<Goal>, List<DashboardAlert>)> goals;
  final Section<Insights> insights;
  final Section<List<RankedItem>> lowStock;
  final Section<List<Activity>> activity;

  DashboardState copyWith({
    DashboardPeriod? period,
    Section<Overview>? overview,
    Section<List<TrendPoint>>? trend,
    Section<List<FunnelStep>>? funnel,
    Section<List<RankedItem>>? customers,
    Section<List<RankedItem>>? filaments,
    Section<List<RankedItem>>? materials,
    Section<(List<Goal>, List<DashboardAlert>)>? goals,
    Section<Insights>? insights,
    Section<List<RankedItem>>? lowStock,
    Section<List<Activity>>? activity,
  }) => DashboardState(
    period: period ?? this.period,
    overview: overview ?? this.overview,
    trend: trend ?? this.trend,
    funnel: funnel ?? this.funnel,
    customers: customers ?? this.customers,
    filaments: filaments ?? this.filaments,
    materials: materials ?? this.materials,
    goals: goals ?? this.goals,
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
    customers,
    filaments,
    materials,
    goals,
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
    ) async {
      Section<T> section;
      try {
        section = Section.data(await fetch());
      } on ApiError catch (e) {
        section = Section.error(e.message);
      }
      if (!isClosed && gen == _generation) emit(put(section));
    }

    await Future.wait([
      run(() => _repo.overview(p), (s) => state.copyWith(overview: s)),
      run(() => _repo.revenueTrend(p), (s) => state.copyWith(trend: s)),
      run(() => _repo.funnel(p), (s) => state.copyWith(funnel: s)),
      run(() => _repo.topCustomers(p), (s) => state.copyWith(customers: s)),
      run(() => _repo.topFilaments(p), (s) => state.copyWith(filaments: s)),
      run(() => _repo.topMaterials(p), (s) => state.copyWith(materials: s)),
      run(() => _repo.goalsAlerts(p), (s) => state.copyWith(goals: s)),
      run(() => _repo.insights(p), (s) => state.copyWith(insights: s)),
      run(_repo.lowStock, (s) => state.copyWith(lowStock: s)),
      run(_repo.recentActivity, (s) => state.copyWith(activity: s)),
    ]);
  }
}
