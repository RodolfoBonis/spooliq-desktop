import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forma_theme_spooliq/forma_theme_spooliq.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/features/catalog/domain/catalog.dart';
import 'package:spooliq_desktop/features/catalog/domain/catalog_repository.dart';
import 'package:spooliq_desktop/features/catalog/presentation/filament_stock_sheet.dart';

class _Catalog extends Mock implements CatalogRepository {}

final _filament = Filament.fromJson(const {
  'id': 'f1',
  'name': 'PLA Basic',
  'brand_id': 'b',
  'material_id': 'm',
  'color': 'Preto',
  'color_hex': '#000000',
  'color_type': 'solid',
  'diameter': 1.75,
  'weight': 1000,
  'price_per_kg': 11990,
  'track_stock': true,
  'stock_grams': 2000,
});

StockMovement _movement(String id, String type, double grams) =>
    StockMovement.fromJson({'id': id, 'type': type, 'grams': grams});

Paginated<StockMovement> _page(
  List<StockMovement> items, {
  int page = 1,
  int totalPages = 1,
}) => Paginated(
  items: items,
  total: items.length,
  page: page,
  pageSize: 50,
  totalPages: totalPages,
);

void main() {
  late _Catalog catalog;

  setUpAll(() => registerFallbackValue(StockMovementType.purchase));

  setUp(() {
    catalog = _Catalog();
    di
      ..allowReassignment = true
      ..registerSingleton<CatalogRepository>(catalog);
    when(() => catalog.filament('f1')).thenAnswer((_) async => _filament);
    when(
      () => catalog.stockMovements(
        'f1',
        page: any(named: 'page'),
        type: any(named: 'type'),
      ),
    ).thenAnswer(
      (_) async => _page(
        [_movement('s1', 'purchase', 1000)],
        totalPages: 2,
      ),
    );
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: SpooliqTheme.light,
        home: Scaffold(
          body: FilamentStockSheet(filament: _filament, onChanged: () {}),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder field(String label) => find.descendant(
    of: find.widgetWithText(FormaNumberField, label),
    matching: find.byType(TextField),
  );

  testWidgets('spools × spool weight fills the purchase grams', (
    tester,
  ) async {
    when(
      () => catalog.addStockMovement(
        'f1',
        type: any(named: 'type'),
        grams: any(named: 'grams'),
        unitPricePerKgCents: any(named: 'unitPricePerKgCents'),
        note: any(named: 'note'),
      ),
    ).thenAnswer((_) async => _movement('s2', 'purchase', 3000));

    await pump(tester);
    await tester.enterText(field('Carretéis'), '3');
    await tester.pump();
    await tester.tap(find.text('Registrar'));
    await tester.pump(const Duration(milliseconds: 100));

    verify(
      () => catalog.addStockMovement(
        'f1',
        type: StockMovementType.purchase,
        grams: 3000,
        unitPricePerKgCents: any(named: 'unitPricePerKgCents'),
        note: any(named: 'note'),
      ),
    ).called(1);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('loads more history pages', (tester) async {
    when(
      () => catalog.stockMovements(
        'f1',
        page: 2,
        type: any(named: 'type'),
      ),
    ).thenAnswer(
      (_) async => _page(
        [_movement('s0', 'waste', -50)],
        page: 2,
        totalPages: 2,
      ),
    );

    await pump(tester);
    expect(find.text('Carregar mais'), findsOneWidget);

    await tester.tap(find.text('Carregar mais'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(StockMovementType.waste.label), findsWidgets);
    expect(find.text('Carregar mais'), findsNothing);
  });

  testWidgets('filters the history by movement type', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Todos os tipos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(StockMovementType.waste.label).last);
    await tester.pump(const Duration(milliseconds: 100));

    verify(
      () => catalog.stockMovements(
        'f1',
        page: any(named: 'page'),
        type: StockMovementType.waste,
      ),
    ).called(1);
  });
}
