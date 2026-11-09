import 'package:equatable/equatable.dart';
import 'package:spooliq_desktop/core/network/json.dart';

/// O que está sendo cobrado neste pagamento.
enum PaymentKind {
  deposit('deposit', 'Sinal'),
  balance('balance', 'Saldo'),
  full('full', 'Integral');

  const PaymentKind(this.value, this.label);

  final String value;
  final String label;

  static PaymentKind fromValue(String? v) => switch (v) {
    'deposit' => deposit,
    'balance' => balance,
    _ => full,
  };
}

/// Situação de uma linha de pagamento.
enum BudgetPaymentStatus {
  pending('pending'),
  paid('paid'),
  refunded('refunded'),
  canceled('canceled'),
  failed('failed');

  const BudgetPaymentStatus(this.value);

  final String value;

  static BudgetPaymentStatus fromValue(String? v) => switch (v) {
    'paid' => paid,
    'refunded' => refunded,
    'canceled' => canceled,
    'failed' => failed,
    _ => pending,
  };
}

/// Um pagamento de orçamento (`GET /v1/budgets/:id/payments`).
class BudgetPayment extends Equatable {
  const BudgetPayment({
    required this.kind,
    required this.status,
    required this.amountCents,
    this.paidAmountCents = 0,
    this.installments,
    this.captureMethod,
    this.statusReason,
    this.receiptUrl,
    this.paidAt,
  });

  factory BudgetPayment.fromJson(Json json) => BudgetPayment(
    kind: PaymentKind.fromValue(json.strOrNull('kind')),
    status: BudgetPaymentStatus.fromValue(json.strOrNull('status')),
    amountCents: json.integer('amount_cents', json.integer('amount')),
    paidAmountCents: json.integer(
      'paid_amount_cents',
      json.integer('paid_amount'),
    ),
    installments: json.intOrNull('installments'),
    captureMethod: json.strOrNull('capture_method'),
    statusReason: json.strOrNull('status_reason'),
    receiptUrl: json.strOrNull('receipt_url'),
    paidAt: json.date('paid_at'),
  );

  final PaymentKind kind;
  final BudgetPaymentStatus status;
  final int amountCents;
  final int paidAmountCents;
  final int? installments;

  /// `pix`, `credit_card`, `debit_card`… vindo da InfinitePay.
  final String? captureMethod;
  final String? statusReason;
  final String? receiptUrl;
  final DateTime? paidAt;

  bool get isPaid => status == BudgetPaymentStatus.paid;

  /// O comprador pagou depois do link ter sido cancelado (precisa de estorno
  /// manual pela InfinitePay).
  bool get isPaidAfterCancel => statusReason == 'paid_after_cancel';

  /// Rótulo do método: Pix, Cartão ou "—".
  String get methodLabel => switch (captureMethod) {
    null || '' => '—',
    'pix' => 'Pix',
    _ => 'Cartão',
  };

  @override
  List<Object?> get props => [
    kind,
    status,
    amountCents,
    paidAmountCents,
    installments,
    captureMethod,
    statusReason,
    receiptUrl,
    paidAt,
  ];
}

/// Link de pagamento gerado (`POST /v1/budgets/:id/payments/link`).
class PaymentLink extends Equatable {
  const PaymentLink({
    required this.checkoutUrl,
    required this.kind,
    required this.amountCents,
    this.expiresAt,
  });

  factory PaymentLink.fromJson(Json json) {
    final j = json.unwrapData();
    return PaymentLink(
      checkoutUrl: j.str('checkout_url'),
      kind: PaymentKind.fromValue(j.strOrNull('kind')),
      amountCents: j.integer('amount_cents', j.integer('amount')),
      expiresAt: j.date('expires_at'),
    );
  }

  final String checkoutUrl;
  final PaymentKind kind;
  final int amountCents;
  final DateTime? expiresAt;

  @override
  List<Object?> get props => [checkoutUrl, kind, amountCents, expiresAt];
}
