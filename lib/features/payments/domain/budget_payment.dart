import 'package:equatable/equatable.dart';
import 'package:spooliq_desktop/core/network/json.dart';
import 'package:spooliq_desktop/core/observability/app_logger.dart';

/// O que está sendo cobrado neste pagamento.
enum PaymentKind {
  deposit('deposit', 'Sinal'),
  balance('balance', 'Saldo'),
  full('full', 'Integral');

  const PaymentKind(this.value, this.label);

  final String value;
  final String label;

  static PaymentKind fromValue(String? v) {
    switch (v) {
      case 'deposit':
        return deposit;
      case 'balance':
        return balance;
      case 'full':
        return full;
      default:
        if (v != null && v.isNotEmpty) {
          AppLogger.warning(
            'Tipo de cobrança desconhecido: $v',
            category: 'payments',
          );
        }
        return full;
    }
  }
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

  static BudgetPaymentStatus fromValue(String? v) {
    switch (v) {
      case 'pending':
        return pending;
      case 'paid':
        return paid;
      case 'refunded':
        return refunded;
      case 'canceled':
        return canceled;
      case 'failed':
        return failed;
      default:
        if (v != null && v.isNotEmpty) {
          AppLogger.warning(
            'Status de pagamento desconhecido: $v',
            category: 'payments',
          );
        }
        return pending;
    }
  }
}

/// Um pagamento de orçamento (`PaymentLineResponse`).
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
    amountCents: json.integer('amount'),
    paidAmountCents: json.integer('paid_amount'),
    installments: json.intOrNull('installments'),
    captureMethod: json.strOrNull('capture_method'),
    // Exposto só no contrato autenticado; ausente = null.
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

/// Resposta de `GET /v1/budgets/:id/payments` (`BudgetPaymentsResponse`).
///
/// Só guardamos o que a tela usa: o valor a reembolsar (soma dos pagamentos
/// `paid_after_cancel`, que NÃO entra no total pago) e as linhas. A agregação
/// pago/saldo vem do próprio orçamento.
class BudgetPaymentsResult extends Equatable {
  const BudgetPaymentsResult({
    this.refundDueCents = 0,
    this.payments = const [],
  });

  factory BudgetPaymentsResult.fromJson(Json json) => BudgetPaymentsResult(
    refundDueCents: json.integer('refund_due'),
    payments: json.list('payments', BudgetPayment.fromJson),
  );

  /// Valor recebido em links cancelados, a reembolsar pela InfinitePay.
  final int refundDueCents;
  final List<BudgetPayment> payments;

  @override
  List<Object?> get props => [refundDueCents, payments];
}

/// Link de pagamento gerado (`CreateLinkResponse`).
class PaymentLink extends Equatable {
  const PaymentLink({
    required this.checkoutUrl,
    required this.kind,
    required this.amountCents,
    this.expiresAt,
  });

  factory PaymentLink.fromJson(Json json) => PaymentLink(
    checkoutUrl: json.str('checkout_url'),
    kind: PaymentKind.fromValue(json.strOrNull('kind')),
    amountCents: json.integer('amount'),
    expiresAt: json.date('expires_at'),
  );

  final String checkoutUrl;
  final PaymentKind kind;
  final int amountCents;
  final DateTime? expiresAt;

  @override
  List<Object?> get props => [checkoutUrl, kind, amountCents, expiresAt];
}
