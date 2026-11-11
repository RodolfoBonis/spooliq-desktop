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
    this.feeAmountCents,
    this.netAmountCents,
    this.feeRatePercent,
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
    // Taxa da InfinitePay: ausente/nulo = desconhecida (sem tabela).
    feeAmountCents: json.intOrNull('fee_amount'),
    netAmountCents: json.intOrNull('net_amount'),
    feeRatePercent: json.dblOrNull('fee_rate_percent'),
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

  /// Taxa cobrada pela InfinitePay (centavos); `null` = desconhecida.
  final int? feeAmountCents;

  /// Valor líquido recebido (centavos); `null` = desconhecido.
  final int? netAmountCents;

  /// Percentual da taxa aplicada; `null` = desconhecido.
  final double? feeRatePercent;

  bool get isPaid => status == BudgetPaymentStatus.paid;

  /// Há estimativa de taxa/líquido para esta linha.
  bool get hasFeeEstimate => netAmountCents != null && feeAmountCents != null;

  /// O comprador pagou depois do link ter sido cancelado (precisa de estorno
  /// manual pela InfinitePay).
  bool get isPaidAfterCancel => statusReason == 'paid_after_cancel';

  /// Pago e contado no agregado (exclui `paid_after_cancel`).
  bool get isPaidCounted => isPaid && !isPaidAfterCancel;

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
    feeAmountCents,
    netAmountCents,
    feeRatePercent,
  ];
}

/// Resposta de `GET /v1/budgets/:id/payments` (`BudgetPaymentsResponse`).
///
/// Só guardamos o que a tela usa: o valor a reembolsar (soma dos pagamentos
/// `paid_after_cancel`, que NÃO entra no total pago), as linhas e os totais de
/// taxa/líquido. A agregação pago/saldo vem do próprio orçamento.
class BudgetPaymentsResult extends Equatable {
  const BudgetPaymentsResult({
    this.refundDueCents = 0,
    this.payments = const [],
    this.feesCents,
    this.netReceivedCents,
  });

  factory BudgetPaymentsResult.fromJson(Json json) => BudgetPaymentsResult(
    refundDueCents: json.integer('refund_due'),
    payments: json.list('payments', BudgetPayment.fromJson),
    // Soma das taxas/líquido conhecidos; ausente = desconhecido.
    feesCents: json.intOrNull('fees'),
    netReceivedCents: json.intOrNull('net_received'),
  );

  /// Valor recebido em links cancelados, a reembolsar pela InfinitePay.
  final int refundDueCents;
  final List<BudgetPayment> payments;

  /// Soma das taxas conhecidas das linhas pagas e contadas; `null` = sem
  /// estimativa (tabela não cadastrada).
  final int? feesCents;

  /// Líquido total recebido; `null` = desconhecido.
  final int? netReceivedCents;

  @override
  List<Object?> get props => [
    refundDueCents,
    payments,
    feesCents,
    netReceivedCents,
  ];
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
