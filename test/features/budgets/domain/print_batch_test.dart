import 'package:flutter_test/flutter_test.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_draft.dart';
import 'package:spooliq_desktop/features/budgets/domain/print_batch.dart';
import 'package:spooliq_desktop/features/budgets/presentation/editor/print_batch_bar.dart';
import 'package:spooliq_desktop/features/models3d/domain/model3d.dart';

/// O potinho: 1 impressão (2 mesas) = 10 conjuntos, 3h25, 78,7 g + 3,5 g.
const _perRun = BudgetItemDraft(
  key: 0,
  productName: 'Potinho',
  quantity: 10,
  unitsPerPrint: 10,
  printHours: 3,
  printMinutes: 25,
  setupMinutes: 15,
  laborMinutes: 20,
  postProcessingMinutes: 30,
  filaments: [
    FilamentUsageDraft(filamentId: 'branco', grams: 78.7),
    FilamentUsageDraft(filamentId: 'rosa', grams: 3.5),
  ],
);

void main() {
  group('PrintBatch', () {
    test('proportional material/time and setup per run', () {
      const b = PrintBatch(quantity: 25, unitsPerPrint: 10);
      expect(b.factor, 2.5);
      expect(b.runs, 3);
      expect(b.scaleMinutes(205), 513); // 205 × 2,5 = 512,5
      expect(b.scaleGrams(78.7), 196.8);
      expect(b.scaleSetup(15), 45);
    });

    test('same quantity as the file changes nothing', () {
      const b = PrintBatch(quantity: 10, unitsPerPrint: 10);
      expect(b.factor, 1);
      expect(b.runs, 1);
      expect(b.scaleMinutes(205), 205);
      expect(b.scaleGrams(3.5), 3.5);
    });

    test('summary reads in pt-BR', () {
      expect(
        printBatchSummary(const PrintBatch(quantity: 25, unitsPerPrint: 10)),
        '25 peças = 2,5 impressões · setup cobrado 3×',
      );
      expect(
        printBatchSummary(const PrintBatch(quantity: 10, unitsPerPrint: 10)),
        '10 peças = 1 impressão · setup cobrado 1×',
      );
    });
  });

  group('BudgetItemDraft with units per print', () {
    test('sends totals scaled to the quantity', () {
      final j = _perRun.copyWith(quantity: 25).toJson(1);
      expect(j['product_quantity'], 25);
      expect(j['units_per_print'], 10);
      // 3h25 = 205 min × 2,5 = 513 min = 8h33.
      expect(j['print_time_hours'], 8);
      expect(j['print_time_minutes'], 33);
      expect(j['setup_time_minutes'], 45);
      expect(j['manual_labor_minutes_total'], 50);
      expect(j['post_processing_minutes'], 75);
      final fils = (j['filaments'] as List).cast<Map<String, dynamic>>();
      expect(fils.map((f) => f['quantity']), [196.8, 8.8]);
    });

    test('without units per print values are sent as totals', () {
      final j = _perRun.copyWith(unitsPerPrint: () => null).toJson(1);
      expect(j.containsKey('units_per_print'), isFalse);
      expect(j['print_time_hours'], 3);
      expect(j['setup_time_minutes'], 15);
    });

    test('a saved item comes back as one run', () {
      for (final quantity in [10, 20, 25, 40]) {
        final sent = _perRun.copyWith(quantity: quantity).toJson(1);
        final item = BudgetItem.fromJson({
          ...sent,
          'id': 'i1',
          'filaments': [
            for (final f
                in (sent['filaments'] as List).cast<Map<String, dynamic>>())
              {'filament_id': f['filament_id'], 'quantity': f['quantity']},
          ],
        });
        final back = BudgetItemDraft.fromItem(item, 0);
        expect(back.unitsPerPrint, 10, reason: 'q=$quantity');
        expect(
          back.printHours * 60 + back.printMinutes,
          205,
          reason: 'q=$quantity',
        );
        expect(back.setupMinutes, 15, reason: 'q=$quantity');
        expect(back.laborMinutes, 20, reason: 'q=$quantity');
        expect(back.filaments.map((f) => f.grams), [
          78.7,
          3.5,
        ], reason: 'q=$quantity');
      }
    });
  });

  group('piecesPerPrint', () {
    SlicePlate plate(int index, List<SliceObject> objects) => SlicePlate(
      index: index,
      name: '',
      printSeconds: 0,
      estimated: false,
      filaments: const [],
      objects: objects,
    );

    test('sets across plates use the GCD of copies per object', () {
      expect(
        piecesPerPrint([
          plate(1, const [
            SliceObject(name: 'pote', count: 10),
            SliceObject(name: 'tampa', count: 10),
          ]),
          plate(2, const [SliceObject(name: 'laco', count: 10)]),
        ]),
        10,
      );
    });

    test('unique objects make one piece; no objects is unknown', () {
      expect(
        piecesPerPrint([
          plate(1, const [
            SliceObject(name: 'a', count: 1),
            SliceObject(name: 'b', count: 1),
          ]),
        ]),
        1,
      );
      expect(piecesPerPrint([plate(1, const [])]), isNull);
    });

    test('uneven sets fall back to the common divisor', () {
      expect(
        piecesPerPrint([
          plate(1, const [
            SliceObject(name: 'pote', count: 10),
            SliceObject(name: 'laco', count: 5),
          ]),
        ]),
        5,
      );
    });

    test('plates parse objects from the analysis', () {
      final p = SlicePlate.fromJson(const {
        'index': 1,
        'objects': [
          {'name': 'pote', 'count': 10},
        ],
      });
      expect(p.objects.single, const SliceObject(name: 'pote', count: 10));
      expect(SlicePlate.fromJson(const {'index': 1}).objects, isEmpty);
    });
  });
}
