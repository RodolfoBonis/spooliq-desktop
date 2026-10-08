import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forma_theme_spooliq/forma_theme_spooliq.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spooliq_desktop/core/auth/session_user.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/features/auth/presentation/session_cubit.dart';
import 'package:spooliq_desktop/features/catalog/domain/catalog.dart';
import 'package:spooliq_desktop/features/catalog/domain/catalog_repository.dart';
import 'package:spooliq_desktop/features/catalog/presentation/brands_page.dart';

class _Catalog extends Mock implements CatalogRepository {}

class _Session extends Mock implements SessionCubit {}

Paginated<Brand> _page(List<Brand> items) => Paginated(
  items: items,
  total: items.length,
  page: 1,
  pageSize: 100,
  totalPages: 1,
);

void main() {
  late _Catalog catalog;

  setUpAll(() => registerFallbackValue(const PageQuery()));

  setUp(() {
    catalog = _Catalog();
    di
      ..allowReassignment = true
      ..registerSingleton<CatalogRepository>(catalog);
  });

  Future<void> pump(
    WidgetTester tester, {
    Set<Role> roles = const {Role.owner},
  }) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = _Session();
    when(() => session.state).thenReturn(
      SessionState.authenticated(
        SessionUser(
          id: 'u',
          email: 'a@b.c',
          name: 'Ana',
          organizationId: 'o',
          roles: roles,
          expiresAt: null,
        ),
      ),
    );
    when(() => session.stream).thenAnswer((_) => const Stream.empty());
    await tester.pumpWidget(
      MaterialApp(
        theme: SpooliqTheme.light,
        home: BlocProvider<SessionCubit>.value(
          value: session,
          child: const Scaffold(body: BrandsPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('lists brands and creates a new one', (tester) async {
    when(() => catalog.brands(page: any(named: 'page'))).thenAnswer(
      (_) async => _page(const [Brand(id: 'b1', name: 'Voolt 3D')]),
    );
    when(
      () => catalog.saveBrand(
        name: any(named: 'name'),
        description: any(named: 'description'),
      ),
    ).thenAnswer((_) async => const Brand(id: 'b2', name: 'Bambu Lab'));

    await pump(tester);
    expect(find.text('Voolt 3D'), findsOneWidget);

    await tester.tap(find.text('Nova marca'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(
      find
          .descendant(
            of: find.byType(FormaDialog),
            matching: find.byType(TextFormField),
          )
          .first,
      'Bambu Lab',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pump(const Duration(milliseconds: 400));

    verify(
      () => catalog.saveBrand(
        name: 'Bambu Lab',
        description: any(named: 'description'),
      ),
    ).called(1);
    expect(find.text('Bambu Lab'), findsOneWidget);
    // Fecha o toast pendente para não vazar timers.
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('shows the empty state and hides actions for regular users', (
    tester,
  ) async {
    when(
      () => catalog.brands(page: any(named: 'page')),
    ).thenAnswer((_) async => _page(const []));

    await pump(tester, roles: const {Role.user});
    expect(find.text('Nenhuma marca cadastrada'), findsOneWidget);
    expect(find.text('Nova marca'), findsNothing);
  });
}
