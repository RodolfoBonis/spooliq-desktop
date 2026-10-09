import 'package:flutter_test/flutter_test.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_status.dart';

import '../../../helpers/fixtures.dart';

void main() {
  group('BudgetStatus', () {
    test('parses all 8 backend values (swagger lists only 6)', () {
      for (final s in BudgetStatus.values) {
        expect(BudgetStatus.fromValue(s.value), s);
      }
      expect(BudgetStatus.fromValue('unknown'), BudgetStatus.draft);
    });

    test('transitions mirror the backend matrix', () {
      expect(BudgetStatus.draft.allowedTransitions, {
        BudgetStatus.sent,
        BudgetStatus.cancelled,
      });
      expect(BudgetStatus.sent.allowedTransitions, {
        BudgetStatus.approved,
        BudgetStatus.rejected,
        BudgetStatus.expired,
        BudgetStatus.cancelled,
      });
      expect(BudgetStatus.approved.allowedTransitions, {
        BudgetStatus.printing,
        BudgetStatus.cancelled,
      });
      expect(BudgetStatus.printing.allowedTransitions, {
        BudgetStatus.completed,
      });
      expect(BudgetStatus.completed.allowedTransitions, isEmpty);
      for (final s in [
        BudgetStatus.rejected,
        BudgetStatus.expired,
        BudgetStatus.cancelled,
      ]) {
        expect(s.allowedTransitions, {BudgetStatus.draft});
      }
    });

    test('edit/delete/share rules', () {
      expect(BudgetStatus.draft.isEditable, isTrue);
      expect(BudgetStatus.sent.isEditable, isFalse);
      expect(BudgetStatus.printing.isDeletable, isFalse);
      expect(BudgetStatus.completed.isDeletable, isFalse);
      expect(BudgetStatus.cancelled.isShareable, isFalse);
      expect(BudgetStatus.expired.isShareable, isTrue);
    });
  });

  group('Budget.fromJson', () {
    final b = Budget.fromJson(budgetJson());

    test('reads identity, customer and refs', () {
      expect(b.id, 'b-1');
      expect(b.quoteNumber, 42);
      expect(b.status, BudgetStatus.draft);
      expect(b.customerName, 'Ana Souza');
      expect(b.profile?.name, 'Bambu P1S');
      expect(b.costPreset, isNull);
      expect(b.validUntil, isNotNull);
      expect(b.isShared, isFalse);
    });

    test('reads money in cents and cost lines', () {
      expect(b.totalCents, 25990);
      expect(b.costs.filament, 8000);
      expect(b.costs.direct, 8000 + 300 + 450 + 600 + 500 + 2000 + 200 + 150);
      expect(b.discountType, DiscountType.percent);
      expect(b.discountValue, 10);
      expect(b.taxRate, isNull);
      expect(b.taxRateApplied, 6);
    });

    test('sorts item filaments by AMS order', () {
      final item = b.items.single;
      expect(item.filaments.map((f) => f.color), ['Preto', 'Branco']);
      expect(item.totalGrams, 420.5);
      expect(item.saleTotalCents, 25990);
    });

    test('reads history and stock warnings', () {
      expect(b.statusHistory.single.to, BudgetStatus.sent);
      expect(b.stockWarnings.single.requiredGrams, 600);
    });

    test('current items are not legacy', () {
      expect(b.usesLegacyCalculation, isFalse);
    });

    for (final missing in [
      'setup_time_minutes',
      'manual_labor_minutes_total',
    ]) {
      test('items without $missing use the old calculation', () {
        final json = budgetJson();
        final item = Map<String, dynamic>.of(
          (json['items']! as List).single as Map<String, dynamic>,
        )..remove(missing);
        final legacy = Budget.fromJson({
          ...json,
          'items': [item],
        });
        expect(legacy.items.single.isLegacy, isTrue);
        expect(legacy.usesLegacyCalculation, isTrue);
      });
    }

    test('copyWithStatus keeps everything else', () {
      final moved = b.copyWithStatus(BudgetStatus.sent);
      expect(moved.status, BudgetStatus.sent);
      expect(moved.totalCents, b.totalCents);
      expect(moved.items, b.items);
    });
  });
}
