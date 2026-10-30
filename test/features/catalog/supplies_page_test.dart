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
import 'package:spooliq_desktop/features/catalog/presentation/supplies_page.dart';

class _Catalog extends Mock implements CatalogRepository {}

class _Session extends Mock implements SessionCubit {}

Paginated<Supply> _page(List<Supply> items) => Paginated(
  items: items,
  total: items.length,
  page: 1,
  pageSize: 100,
  totalPages: 1,
);

void main() {
  late _Catalog catalog;

  setUpAll(() {
    registerFallbackValue(const PageQuery());
    registerFallbackValue(SupplyUnit.un);
  });

  setUp(() {
    catalog = _Catalog();
    di
      ..allowReassignment = true
      ..registerSingleton<CatalogRepository>(catalog);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = _Session();
    when(() => session.state).thenReturn(
      const SessionState.authenticated(
        SessionUser(
          id: 'u',
          email: 'a@b.c',
          name: 'Ana',
          organizationId: 'o',
          roles: {Role.owner},
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
          child: const Scaffold(body: SuppliesPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets(r'create dialog converts R$ to cents', (tester) async {
    when(
      () => catalog.supplies(page: any(named: 'page')),
    ).thenAnswer((_) async => _page(const []));
    when(
      () => catalog.saveSupply(
        name: any(named: 'name'),
        unit: any(named: 'unit'),
        unitCostCents: any(named: 'unitCostCents'),
        description: any(named: 'description'),
        isActive: any(named: 'isActive'),
      ),
    ).thenAnswer(
      (_) async => const Supply(
        id: 's-new',
        name: 'LED 5mm',
        unit: SupplyUnit.un,
        unitCostCents: 1250,
      ),
    );

    await pump(tester);
    expect(find.text('Nenhum insumo cadastrado'), findsOneWidget);

    await tester.tap(find.text('Novo insumo'));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(
      find
          .descendant(
            of: find.byType(FormaDialog),
            matching: find.byType(TextFormField),
          )
          .first,
      'LED 5mm',
    );
    await tester.enterText(
      find.descendant(
        of: find.byType(FormaNumberField),
        matching: find.byType(TextField),
      ),
      '12,50',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pump(const Duration(milliseconds: 400));

    verify(
      () => catalog.saveSupply(
        name: 'LED 5mm',
        unit: SupplyUnit.un,
        unitCostCents: 1250,
        description: any(named: 'description'),
        isActive: any(named: 'isActive'),
      ),
    ).called(1);
    expect(find.text('LED 5mm'), findsOneWidget);
    // Drena o toast pendente para não vazar timers.
    await tester.pump(const Duration(seconds: 5));
  });
}
