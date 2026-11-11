import 'package:flutter_test/flutter_test.dart';
import 'package:spooliq_desktop/features/payments/domain/budget_payment.dart';

void main() {
  group('BudgetPayment fee estimate', () {
    test('reads fee_amount, net_amount and fee_rate_percent', () {
      // Caso real: pago 217,12 em 4x, taxa 7,9% → líquido 199,97.
      final p = BudgetPayment.fromJson(const {
        'kind': 'full',
        'amount': 21712,
        'paid_amount': 21712,
        'capture_method': 'credit_card',
        'installments': 4,
        'status': 'paid',
        'fee_amount': 1715,
        'net_amount': 19997,
        'fee_rate_percent': 7.9,
      });
      expect(p.feeAmountCents, 1715);
      expect(p.netAmountCents, 19997);
      expect(p.feeRatePercent, 7.9);
      expect(p.hasFeeEstimate, isTrue);
      expect(p.isPaidCounted, isTrue);
    });

    test('an absent estimate stays null and hasFeeEstimate is false', () {
      final p = BudgetPayment.fromJson(const {
        'kind': 'full',
        'amount': 1000,
        'paid_amount': 1000,
        'status': 'paid',
      });
      expect(p.feeAmountCents, isNull);
      expect(p.netAmountCents, isNull);
      expect(p.feeRatePercent, isNull);
      expect(p.hasFeeEstimate, isFalse);
    });

    test('a paid_after_cancel line is not counted', () {
      final p = BudgetPayment.fromJson(const {
        'kind': 'full',
        'amount': 1000,
        'paid_amount': 1000,
        'status': 'paid',
        'status_reason': 'paid_after_cancel',
      });
      expect(p.isPaid, isTrue);
      expect(p.isPaidCounted, isFalse);
    });
  });

  group('BudgetPaymentsResult totals', () {
    test('reads fees and net_received', () {
      final r = BudgetPaymentsResult.fromJson(const {
        'refund_due': 0,
        'fees': 1715,
        'net_received': 19997,
        'payments': [
          {
            'kind': 'full',
            'amount': 21712,
            'paid_amount': 21712,
            'status': 'paid',
            'fee_amount': 1715,
            'net_amount': 19997,
          },
        ],
      });
      expect(r.feesCents, 1715);
      expect(r.netReceivedCents, 19997);
    });

    test('leaves the totals null when absent (no table configured)', () {
      final r = BudgetPaymentsResult.fromJson(const {
        'refund_due': 0,
        'payments': [
          {
            'kind': 'full',
            'amount': 1000,
            'paid_amount': 1000,
            'status': 'paid',
          },
        ],
      });
      expect(r.feesCents, isNull);
      expect(r.netReceivedCents, isNull);
    });
  });
}
