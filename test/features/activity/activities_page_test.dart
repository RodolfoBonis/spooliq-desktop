import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forma_theme_spooliq/forma_theme_spooliq.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/network/api_client.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/features/activity/data/api_activity_repository.dart';
import 'package:spooliq_desktop/features/activity/domain/activity_repository.dart';
import 'package:spooliq_desktop/features/activity/presentation/activities_page.dart';
import 'package:spooliq_desktop/features/dashboard/domain/dashboard.dart';

class _Repo extends Mock implements ActivityRepository {}

class _Api extends Mock implements ApiClient {}

final _activity = Activity.fromJson(const {
  'id': 'a1',
  'action': 'approved',
  'entity_type': 'budget',
  'entity_id': 'b1',
  'entity_name': 'Vaso Voronoi',
  'description': 'aprovado pelo link público',
  'created_at': '2026-10-08T10:00:00Z',
});

void main() {
  late _Repo repo;

  setUpAll(() => registerFallbackValue(const PageQuery()));

  setUp(() {
    repo = _Repo();
    di
      ..allowReassignment = true
      ..registerSingleton<ActivityRepository>(repo);
    when(
      () => repo.list(
        page: any(named: 'page'),
        entity: any(named: 'entity'),
        action: any(named: 'action'),
      ),
    ).thenAnswer(
      (_) async => Paginated(
        items: [_activity],
        total: 1,
        page: 1,
        pageSize: 50,
        totalPages: 1,
      ),
    );
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: SpooliqTheme.light,
        home: const Scaffold(body: ActivitiesPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('lists activities with their detail', (tester) async {
    await pump(tester);
    expect(find.textContaining('aprovou orçamento'), findsOneWidget);
    expect(find.text('aprovado pelo link público'), findsOneWidget);
  });

  testWidgets('filters by area', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Todas as áreas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ActivityEntity.customer.label).last);
    await tester.pump(const Duration(milliseconds: 100));

    verify(
      () => repo.list(
        page: any(named: 'page'),
        entity: ActivityEntity.customer,
        action: any(named: 'action'),
      ),
    ).called(1);
  });

  test('repository sends only paging and the chosen filters', () async {
    final api = _Api();
    when(
      () => api.get(any(), query: any(named: 'query')),
    ).thenAnswer((_) async => {'data': <Object>[], 'total': 0});

    await ApiActivityRepository(api).list(
      page: const PageQuery(page: 2, search: 'ignored'),
      action: ActivityAction.approved,
    );

    verify(
      () => api.get(
        '/activities',
        query: {'page': 2, 'page_size': 20, 'action': 'approved'},
      ),
    ).called(1);
  });
}
