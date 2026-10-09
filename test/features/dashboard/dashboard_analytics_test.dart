import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/routing/routes.dart';
import 'package:spooliq_desktop/features/dashboard/domain/dashboard.dart';
import 'package:spooliq_desktop/features/dashboard/presentation/dashboard_cubit.dart';
import 'package:spooliq_desktop/features/dashboard/presentation/widgets/goals_card.dart';
import 'package:spooliq_desktop/features/dashboard/presentation/widgets/insights_panel.dart';
import 'package:spooliq_desktop/features/dashboard/presentation/widgets/profitability_card.dart';
import 'package:spooliq_desktop/features/dashboard/presentation/widgets/response_times_card.dart';

class _Repo extends Mock implements DashboardRepository {}

const _goals = GoalsSummary(goals: [], alerts: [], month: '2026-10');

void main() {
  group('parsing', () {
    test('overview reads profit fields and the weighted margin', () {
      final o = Overview.fromJson(const {
        'total_revenue': 17000,
        'avg_profit_margin': 10,
        'profit_margin': 26.6,
        'net_revenue': 15000,
        'profit': 4000,
        'profit_realized': 3000,
        'profit_forecast': 1000,
        'profit_margin_points_change': -3.5,
        'profit_per_print_hour': 1333,
        'print_hours': 3,
        'sales_count': 2,
      });
      expect(o.netRevenueCents, 15000);
      expect(o.profitCents, 4000);
      expect(o.profitRealizedCents + o.profitForecastCents, o.profitCents);
      expect(o.profitMargin, 26.6);
      expect(o.marginPointsChange, -3.5);
      expect(o.profitPerHourCents, 1333);
    });

    test('overview falls back to the old margin field', () {
      expect(
        Overview.fromJson(const {'avg_profit_margin': 12}).profitMargin,
        12,
      );
    });

    test('goals summary keeps metric, projection and pace', () {
      final s = GoalsSummary.fromJson(const {
        'month': '2026-10',
        'goals': [
          {
            'metric': 'profit',
            'configured': true,
            'current': 20000,
            'target': 100000,
            'progress': 20,
            'projected': 60000,
            'projected_progress': 60,
            'required_per_day': 8000,
            'days_left': 10,
          },
          {'metric': 'budgets', 'configured': false},
        ],
        'alerts': <Object>[],
      });
      final profit = s.of(GoalMetric.profit)!;
      expect(profit.offPace, isTrue);
      expect(profit.requiredPerDay, 8000);
      expect(s.of(GoalMetric.budgets)!.configured, isFalse);
      expect(s.of(GoalMetric.revenue), isNull);
    });

    test('profitability, response times and insights', () {
      final p = Profitability.fromJson(const {
        'average_margin': 25,
        'by_customer': [
          {
            'id': 'c1',
            'name': 'Ana',
            'revenue': 100,
            'profit': 30,
            'margin': 30,
            'discount_rate': 12.5,
            'repeat': true,
          },
        ],
      });
      expect(p.byCustomer.single.repeat, isTrue);
      expect(p.byMaterial, isEmpty);

      final r = ResponseTimes.fromJson(const {
        'approved': 2,
        'rejected': 1,
        'approval_median_hours': 14,
        'approval_buckets': [
          {'label': 'Menos de 1 dia', 'count': 1},
        ],
        'recent_rejections': [
          {'budget_id': 'b1', 'customer': 'Beto', 'reason': 'caro'},
        ],
      });
      expect(r.decided, 3);
      expect(r.buckets.single.count, 1);
      expect(r.recentRejections.single.reason, 'caro');

      final i = Insight.fromJson(const {
        'kind': 'expiring_soon',
        'severity': 'warning',
        'title': 't',
        'detail': 'd',
        'metric': r'R$ 100,00',
        'action': {'label': 'Ver', 'target': 'budgets', 'filter': 'sent'},
      });
      expect(i.severity, InsightSeverity.warning);
      expect(i.action!.filter, 'sent');
      expect(
        InsightSeverity.fromValue('unknown'),
        InsightSeverity.info,
      );
    });
  });

  group('helpers', () {
    test('insight actions map to app routes', () {
      expect(
        insightRoute(
          const InsightAction(label: '', target: 'budgets', filter: 'sent'),
        ),
        '${Routes.budgets}?status=sent',
      );
      expect(
        insightRoute(
          const InsightAction(label: '', target: 'customer', id: 'c1'),
        ),
        Routes.customer('c1'),
      );
      expect(
        insightRoute(const InsightAction(label: '', target: 'customer')),
        Routes.customers,
      );
      expect(
        insightRoute(const InsightAction(label: '', target: 'machines')),
        Routes.machines,
      );
      expect(
        insightRoute(const InsightAction(label: '', target: 'goals')),
        isNull,
      );
    });

    test('goal form values become API targets (cents, empty removes)', () {
      expect(
        goalTargetsFromInput({
          GoalMetric.revenue: 1234.56,
          GoalMetric.profit: null,
          GoalMetric.budgets: 12,
          GoalMetric.approvalRate: 55.5,
        }),
        {
          GoalMetric.revenue: 123456,
          GoalMetric.profit: 0,
          GoalMetric.budgets: 12,
          GoalMetric.approvalRate: 55.5,
        },
      );
    });

    test('profit rows sort by the chosen column', () {
      const a = ProfitRow(
        id: 'a',
        name: 'A',
        revenueCents: 100,
        profitCents: 50,
        margin: 50,
      );
      const b = ProfitRow(
        id: 'b',
        name: 'B',
        revenueCents: 300,
        profitCents: 30,
        margin: 10,
      );
      expect(sortProfitRows([a, b], ProfitSort.revenue).first, b);
      expect(sortProfitRows([b, a], ProfitSort.profit).first, a);
      expect(sortProfitRows([b, a], ProfitSort.margin).first, a);
    });

    test('hours read as hours or days', () {
      expect(formatHours(0), '—');
      expect(formatHours(5), '5 h');
      expect(formatHours(24), '1 dia');
      expect(formatHours(36), '1,5 dias');
      expect(formatHours(24 * 12), '12 dias');
    });
  });

  group('DashboardCubit', () {
    late _Repo repo;

    setUpAll(() => registerFallbackValue(DashboardPeriod.d30));

    setUp(() {
      repo = _Repo();
      when(() => repo.overview(any())).thenAnswer(
        (_) async => Overview.fromJson(const {}),
      );
      when(() => repo.revenueTrend(any())).thenAnswer((_) async => []);
      when(() => repo.funnel(any())).thenAnswer((_) async => []);
      when(() => repo.topMaterials(any())).thenAnswer((_) async => []);
      when(() => repo.goals()).thenAnswer((_) async => _goals);
      when(() => repo.operations(any())).thenAnswer(
        (_) async => Operations.fromJson(const {}),
      );
      when(() => repo.profitability(any())).thenThrow(
        const NetworkError('sem rede'),
      );
      when(() => repo.responseTimes(any())).thenAnswer(
        (_) async => ResponseTimes.fromJson(const {}),
      );
      when(() => repo.insights(any())).thenAnswer((_) async => []);
      when(() => repo.lowStock()).thenAnswer((_) async => []);
      when(() => repo.recentActivity()).thenAnswer((_) async => []);
    });

    blocTest<DashboardCubit, DashboardState>(
      'a failing section does not block the others',
      build: () => DashboardCubit(repo),
      act: (c) => c.load(),
      verify: (c) {
        expect(c.state.anyLoading, isFalse);
        expect(c.state.profitability.error, 'sem rede');
        expect(c.state.goals.data, _goals);
        expect(c.state.insights.data, isEmpty);
      },
    );

    blocTest<DashboardCubit, DashboardState>(
      'saving goals reloads goals and insights',
      build: () => DashboardCubit(repo),
      setUp: () => when(() => repo.saveGoals(any())).thenAnswer((_) async {}),
      act: (c) async {
        await c.load();
        await c.saveGoals({GoalMetric.profit: 500000});
      },
      verify: (_) {
        verify(() => repo.saveGoals({GoalMetric.profit: 500000})).called(1);
        verify(() => repo.goals()).called(2);
        verify(() => repo.insights(DashboardPeriod.d30)).called(2);
      },
    );

    test('a failed save surfaces the API error to the dialog', () async {
      when(() => repo.saveGoals(any())).thenThrow(
        const ValidationError('Meta inválida'),
      );
      final cubit = DashboardCubit(repo);
      addTearDown(cubit.close);
      await expectLater(
        cubit.saveGoals({GoalMetric.approvalRate: 120}),
        throwsA(isA<ValidationError>()),
      );
    });
  });
}
