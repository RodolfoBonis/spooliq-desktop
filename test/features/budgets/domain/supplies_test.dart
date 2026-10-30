import 'package:flutter_test/flutter_test.dart';
import 'package:spooliq_desktop/core/network/json.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_draft.dart';
import 'package:spooliq_desktop/features/catalog/domain/catalog.dart';

/// Item com insumos, no formato de `GET /budgets/{id}`.
Json _itemJson({bool legacySupply = false}) => {
  'id': 'i-1',
  'product_name': 'Luminária',
  'product_quantity': 4,
  'print_time_hours': 2,
  'print_time_minutes': 0,
  'print_time_display': '2h',
  'setup_time_minutes': 10,
  'manual_labor_minutes_total': 20,
  'filament_cost': 8000,
  'supplies_cost': 1200,
  'item_total_cost': 12000,
  'unit_price': 3000,
  'sale_unit_price': 6000,
  'sale_total': 24000,
  'order': 1,
  'filaments': [
    {
      'filament_id': 'f-1',
      'filament_name': 'PLA',
      'color': 'Preto',
      'quantity': 100,
      'cost': 8000,
      'order': 1,
    },
  ],
  'supplies': [
    {
      'supply_id': 's-1',
      'name': 'LED 5mm',
      'unit': 'un',
      'unit_cost': 150,
      if (!legacySupply) 'package_size': 100,
      if (!legacySupply) 'package_price': 15000,
      'quantity_per_piece': 2,
      'total': 1200,
    },
  ],
};

void main() {
  group('BudgetItem.fromJson supplies', () {
    final item = BudgetItem.fromJson(_itemJson());

    test('parses the supplies list with package fields', () {
      expect(item.supplies, hasLength(1));
      final s = item.supplies.single;
      expect(s.supplyId, 's-1');
      expect(s.name, 'LED 5mm');
      expect(s.unit, 'un');
      expect(s.unitCostCents, 150);
      expect(s.packageSize, 100);
      expect(s.packagePriceCents, 15000);
      expect(s.quantityPerPiece, 2);
      expect(s.totalCents, 1200);
    });

    test('falls back to package size 1 / price = unit_cost when missing', () {
      final legacy = BudgetItem.fromJson(_itemJson(legacySupply: true));
      final s = legacy.supplies.single;
      expect(s.packageSize, 1, reason: 'legacy supplies are per unit');
      expect(s.packagePriceCents, 150, reason: 'price = legacy unit_cost');
    });

    test('supplies_cost feeds CostLines.supplies and is part of direct', () {
      expect(item.costs.supplies, 1200);
      expect(item.costs.direct, 8000 + 1200);
    });
  });

  group('Supply.fromJson package pricing', () {
    test('reads package_size / package_price and derives cost per unit', () {
      final s = Supply.fromJson(const <String, dynamic>{
        'id': 's-1',
        'name': 'Loção',
        'unit': 'ml',
        'unit_cost': 17,
        'package_size': 400,
        'package_price': 6990,
      });
      expect(s.packageSize, 400);
      expect(s.packagePriceCents, 6990);
      // 6990 / 400 = 17,475 centavos por ml.
      expect(s.costPerUnit, closeTo(17.475, 1e-9));
    });

    test('legacy supply without package fields falls back to unit 1', () {
      final s = Supply.fromJson(const <String, dynamic>{
        'id': 's-2',
        'name': 'LED 5mm',
        'unit': 'un',
        'unit_cost': 150,
      });
      expect(s.packageSize, 1);
      expect(s.packagePriceCents, 150);
      expect(s.costPerUnit, 150);
    });

    test('guards against a zero package size', () {
      final s = Supply.fromJson(const <String, dynamic>{
        'id': 's-3',
        'name': 'X',
        'unit': 'un',
        'unit_cost': 100,
        'package_size': 0,
        'package_price': 500,
      });
      expect(s.packageSize, 1);
      expect(s.costPerUnit, 500);
    });
  });

  group('supplyLineCostCents', () {
    test(r'rounds once: 10 ml x 10 pecas de embalagem 400 / R$ 69,90', () {
      // 10 * 10 * 6990 / 400 = 1747,5 → 1748.
      expect(
        supplyLineCostCents(
          quantityPerPiece: 10,
          productQuantity: 10,
          packagePriceCents: 6990,
          packageSize: 400,
        ),
        1748,
      );
    });

    test(r'LED 2 x 10 pecas de uma caixa de 100 un / R$ 50,00 = R$ 10,00', () {
      // 2 * 10 * 5000 / 100 = 1000 (50 centavos por unidade).
      expect(
        supplyLineCostCents(
          quantityPerPiece: 2,
          productQuantity: 10,
          packagePriceCents: 5000,
          packageSize: 100,
        ),
        1000,
      );
    });

    test('legacy per-unit supply (package size 1)', () {
      // 2 por peça × 4 peças × 150 / 1 = 1200.
      expect(
        supplyLineCostCents(
          quantityPerPiece: 2,
          productQuantity: 4,
          packagePriceCents: 150,
          packageSize: 1,
        ),
        1200,
      );
    });

    test('zero package size yields zero (never divides by zero)', () {
      expect(
        supplyLineCostCents(
          quantityPerPiece: 5,
          productQuantity: 2,
          packagePriceCents: 1000,
          packageSize: 0,
        ),
        0,
      );
    });
  });

  group('BudgetItemDraft supplies', () {
    test('fromItem maps supplies with package fields and no scaling', () {
      final draft = BudgetItemDraft.fromItem(
        BudgetItem.fromJson(_itemJson()),
        0,
      );
      expect(draft.supplies, hasLength(1));
      final s = draft.supplies.single;
      expect(s.supplyId, 's-1');
      expect(s.quantityPerPiece, 2, reason: 'per piece, never scaled');
      expect(s.label, 'LED 5mm');
      expect(s.unit, 'un');
      expect(s.unitCostCents, 150);
      expect(s.packageSize, 100);
      expect(s.packagePriceCents, 15000);
    });

    test('toJson always includes supplies (empty list clears them)', () {
      const empty = BudgetItemDraft(
        key: 0,
        productName: 'X',
        filaments: [FilamentUsageDraft(filamentId: 'f-1', grams: 10)],
      );
      final json = empty.toJson(1);
      expect(json.containsKey('supplies'), isTrue);
      expect(json['supplies'], isEmpty);
    });

    test('toJson drops incomplete supply rows but keeps valid ones', () {
      const draft = BudgetItemDraft(
        key: 0,
        productName: 'X',
        filaments: [FilamentUsageDraft(filamentId: 'f-1', grams: 10)],
        supplies: [
          SupplyUsageDraft(supplyId: 's-1', quantityPerPiece: 2),
          SupplyUsageDraft(supplyId: '', quantityPerPiece: 5),
          SupplyUsageDraft(supplyId: 's-2', quantityPerPiece: 0),
        ],
      );
      expect(draft.toJson(1)['supplies'], [
        {'supply_id': 's-1', 'quantity_per_piece': 2.0},
      ]);
    });

    test('supplies are NOT scaled by PrintBatch (per piece)', () {
      // 40 pieces from a file that prints 10 => filaments scale 4x, supplies do
      // not: quantity_per_piece stays as entered.
      const draft = BudgetItemDraft(
        key: 0,
        productName: 'X',
        quantity: 40,
        unitsPerPrint: 10,
        filaments: [FilamentUsageDraft(filamentId: 'f-1', grams: 10)],
        supplies: [SupplyUsageDraft(supplyId: 's-1', quantityPerPiece: 2)],
      );
      final json = draft.toJson(1);
      // Filament grams scale (10 * 40/10 = 40), supplies do not.
      expect(((json['filaments'] as List).single as Map)['quantity'], 40.0);
      expect(json['supplies'], [
        {'supply_id': 's-1', 'quantity_per_piece': 2.0},
      ]);
    });
  });

  test('a chosen supply without quantity blocks saving', () {
    const draft = BudgetDraft(
      name: 'Kit',
      customerId: 'c1',
      items: [
        BudgetItemDraft(
          key: 0,
          productName: 'Luminária',
          filaments: [FilamentUsageDraft(filamentId: 'f1', grams: 10)],
          supplies: [
            SupplyUsageDraft(
              supplyId: 's1',
              quantityPerPiece: 0,
              label: 'LED',
              unit: 'un',
              unitCostCents: 50,
            ),
          ],
        ),
      ],
    );
    expect(
      draft.validate()['item.0.supplies'],
      'Informe a quantidade por peça de cada insumo.',
    );
    final ok = draft.copyWith(
      items: [
        draft.items.single.copyWith(
          supplies: [
            draft.items.single.supplies.single.copyWith(quantityPerPiece: 1),
          ],
        ),
      ],
    );
    expect(ok.validate().containsKey('item.0.supplies'), isFalse);
  });
}
