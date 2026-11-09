import 'package:flutter_test/flutter_test.dart';
import 'package:spooliq_desktop/features/payments/domain/budget_payment.dart';

void main() {
  group('BudgetPayment.fromJson', () {
    test('reads the exact PaymentLineResponse field names', () {
      final p = BudgetPayment.fromJson(const {
        'kind': 'deposit',
        'amount': 1000,
        'paid_amount': 950,
        'capture_method': 'pix',
        'installments': 1,
        'status': 'paid',
        'receipt_url': 'https://infinitepay.io/r/1',
        'paid_at': '2026-11-05T10:00:00Z',
      });
      expect(p.kind, PaymentKind.deposit);
      expect(p.amountCents, 1000);
      expect(p.paidAmountCents, 950);
      expect(p.methodLabel, 'Pix');
      expect(p.status, BudgetPaymentStatus.paid);
      expect(p.isPaid, isTrue);
      expect(p.receiptUrl, 'https://infinitepay.io/r/1');
      expect(p.paidAt, isNotNull);
    });

    test('labels card capture methods as Cartão', () {
      final p = BudgetPayment.fromJson(const {
        'kind': 'balance',
        'amount': 500,
        'paid_amount': 500,
        'capture_method': 'credit_card',
        'installments': 3,
        'status': 'paid',
      });
      expect(p.kind, PaymentKind.balance);
      expect(p.methodLabel, 'Cartão');
      expect(p.installments, 3);
    });

    test('detects paid_after_cancel from status_reason', () {
      final p = BudgetPayment.fromJson(const {
        'kind': 'full',
        'amount': 200,
        'paid_amount': 200,
        'status': 'paid',
        'status_reason': 'paid_after_cancel',
      });
      expect(p.isPaidAfterCancel, isTrue);
    });

    test('treats an absent status_reason as not-after-cancel', () {
      final p = BudgetPayment.fromJson(const {
        'kind': 'full',
        'amount': 200,
        'paid_amount': 200,
        'status': 'paid',
      });
      expect(p.statusReason, isNull);
      expect(p.isPaidAfterCancel, isFalse);
    });

    test('falls back to safe defaults for unknown enum values', () {
      final p = BudgetPayment.fromJson(const {
        'kind': 'weird',
        'amount': 100,
        'status': 'mystery',
      });
      expect(p.kind, PaymentKind.full);
      expect(p.status, BudgetPaymentStatus.pending);
      expect(p.methodLabel, '—');
    });
  });

  group('BudgetPaymentsResult.fromJson', () {
    test('reads refund_due and the payment lines', () {
      final r = BudgetPaymentsResult.fromJson(const {
        'status': 'partial',
        'total': 2000,
        'paid': 1000,
        'balance': 1000,
        'refund_due': 500,
        'payments': [
          {
            'kind': 'deposit',
            'amount': 1000,
            'paid_amount': 1000,
            'status': 'paid',
          },
        ],
      });
      expect(r.refundDueCents, 500);
      expect(r.payments, hasLength(1));
      expect(r.payments.single.kind, PaymentKind.deposit);
    });

    test('defaults refund_due to 0 and payments to empty when absent', () {
      final r = BudgetPaymentsResult.fromJson(const {'status': 'unpaid'});
      expect(r.refundDueCents, 0);
      expect(r.payments, isEmpty);
    });
  });

  group('PaymentLink.fromJson', () {
    test('reads the CreateLinkResponse shape', () {
      final link = PaymentLink.fromJson(const {
        'checkout_url': 'https://checkout.infinitepay.io/x',
        'kind': 'deposit',
        'amount': 1000,
        'expires_at': '2026-12-01T10:00:00Z',
      });
      expect(link.checkoutUrl, 'https://checkout.infinitepay.io/x');
      expect(link.kind, PaymentKind.deposit);
      expect(link.amountCents, 1000);
      expect(link.expiresAt, isNotNull);
    });
  });
}
