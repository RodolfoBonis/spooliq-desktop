import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forma_theme_spooliq/forma_theme_spooliq.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget.dart';
import 'package:spooliq_desktop/features/budgets/presentation/widgets/cost_breakdown.dart';

import '../../../helpers/fixtures.dart';

void main() {
  Future<void> pumpSummary(WidgetTester tester, Budget budget) {
    return tester.pumpWidget(
      MaterialApp(
        theme: SpooliqTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(child: PriceSummary(budget: budget)),
        ),
      ),
    );
  }

  testWidgets('shows the payment fee line when the fee is embedded', (
    tester,
  ) async {
    await pumpSummary(
      tester,
      Budget.fromJson(
        budgetJson(paymentFeeRateApplied: 6.1, paymentFeeAmount: 1320),
      ),
    );
    expect(find.textContaining('Taxa de pagamento'), findsOneWidget);
    expect(find.textContaining('inclusa · 6,10%'), findsOneWidget);
  });

  testWidgets('hides the payment fee line when there is no embedded fee', (
    tester,
  ) async {
    await pumpSummary(tester, Budget.fromJson(budgetJson()));
    expect(find.textContaining('Taxa de pagamento'), findsNothing);
  });
}
