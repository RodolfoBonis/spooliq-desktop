import 'package:flutter_test/flutter_test.dart';
import 'package:spooliq_desktop/features/dashboard/presentation/dashboard_cubit.dart';

void main() {
  test('export waits until every section has loaded', () {
    const loading = DashboardState();
    expect(loading.anyLoading, isTrue);

    const failed = Section<Never>.error('x');
    final done = loading.copyWith(
      overview: const Section.error('x'),
      trend: const Section.data([]),
      funnel: const Section.data([]),
      customers: const Section.data([]),
      filaments: const Section.data([]),
      materials: const Section.data([]),
      goals: const Section.data((<Never>[], <Never>[])),
      insights: const Section.error('x'),
      lowStock: const Section.data([]),
      activity: const Section.data([]),
    );
    expect(failed.loading, isFalse);
    expect(done.anyLoading, isFalse);
  });
}
