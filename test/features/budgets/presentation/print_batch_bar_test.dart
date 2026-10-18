import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forma_theme_spooliq/forma_theme_spooliq.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_draft.dart';
import 'package:spooliq_desktop/features/budgets/presentation/editor/print_batch_bar.dart';

void main() {
  Future<BudgetItemDraft Function()> pump(
    WidgetTester tester,
    BudgetItemDraft item,
  ) async {
    var current = item;
    await tester.pumpWidget(
      MaterialApp(
        theme: SpooliqTheme.light,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => PrintBatchBar(
              item: current,
              onChanged: (f) => setState(() => current = f(current)),
            ),
          ),
        ),
      ),
    );
    return () => current;
  }

  testWidgets('shows the batch summary and can go back to totals', (
    tester,
  ) async {
    final get = await pump(
      tester,
      const BudgetItemDraft(key: 0, quantity: 25, unitsPerPrint: 10),
    );
    expect(
      find.text('25 peças = 2,5 impressões · setup cobrado 3×'),
      findsOneWidget,
    );
    await tester.tap(find.text('Usar valores totais'));
    await tester.pump();
    expect(get().unitsPerPrint, isNull);
    expect(get().setupMinutes, 0);
    expect(find.textContaining('Definir peças por impressão'), findsOneWidget);
  });

  testWidgets('going back to totals converts per-print values', (
    tester,
  ) async {
    final get = await pump(
      tester,
      const BudgetItemDraft(
        key: 0,
        quantity: 25,
        unitsPerPrint: 10,
        printHours: 3,
        printMinutes: 25,
        setupMinutes: 15,
      ),
    );
    await tester.tap(find.text('Usar valores totais'));
    await tester.pump();
    expect(get().printHours * 60 + get().printMinutes, 513);
    expect(get().setupMinutes, 45);
  });

  testWidgets('clearing the pieces field keeps the previous value', (
    tester,
  ) async {
    final get = await pump(
      tester,
      const BudgetItemDraft(key: 0, quantity: 25, unitsPerPrint: 10),
    );
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump();
    expect(get().unitsPerPrint, 10);
  });

  testWidgets('defining pieces keeps the current totals', (tester) async {
    final get = await pump(tester, const BudgetItemDraft(key: 0, quantity: 4));
    await tester.tap(find.textContaining('Definir peças por impressão'));
    await tester.pump();
    expect(get().unitsPerPrint, 4, reason: 'factor 1: totals unchanged');
    expect(find.textContaining('4 peças = 1 impressão'), findsOneWidget);
  });
}
