import 'package:spooliq_desktop/core/network/api_client.dart';
import 'package:spooliq_desktop/core/network/json.dart';
import 'package:spooliq_desktop/features/dashboard/domain/dashboard.dart';

class ApiDashboardRepository implements DashboardRepository {
  const ApiDashboardRepository(this._api);

  final ApiClient _api;

  Future<Json> _get(String path, DashboardPeriod? p, {int? limit}) =>
      _api.getJson(
        '/dashboard/$path',
        query: {'period': p?.value, 'limit': limit},
      );

  @override
  Future<Overview> overview(DashboardPeriod p) async =>
      Overview.fromJson(await _get('overview', p));

  @override
  Future<List<TrendPoint>> revenueTrend(DashboardPeriod p) async =>
      (await _get('revenue-trend', p)).list('points', TrendPoint.fromJson);

  @override
  Future<List<FunnelStep>> funnel(DashboardPeriod p) async =>
      (await _get('conversion-funnel', p)).list('steps', FunnelStep.fromJson);

  @override
  Future<List<RankedItem>> topMaterials(DashboardPeriod p) async =>
      (await _get('top-materials', p, limit: 6)).list(
        'materials',
        (j) => RankedItem(
          id: j.str('id'),
          name: j.str('name'),
          value: j.dbl('total_grams'),
          count: j.integer('usage_count'),
        ),
      );

  @override
  Future<GoalsSummary> goals() async =>
      GoalsSummary.fromJson(await _get('goals-alerts', null));

  @override
  Future<void> saveGoals(Map<GoalMetric, double> targets) => _api.put(
    '/dashboard/goals',
    body: {
      'goals': [
        for (final e in targets.entries)
          {'metric': e.key.value, 'target': e.value},
      ],
    },
  );

  @override
  Future<Operations> operations(DashboardPeriod p) async =>
      Operations.fromJson(await _get('operational-insights', p));

  @override
  Future<Profitability> profitability(DashboardPeriod p) async =>
      Profitability.fromJson(await _get('profitability', p, limit: 10));

  @override
  Future<ResponseTimes> responseTimes(DashboardPeriod p) async =>
      ResponseTimes.fromJson(await _get('response-times', p));

  @override
  Future<List<Insight>> insights(DashboardPeriod p) async =>
      (await _get('insights', p)).list('insights', Insight.fromJson);

  @override
  Future<List<RankedItem>> lowStock() async =>
      (await _get('low-stock', null)).list(
        'data',
        (j) => RankedItem(
          id: j.str('id'),
          name: j.str('name'),
          subtitle: [
            j.str('color'),
            j.str('brand_name'),
          ].where((s) => s.isNotEmpty).join(' · '),
          colorHex: j.strOrNull('color_hex'),
          value: j.integer('stock_grams'),
          count: j.integer('low_stock_threshold_grams'),
        ),
      );

  @override
  Future<List<Activity>> recentActivity() async =>
      (await _get('recent-activity', null, limit: 12)).list(
        'activities',
        Activity.fromJson,
      );
}
