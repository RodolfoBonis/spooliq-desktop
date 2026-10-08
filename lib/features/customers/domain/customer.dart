import 'package:equatable/equatable.dart';
import 'package:spooliq_desktop/core/network/json.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_status.dart';

/// Orçamento resumido listado no cliente.
class CustomerBudgetSummary extends Equatable {
  const CustomerBudgetSummary({
    required this.id,
    required this.name,
    required this.status,
    required this.totalCents,
    this.createdAt,
  });

  factory CustomerBudgetSummary.fromJson(Json json) => CustomerBudgetSummary(
    id: json.str('id'),
    name: json.str('name'),
    status: BudgetStatus.fromValue(json.strOrNull('status')),
    totalCents: json.integer('total_cost'),
    createdAt: json.date('created_at'),
  );

  final String id;
  final String name;
  final BudgetStatus status;
  final int totalCents;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [id, status, totalCents];
}

class Customer extends Equatable {
  const Customer({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.document,
    this.address,
    this.city,
    this.state,
    this.zipCode,
    this.notes,
    this.isActive = true,
    this.budgetCount = 0,
    this.totalSpentCents = 0,
    this.budgets = const [],
    this.createdAt,
  });

  /// Aceita tanto o wrapper `{customer, budget_count, …}` quanto o objeto puro.
  factory Customer.fromJson(Json json) {
    final c = json.obj('customer') ?? json;
    return Customer(
      id: c.str('id'),
      name: c.str('name'),
      email: c.strOrNull('email'),
      phone: c.strOrNull('phone'),
      document: c.strOrNull('document'),
      address: c.strOrNull('address'),
      city: c.strOrNull('city'),
      state: c.strOrNull('state'),
      zipCode: c.strOrNull('zip_code'),
      notes: c.strOrNull('notes'),
      isActive: c.boolean('is_active', fallback: true),
      createdAt: c.date('created_at'),
      budgetCount: json.integer('budget_count'),
      totalSpentCents: json.integer('total_budgets'),
      budgets: json.list('budgets', CustomerBudgetSummary.fromJson),
    );
  }

  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? document;
  final String? address;
  final String? city;
  final String? state;
  final String? zipCode;
  final String? notes;
  final bool isActive;
  final int budgetCount;

  /// Soma (centavos) dos orçamentos imprimindo/concluídos.
  final int totalSpentCents;
  final List<CustomerBudgetSummary> budgets;
  final DateTime? createdAt;

  String get location =>
      [city, state].whereType<String>().where((s) => s.isNotEmpty).join(' / ');

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final last = parts.length > 1 ? parts.last[0] : '';
    return (parts.first[0] + last).toUpperCase();
  }

  @override
  List<Object?> get props => [
    id,
    name,
    email,
    phone,
    document,
    address,
    city,
    state,
    zipCode,
    notes,
    isActive,
    budgetCount,
    totalSpentCents,
  ];
}

/// Entrada de criação/edição.
class CustomerInput extends Equatable {
  const CustomerInput({
    required this.name,
    this.email,
    this.phone,
    this.document,
    this.address,
    this.city,
    this.state,
    this.zipCode,
    this.notes,
    this.isActive,
  });

  factory CustomerInput.from(Customer c) => CustomerInput(
    name: c.name,
    email: c.email,
    phone: c.phone,
    document: c.document,
    address: c.address,
    city: c.city,
    state: c.state,
    zipCode: c.zipCode,
    notes: c.notes,
    isActive: c.isActive,
  );

  final String name;
  final String? email;
  final String? phone;
  final String? document;
  final String? address;
  final String? city;
  final String? state;
  final String? zipCode;
  final String? notes;
  final bool? isActive;

  Json toJson() => {
    'name': name.trim(),
    'email': _blank(email),
    'phone': _blank(phone),
    'document': _blank(document),
    'address': _blank(address),
    'city': _blank(city),
    'state': _blank(state)?.toUpperCase(),
    'zip_code': _blank(zipCode),
    'notes': _blank(notes),
    'is_active': ?isActive,
  };

  @override
  List<Object?> get props => [
    name,
    email,
    phone,
    document,
    address,
    city,
    state,
    zipCode,
    notes,
    isActive,
  ];
}

String? _blank(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
