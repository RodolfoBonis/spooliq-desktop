import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forma_theme_spooliq/forma_theme_spooliq.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spooliq_desktop/features/dashboard/domain/dashboard.dart';
import 'package:spooliq_desktop/features/dashboard/presentation/dashboard_cubit.dart';
import 'package:spooliq_desktop/features/dashboard/presentation/widgets/goals_card.dart';
import 'package:spooliq_desktop/features/dashboard/presentation/widgets/insights_panel.dart';

class _Repo extends Mock implements DashboardRepository {}

const _offPace = Goal(
  metric: GoalMetric.profit,
  configured: true,
  current: 20000,
  target: 100000,
  progress: 20,
  projected: 60000,
  projectedProgress: 60,
  requiredPerDay: 8000,
  daysLeft: 10,
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    registerFallbackValue(<GoalMetric, double>{});
    registerFallbackValue(DashboardPeriod.d30);
  });

  Future<_Repo> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _Repo();
    when(() => repo.saveGoals(any())).thenAnswer((_) async {});
    when(repo.goals).thenAnswer(
      (_) async => const GoalsSummary(goals: [], alerts: [], month: '2026-10'),
    );
    when(() => repo.insights(any())).thenAnswer((_) async => []);
    final cubit = DashboardCubit(repo);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: SpooliqTheme.light,
        home: BlocProvider.value(
          value: cubit,
          child: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
    return repo;
  }

  testWidgets('insights render with metric and the goals action', (
    tester,
  ) async {
    var opened = 0;
    await pump(
      tester,
      InsightsPanel(
        section: const Section.data([
          Insight(
            kind: 'goal_off_pace',
            severity: InsightSeverity.warning,
            title: 'Meta de lucro fora do ritmo',
            detail: 'No ritmo atual o mês fecha em 60%.',
            metric: '20,0%',
            action: InsightAction(label: 'Ver metas', target: 'goals'),
          ),
          Insight(
            kind: 'profit_growth',
            severity: InsightSeverity.positive,
            title: 'Lucro em alta',
            detail: 'Cresceu 25%.',
          ),
        ]),
        onOpenGoals: () => opened++,
      ),
    );

    expect(find.text('Meta de lucro fora do ritmo'), findsOneWidget);
    expect(find.text('20,0%'), findsOneWidget);
    expect(find.text('Lucro em alta'), findsOneWidget);
    await tester.tap(find.text('Ver metas'));
    expect(opened, 1);
  });

  testWidgets('no insights shows the all-clear message', (tester) async {
    await pump(
      tester,
      InsightsPanel(section: const Section.data([]), onOpenGoals: () {}),
    );
    expect(find.textContaining('Tudo em ordem'), findsOneWidget);
  });

  testWidgets('goals card shows progress, projection and pace', (
    tester,
  ) async {
    await pump(
      tester,
      GoalsCard(
        section: const Section.data(
          GoalsSummary(goals: [_offPace], alerts: [], month: '2026-10'),
        ),
        canManage: true,
        onEdit: () {},
      ),
    );
    expect(find.text('Metas de outubro'), findsOneWidget);
    expect(find.text('Lucro'), findsOneWidget);
    expect(find.textContaining('10 dias restantes'), findsOneWidget);
  });

  testWidgets('users without permission cannot define goals', (tester) async {
    await pump(
      tester,
      GoalsCard(
        section: const Section.data(
          GoalsSummary(goals: [], alerts: [], month: '2026-10'),
        ),
        canManage: false,
        onEdit: () {},
      ),
    );
    expect(find.text('Definir metas'), findsNothing);
    expect(find.textContaining('Peça a um administrador'), findsOneWidget);
  });

  testWidgets('the goals dialog saves targets in cents', (tester) async {
    final repo = await pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => openGoalsDialog(context),
          child: const Text('abrir'),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find
            .ancestor(
              of: find.text('Lucro'),
              matching: find.byType(Column),
            )
            .first,
        matching: find.byType(TextField),
      ),
      '5000',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    final saved =
        verify(() => repo.saveGoals(captureAny())).captured.single
            as Map<GoalMetric, double>;
    expect(saved[GoalMetric.profit], 500000);
    expect(saved[GoalMetric.revenue], 0);
  });
}
