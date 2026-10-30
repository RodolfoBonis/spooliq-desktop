import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forma_theme_spooliq/forma_theme_spooliq.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/format/formatters.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_draft.dart';
import 'package:spooliq_desktop/features/budgets/presentation/editor/item_editor.dart';
import 'package:spooliq_desktop/features/catalog/domain/catalog.dart';
import 'package:spooliq_desktop/features/catalog/domain/catalog_repository.dart';

class _Catalog extends Mock implements CatalogRepository {}

void main() {
  setUpAll(() => registerFallbackValue(const PageQuery()));

  setUp(() {
    final catalog = _Catalog();
    when(
      () => catalog.supplies(page: any(named: 'page')),
    ).thenAnswer((_) async => const Paginated<Supply>.empty());
    di
      ..allowReassignment = true
      ..registerSingleton<CatalogRepository>(catalog);
  });

  testWidgets('Insumos section shows subtotal and supports add/remove', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var item = const BudgetItemDraft(
      key: 0,
      productName: 'Luminária',
      quantity: 3,
      filaments: [FilamentUsageDraft(filamentId: 'f-1', grams: 10)],
      supplies: [
        SupplyUsageDraft(
          supplyId: 's-1',
          quantityPerPiece: 2,
          label: 'LED 5mm',
          unit: 'un',
          unitCostCents: 500,
          packagePriceCents: 500,
        ),
      ],
    );

    Widget build() => MaterialApp(
      theme: SpooliqTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: ItemEditor(
            index: 0,
            item: item,
            costPresets: const [],
            onChanged: (change) => item = change(item),
            onRemove: null,
            onDuplicate: () {},
          ),
        ),
      ),
    );

    await tester.pumpWidget(build());
    await tester.pump();

    expect(find.text('Insumos'), findsOneWidget);
    // Sufixo da unidade por peça na coluna de quantidade.
    expect(find.textContaining('un/peça'), findsOneWidget);
    // Subtotal = 2 un/peça × 3 peças × R\$ 5,00 (embalagem 500/1) = R\$ 30,00.
    expect(find.textContaining('2 un × 3 peças = 6 un'), findsOneWidget);
    expect(find.textContaining(Fmt.cents(3000)), findsOneWidget);

    // Adiciona uma linha vazia de insumo.
    await tester.tap(find.text('Adicionar insumo'));
    expect(item.supplies, hasLength(2));

    await tester.pumpWidget(build());
    await tester.pump();

    // Remove a primeira linha.
    await tester.tap(find.byTooltip('Remover insumo').first);
    expect(item.supplies, hasLength(1));
  });
}
