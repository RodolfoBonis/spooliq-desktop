import 'package:equatable/equatable.dart';
import 'package:spooliq_desktop/core/network/json.dart';

enum SubscriptionStatus {
  trial('trial', 'Período de teste'),
  active('active', 'Ativa'),
  overdue('overdue', 'Pagamento pendente'),
  paymentPending('payment_pending', 'Pagamento pendente'),
  suspended('suspended', 'Suspensa'),
  cancelled('cancelled', 'Cancelada'),
  permanent('permanent', 'Permanente'),
  unknown('', '—');

  const SubscriptionStatus(this.value, this.label);

  final String value;
  final String label;

  static SubscriptionStatus fromValue(String? v) =>
      values.firstWhere((s) => s.value == v, orElse: () => unknown);
}

/// `current_plan` vem como objeto de plano (`{id, name, …}`); versões
/// antigas mandavam string em `current_plan`/`subscription_plan`.
String? planNameOf(Json j) {
  final plan = j['current_plan'];
  if (plan is Map) return Map<String, dynamic>.from(plan).strOrNull('name');
  return j.strOrNull('current_plan') ?? j.strOrNull('subscription_plan');
}

class Company extends Equatable {
  const Company({
    required this.id,
    required this.name,
    this.tradeName,
    this.document,
    this.email,
    this.phone,
    this.whatsapp,
    this.instagram,
    this.website,
    this.logoUrl,
    this.address,
    this.city,
    this.state,
    this.zipCode,
    this.defaultTaxRate,
    this.defaultQuoteValidityDays,
    this.defaultPaymentTerms,
    this.subscriptionStatus = SubscriptionStatus.unknown,
    this.currentPlan,
    this.trialEndsAt,
    this.isPlatformCompany = false,
  });

  factory Company.fromJson(Json json) {
    final j = json.unwrapData();
    return Company(
      id: j.str('id'),
      name: j.str('name'),
      tradeName: j.strOrNull('trade_name'),
      document: j.strOrNull('document'),
      email: j.strOrNull('email'),
      phone: j.strOrNull('phone'),
      whatsapp: j.strOrNull('whatsapp'),
      instagram: j.strOrNull('instagram'),
      website: j.strOrNull('website'),
      logoUrl: j.strOrNull('logo_url'),
      address: j.strOrNull('address'),
      city: j.strOrNull('city'),
      state: j.strOrNull('state'),
      zipCode: j.strOrNull('zip_code'),
      defaultTaxRate: j.dblOrNull('default_tax_rate'),
      defaultQuoteValidityDays: j.intOrNull('default_quote_validity_days'),
      defaultPaymentTerms: j.strOrNull('default_payment_terms'),
      subscriptionStatus: SubscriptionStatus.fromValue(
        j.strOrNull('subscription_status'),
      ),
      currentPlan: planNameOf(j),
      trialEndsAt: j.date('trial_ends_at'),
      isPlatformCompany: j.boolean('is_platform_company'),
    );
  }

  final String id;
  final String name;
  final String? tradeName;
  final String? document;
  final String? email;
  final String? phone;
  final String? whatsapp;
  final String? instagram;
  final String? website;
  final String? logoUrl;
  final String? address;
  final String? city;
  final String? state;
  final String? zipCode;
  final double? defaultTaxRate;
  final int? defaultQuoteValidityDays;
  final String? defaultPaymentTerms;
  final SubscriptionStatus subscriptionStatus;
  final String? currentPlan;
  final DateTime? trialEndsAt;
  final bool isPlatformCompany;

  String get displayName =>
      (tradeName != null && tradeName!.isNotEmpty) ? tradeName! : name;

  int? get trialDaysLeft {
    final end = trialEndsAt;
    if (end == null || subscriptionStatus != SubscriptionStatus.trial) {
      return null;
    }
    final days = end.difference(DateTime.now()).inHours / 24;
    return days < 0 ? 0 : days.ceil();
  }

  Json toUpdateJson() => {
    'name': name.trim(),
    'trade_name': tradeName?.trim(),
    'document': document?.trim(),
    'email': email?.trim(),
    'phone': phone?.trim(),
    'whatsapp': whatsapp?.trim(),
    'instagram': instagram?.trim(),
    'website': website?.trim(),
    'address': address?.trim(),
    'city': city?.trim(),
    'state': state?.trim().toUpperCase(),
    'zip_code': zipCode?.trim(),
    'default_tax_rate': defaultTaxRate,
    'default_quote_validity_days': defaultQuoteValidityDays,
    'default_payment_terms': defaultPaymentTerms?.trim(),
  };

  Company copyWith({
    String? name,
    String? Function()? tradeName,
    String? Function()? document,
    String? Function()? email,
    String? Function()? phone,
    String? Function()? whatsapp,
    String? Function()? instagram,
    String? Function()? website,
    String? Function()? logoUrl,
    String? Function()? address,
    String? Function()? city,
    String? Function()? state,
    String? Function()? zipCode,
    double? Function()? defaultTaxRate,
    int? Function()? defaultQuoteValidityDays,
    String? Function()? defaultPaymentTerms,
  }) => Company(
    id: id,
    name: name ?? this.name,
    tradeName: tradeName == null ? this.tradeName : tradeName(),
    document: document == null ? this.document : document(),
    email: email == null ? this.email : email(),
    phone: phone == null ? this.phone : phone(),
    whatsapp: whatsapp == null ? this.whatsapp : whatsapp(),
    instagram: instagram == null ? this.instagram : instagram(),
    website: website == null ? this.website : website(),
    logoUrl: logoUrl == null ? this.logoUrl : logoUrl(),
    address: address == null ? this.address : address(),
    city: city == null ? this.city : city(),
    state: state == null ? this.state : state(),
    zipCode: zipCode == null ? this.zipCode : zipCode(),
    defaultTaxRate: defaultTaxRate == null
        ? this.defaultTaxRate
        : defaultTaxRate(),
    defaultQuoteValidityDays: defaultQuoteValidityDays == null
        ? this.defaultQuoteValidityDays
        : defaultQuoteValidityDays(),
    defaultPaymentTerms: defaultPaymentTerms == null
        ? this.defaultPaymentTerms
        : defaultPaymentTerms(),
    subscriptionStatus: subscriptionStatus,
    currentPlan: currentPlan,
    trialEndsAt: trialEndsAt,
    isPlatformCompany: isPlatformCompany,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    tradeName,
    document,
    email,
    phone,
    whatsapp,
    instagram,
    website,
    logoUrl,
    address,
    city,
    state,
    zipCode,
    defaultTaxRate,
    defaultQuoteValidityDays,
    defaultPaymentTerms,
    subscriptionStatus,
    currentPlan,
    trialEndsAt,
  ];
}

/// Cores do PDF (13 slots `#RRGGBB`) + template.
class CompanyBranding extends Equatable {
  const CompanyBranding({required this.colors, this.templateName});

  factory CompanyBranding.fromJson(Json json) {
    final j = json.unwrapData();
    return CompanyBranding(
      templateName: j.strOrNull('template_name'),
      colors: {
        for (final k in keys)
          if (j.strOrNull(k) != null) k: j.str(k),
      },
    );
  }

  static const keys = [
    'header_bg_color',
    'header_text_color',
    'primary_color',
    'primary_text_color',
    'secondary_color',
    'secondary_text_color',
    'title_color',
    'body_text_color',
    'accent_color',
    'border_color',
    'background_color',
    'table_header_bg_color',
    'table_row_alt_bg_color',
  ];

  static const labels = {
    'header_bg_color': 'Fundo do cabeçalho',
    'header_text_color': 'Texto do cabeçalho',
    'primary_color': 'Primária',
    'primary_text_color': 'Texto sobre primária',
    'secondary_color': 'Secundária',
    'secondary_text_color': 'Texto sobre secundária',
    'title_color': 'Títulos',
    'body_text_color': 'Texto',
    'accent_color': 'Destaque',
    'border_color': 'Bordas',
    'background_color': 'Fundo',
    'table_header_bg_color': 'Cabeçalho da tabela',
    'table_row_alt_bg_color': 'Linhas alternadas',
  };

  final String? templateName;
  final Map<String, String> colors;

  Json toJson() => {'template_name': ?templateName, ...colors};

  CompanyBranding withColor(String key, String hex) => CompanyBranding(
    templateName: templateName,
    colors: {...colors, key: hex},
  );

  @override
  List<Object?> get props => [templateName, colors];
}

class BrandingTemplate extends Equatable {
  const BrandingTemplate({
    required this.name,
    required this.displayName,
    required this.description,
    required this.branding,
  });

  factory BrandingTemplate.fromJson(Json json) => BrandingTemplate(
    name: json.str('name'),
    displayName: json.str('display_name', json.str('name')),
    description: json.str('description'),
    branding: CompanyBranding.fromJson(
      json.obj('colors') ?? const <String, dynamic>{},
    ),
  );

  final String name;
  final String displayName;
  final String description;
  final CompanyBranding branding;

  @override
  List<Object?> get props => [name, branding];
}
