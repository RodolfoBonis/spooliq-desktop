import 'package:equatable/equatable.dart';
import 'package:spooliq_desktop/core/network/json.dart';

/// Sufixo de preço para o ciclo de cobrança (`/mês`, `/trimestre`, `/ano`).
String billingCycleSuffix(String? cycle) => switch (cycle?.toUpperCase()) {
  'YEARLY' || 'ANNUAL' => '/ano',
  'QUARTERLY' => '/trimestre',
  _ => '/mês',
};

/// Lista que pode vir como array puro, `{data: []}` ou `{<key>: []}`.
List<T> looseList<T>(Object? body, T Function(Json) parse, [String? key]) {
  var raw = body;
  if (raw is Map) raw = raw[key] ?? raw['data'] ?? raw['items'];
  if (raw is! List) return const [];
  return [
    for (final e in raw)
      if (e is Map) parse(Map<String, dynamic>.from(e)),
  ];
}

class PlanFeature extends Equatable {
  const PlanFeature({
    required this.name,
    this.description,
    this.available = true,
  });

  factory PlanFeature.fromJson(Json j) => PlanFeature(
    name: j.str('name'),
    description: j.strOrNull('description'),
    available: j.boolean(
      'is_active',
      fallback: j.boolean('available', fallback: true),
    ),
  );

  final String name;
  final String? description;
  final bool available;

  Json toJson() => {
    'name': name,
    'description': description ?? '',
    'is_active': available,
  };

  @override
  List<Object?> get props => [name, description, available];
}

class Plan extends Equatable {
  const Plan({
    required this.id,
    required this.name,
    required this.price,
    required this.cycle,
    this.description,
    this.features = const [],
    this.isActive = true,
    this.popular = false,
  });

  factory Plan.fromJson(Json json) {
    final j = json.unwrapData();
    return Plan(
      id: j.str('id'),
      name: j.str('name'),
      description: j.strOrNull('description'),
      price: j.dbl('price'),
      cycle: j.str('cycle', j.str('interval', 'MONTHLY')),
      features: j.list('features', PlanFeature.fromJson),
      isActive: j.boolean(
        'is_active',
        fallback: j.boolean('active', fallback: true),
      ),
      popular: j.boolean('popular') || j.boolean('recommended'),
    );
  }

  final String id;
  final String name;
  final String? description;

  /// Preço em reais.
  final double price;
  final String cycle;
  final List<PlanFeature> features;
  final bool isActive;
  final bool popular;

  String get cycleLabel => billingCycleSuffix(cycle);

  @override
  List<Object?> get props => [id, name, price, cycle, features, isActive];
}

class SubscriptionInfo extends Equatable {
  const SubscriptionInfo({
    required this.status,
    this.planName,
    this.value,
    this.cycle,
    this.nextDueDate,
    this.invoiceUrl,
  });

  factory SubscriptionInfo.fromJson(Json j) => SubscriptionInfo(
    status: j.str('status'),
    planName: j.strOrNull('plan_name'),
    value: j.dblOrNull('value'),
    cycle: j.strOrNull('cycle'),
    nextDueDate: j.date('next_due_date'),
    invoiceUrl: j.strOrNull('first_payment_invoice'),
  );

  final String status;
  final String? planName;
  final double? value;
  final String? cycle;
  final DateTime? nextDueDate;
  final String? invoiceUrl;

  @override
  List<Object?> get props => [status, planName, value, nextDueDate];
}

class PaymentMethod extends Equatable {
  const PaymentMethod({
    required this.id,
    required this.holderName,
    required this.last4,
    required this.brand,
    required this.expiry,
    required this.isPrimary,
  });

  factory PaymentMethod.fromJson(Json j) => PaymentMethod(
    id: j.str('id'),
    holderName: j.str('holder_name'),
    last4: j.str('last_4_digits'),
    brand: j.str('brand'),
    expiry: '${j.str('expiry_month')}/${j.str('expiry_year')}',
    isPrimary: j.boolean('is_primary'),
  );

  final String id;
  final String holderName;
  final String last4;
  final String brand;
  final String expiry;
  final bool isPrimary;

  @override
  List<Object?> get props => [id, isPrimary];
}

class Payment extends Equatable {
  const Payment({
    required this.id,
    required this.amount,
    required this.status,
    this.dueDate,
    this.paymentDate,
    this.invoiceUrl,
    this.description,
  });

  factory Payment.fromJson(Json j) => Payment(
    id: j.str('id'),
    amount: j.dbl('amount'),
    status: j.str('status'),
    dueDate: j.date('due_date'),
    paymentDate: j.date('payment_date'),
    invoiceUrl: j.strOrNull('invoice_url'),
    description: j.strOrNull('description'),
  );

  final String id;

  /// Valor em reais.
  final double amount;
  final String status;
  final DateTime? dueDate;
  final DateTime? paymentDate;
  final String? invoiceUrl;
  final String? description;

  String get statusLabel => switch (status.toUpperCase()) {
    'CONFIRMED' || 'RECEIVED' || 'RECEIVED_IN_CASH' => 'Pago',
    'PENDING' => 'Pendente',
    'OVERDUE' => 'Vencido',
    'REFUNDED' => 'Estornado',
    'FAILED' => 'Falhou',
    _ => status,
  };

  bool get isPaid => statusLabel == 'Pago';

  @override
  List<Object?> get props => [id, status];
}

enum BillingType {
  creditCard('CREDIT_CARD', 'Cartão de crédito'),
  pix('PIX', 'Pix'),
  boleto('BOLETO', 'Boleto');

  const BillingType(this.value, this.label);

  final String value;
  final String label;
}

class NewCard {
  const NewCard({
    required this.holderName,
    required this.number,
    required this.expiryMonth,
    required this.expiryYear,
    required this.ccv,
  });

  final String holderName;
  final String number;
  final String expiryMonth;
  final String expiryYear;
  final String ccv;
}

abstract interface class BillingRepository {
  Future<List<Plan>> plans();
  Future<SubscriptionInfo?> status();
  Future<List<PaymentMethod>> paymentMethods();
  Future<PaymentMethod> addCard(NewCard card, {bool primary = true});
  Future<void> setPrimary(String id);
  Future<void> removeCard(String id);
  Future<SubscriptionInfo> subscribe({
    required String planId,
    required BillingType type,
    String? paymentMethodId,
  });

  /// [reason] usa os valores de `CancelReason`; [feedback] é texto livre.
  Future<void> cancel({required String reason, String? feedback});
  Future<List<Payment>> payments();
}
