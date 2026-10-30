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

  Finder numberField(int index) => find.descendant(
    of: find.byType(FormaNumberField).at(index),
    matching: find.byType(TextField),
  );

  testWidgets(
    'create dialog converts price to cents and shows per-unit cost',
    (
      tester,
    ) async {
      when(
        () => catalog.supplies(page: any(named: 'page')),
      ).thenAnswer((_) async => _page(const []));
      when(
        () => catalog.saveSupply(
          name: any(named: 'name'),
          unit: any(named: 'unit'),
          packageSize: any(named: 'packageSize'),
          packagePriceCents: any(named: 'packagePriceCents'),
          description: any(named: 'description'),
          isActive: any(named: 'isActive'),
        ),
      ).thenAnswer(
        (_) async => const Supply(
          id: 's-new',
          name: 'Loção',
          unit: SupplyUnit.un,
          unitCostCents: 17,
          packageSize: 400,
          packagePriceCents: 6990,
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
        'Loção',
      );
      // Conteúdo da embalagem (primeiro número) e preço (segundo número).
      await tester.enterText(numberField(0), '400');
      await tester.enterText(numberField(1), '69,90');
      await tester.pump();

      // Custo por unidade derivado: 6990 / 400 = R$ 0,1748.
      expect(find.textContaining(r'R$ 0,1748'), findsOneWidget);

      await tester.tap(find.text('Salvar'));
      await tester.pump(const Duration(milliseconds: 400));

      verify(
        () => catalog.saveSupply(
          name: 'Loção',
          unit: SupplyUnit.un,
          packageSize: 400,
          packagePriceCents: 6990,
          description: any(named: 'description'),
          isActive: any(named: 'isActive'),
        ),
      ).called(1);
      expect(find.text('Loção'), findsWidgets);
      // Drena o toast pendente para não vazar timers.
      await tester.pump(const Duration(seconds: 5));
    },
  );

  testWidgets('an empty package size is rejected before saving', (
    tester,
  ) async {
    when(
      () => catalog.supplies(page: any(named: 'page')),
    ).thenAnswer((_) async => _page(const []));

    await pump(tester);
    await tester.tap(find.text('Novo insumo'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(
      find
          .descendant(
            of: find.byType(FormaDialog),
            matching: find.byType(TextFormField),
          )
          .first,
      'Loção',
    );
    await tester.enterText(numberField(1), '69,90');
    await tester.tap(find.text('Salvar'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.textContaining('Informe o conteúdo da embalagem'),
      findsOneWidget,
    );
    verifyNever(
      () => catalog.saveSupply(
        id: any(named: 'id'),
        name: any(named: 'name'),
        unit: any(named: 'unit'),
        packageSize: any(named: 'packageSize'),
        packagePriceCents: any(named: 'packagePriceCents'),
        description: any(named: 'description'),
        isActive: any(named: 'isActive'),
      ),
    );
  });

  testWidgets('edit dialog warns when package size changes', (tester) async {
    when(() => catalog.supplies(page: any(named: 'page'))).thenAnswer(
      (_) async => _page(const [
        Supply(
          id: 's-1',
          name: 'Loção',
          unit: SupplyUnit.ml,
          unitCostCents: 17,
          packageSize: 400,
          packagePriceCents: 6990,
        ),
      ]),
    );

    await pump(tester);
    // Abre o diálogo de edição tocando na linha do insumo.
    await tester.tap(find.text('Loção').first);
    await tester.pump(const Duration(milliseconds: 400));

    // Custo por unidade já aparece ao abrir (dentro do diálogo).
    expect(
      find.descendant(
        of: find.byType(FormaDialog),
        matching: find.textContaining(r'R$ 0,1748'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('passam a interpretar'), findsNothing);

    // Altera o conteúdo da embalagem → dispara o aviso de recálculo.
    await tester.enterText(numberField(0), '500');
    await tester.pump();

    expect(find.textContaining('passam a interpretar'), findsOneWidget);
  });
}
