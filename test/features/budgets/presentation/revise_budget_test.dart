import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forma_theme_spooliq/forma_theme_spooliq.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_status.dart';
import 'package:spooliq_desktop/features/budgets/presentation/budget_actions.dart';

import '../../../helpers/fixtures.dart';

void main() {
  Future<TransitionDecision? Function()> pump(
    WidgetTester tester,
    Budget budget,
  ) async {
    TransitionDecision? result;
    var done = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: SpooliqTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await confirmTransition(
                  context,
                  budget,
                  BudgetStatus.draft,
                );
                done = true;
              },
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    return () {
      expect(done, isTrue);
      return result;
    };
  }

  testWidgets('revising a sent budget records what the customer asked', (
    tester,
  ) async {
    final result = await pump(
      tester,
      Budget.fromJson(budgetJson(status: 'sent')),
    );
    await tester.pump();
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('Revisar orçamento'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'tirar o chaveiro');
    await tester.tap(find.text('Revisar'));
    await tester.pumpAndSettle();

    expect(
      result()!.notes,
      'Revisão solicitada pelo cliente: tirar o chaveiro',
    );
  });

  testWidgets('without a note the revision still explains itself', (
    tester,
  ) async {
    final result = await pump(
      tester,
      Budget.fromJson(budgetJson(status: 'sent')),
    );
    await tester.pump();
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revisar'));
    await tester.pumpAndSettle();

    expect(result()!.notes, 'Revisão solicitada pelo cliente');
  });

  testWidgets('back to draft from cancelled needs no dialog', (tester) async {
    final result = await pump(
      tester,
      Budget.fromJson(budgetJson(status: 'cancelled')),
    );
    await tester.pump();
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Revisar orçamento'), findsNothing);
    expect(result()!.notes, isNull);
  });
}
