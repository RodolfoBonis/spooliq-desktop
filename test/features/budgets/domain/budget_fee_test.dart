import 'package:flutter_test/flutter_test.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_status.dart';

import '../../../helpers/fixtures.dart';

void main() {
  group('Budget payment fee', () {
    test('defaults to zero when the fee fields are absent', () {
      final b = Budget.fromJson(budgetJson());
      expect(b.paymentFeeRateApplied, 0);
      expect(b.paymentFeeAmountCents, 0);
      expect(b.hasEmbeddedPaymentFee, isFalse);
    });

    test('reads payment_fee_rate_applied and payment_fee_amount', () {
      final b = Budget.fromJson(
        budgetJson(paymentFeeRateApplied: 6.1, paymentFeeAmount: 1320),
      );
      expect(b.paymentFeeRateApplied, 6.1);
      expect(b.paymentFeeAmountCents, 1320);
      expect(b.hasEmbeddedPaymentFee, isTrue);
    });

    test('copyWithStatus keeps the embedded fee', () {
      final b = Budget.fromJson(
        budgetJson(paymentFeeRateApplied: 6.1, paymentFeeAmount: 1320),
      );
      final moved = b.copyWithStatus(BudgetStatus.sent);
      expect(moved.paymentFeeRateApplied, 6.1);
      expect(moved.paymentFeeAmountCents, 1320);
    });
  });
}
