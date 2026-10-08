import 'package:flutter_test/flutter_test.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_draft.dart';

import '../../../helpers/fixtures.dart';

void main() {
  const item = BudgetItemDraft(
    key: 0,
    productName: ' Vaso ',
    quantity: 3,
    printHours: 2,
    printMinutes: 75,
    filaments: [
      FilamentUsageDraft(filamentId: 'f-1', grams: 100),
      FilamentUsageDraft(filamentId: '', grams: 50),
      FilamentUsageDraft(filamentId: 'f-2', grams: 25),
    ],
  );

  const draft = BudgetDraft(
    name: 'Vasos',
    customerId: 'c-1',
    discountType: DiscountType.fixed,
    discountValue: 15,
    includeShipping: true,
    shippingOverrideReais: 22.5,
    items: [item],
  );

  test('item JSON renumbers filaments and drops incomplete rows', () {
    final json = item.toJson(1);
    expect(json['product_name'], 'Vaso');
    expect(json['print_time_minutes'], 59);
    expect(json['filaments'], [
      {'filament_id': 'f-1', 'quantity': 100.0, 'order': 1},
      {'filament_id': 'f-2', 'quantity': 25.0, 'order': 2},
    ]);
    expect(json.containsKey('product_description'), isFalse);
  });

  test('create JSON converts shipping override to cents and omits nulls', () {
    final json = draft.toCreateJson();
    expect(json['shipping_override'], 2250);
    expect(json['discount_type'], 'fixed');
    expect(json['discount_value'], 15);
    expect(json.containsKey('tax_rate'), isFalse);
    expect(json.containsKey('valid_until'), isFalse);
  });

  test('update JSON sends clearable fields explicitly as null', () {
    final json = draft
        .copyWith(discountType: () => null, includeShipping: false)
        .toUpdateJson();
    expect(json.containsKey('tax_rate'), isTrue);
    expect(json['tax_rate'], isNull);
    expect(json['discount_type'], isNull);
    expect(json['discount_value'], isNull);
    expect(json['shipping_override'], isNull);
    expect(json['valid_until'], isNull);
  });

  test('preview JSON only includes complete items', () {
    final json = draft
        .copyWith(items: [item, const BudgetItemDraft(key: 1)])
        .toPreviewJson();
    expect((json['items'] as List).length, 1);
  });

  test('validate reports per-field errors', () {
    final errors = const BudgetDraft().validate();
    expect(
      errors.keys,
      containsAll(['name', 'customer', 'item.0.name', 'item.0.filaments']),
    );
    expect(draft.validate(), isEmpty);
  });

  test('fromBudget round-trips the editable fields', () {
    final d = BudgetDraft.fromBudget(Budget.fromJson(budgetJson()));
    expect(d.name, 'Kit organizadores');
    expect(d.customerName, 'Ana Souza');
    expect(d.discountType, DiscountType.percent);
    expect(d.items.single.filaments.first.filamentId, 'f-1');
    expect(d.items.single.filaments.first.label, 'PLA Basic · Preto');
  });
}
