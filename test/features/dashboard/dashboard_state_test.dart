import 'package:flutter_test/flutter_test.dart';
import 'package:spooliq_desktop/features/dashboard/domain/dashboard.dart';
import 'package:spooliq_desktop/features/dashboard/presentation/dashboard_cubit.dart';

void main() {
  test('export waits until every section has loaded', () {
    const loading = DashboardState();
    expect(loading.anyLoading, isTrue);

    const failed = Section<Never>.error('x');
    final done = loading.copyWith(
      overview: const Section.error('x'),
      trend: const Section.data(<TrendPoint>[]),
      funnel: const Section.data(<FunnelStep>[]),
      materials: const Section.data(<RankedItem>[]),
      goals: const Section.data(
        GoalsSummary(goals: [], alerts: [], month: '2026-10'),
      ),
      operations: const Section.error('x'),
      profitability: const Section.error('x'),
      responseTimes: const Section.error('x'),
      insights: const Section.data(<Insight>[]),
      lowStock: const Section.data(<RankedItem>[]),
      activity: const Section.data(<Activity>[]),
    );
    expect(failed.loading, isFalse);
    expect(done.anyLoading, isFalse);
  });
}
