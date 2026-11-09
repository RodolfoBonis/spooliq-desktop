import 'package:equatable/equatable.dart';
import 'package:spooliq_desktop/core/network/json.dart';

/// Configuração da integração de pagamentos (InfinitePay) de uma empresa.
///
/// A chave de API nunca volta da API: só os 4 últimos dígitos ([apiKeyLast4]),
/// e apenas para papéis que podem gerenciar (Owner/OrgAdmin). O papel User
/// recebe os campos não sensíveis para montar o orçamento.
class PaymentSettings extends Equatable {
  const PaymentSettings({
    this.handle,
    this.enabled = false,
    this.connected = false,
    this.apiKeyLast4,
    this.assuredInstallments = 12,
    this.pixDiscountPercent = 0,
    this.defaultDepositPercent,
    this.pendingLinks = 0,
  });

  factory PaymentSettings.fromJson(Json json) {
    final j = json.unwrapData();
    final last4 = j.strOrNull('api_key_last4');
    // Alguns papéis não recebem last4; `connected` chega explícito ou é
    // derivado do carimbo de verificação.
    final connected =
        j.boolOrNull('connected') ??
        (last4 != null || j.date('verified_at') != null);
    return PaymentSettings(
      handle: j.strOrNull('handle'),
      enabled: j.boolean('enabled'),
      connected: connected,
      apiKeyLast4: last4,
      assuredInstallments: (j.intOrNull('assured_installments') ?? 12).clamp(
        1,
        12,
      ),
      pixDiscountPercent: j.integer('pix_discount_percent'),
      defaultDepositPercent: j.dblOrNull('default_deposit_percent'),
      pendingLinks: j.integer('pending_links'),
    );
  }

  final String? handle;
  final bool enabled;

  /// Credenciais já cadastradas (a empresa colou a chave e ela foi validada).
  final bool connected;

  /// Últimos 4 dígitos da chave, só para papéis gerenciais.
  final String? apiKeyLast4;

  /// Parcelas sem juros (1–12).
  final int assuredInstallments;

  /// Desconto Pix inteiro (0–30%).
  final int pixDiscountPercent;

  /// Sinal padrão aplicado a novos orçamentos; `null` = pagamento integral.
  final double? defaultDepositPercent;

  /// Links de pagamento pendentes (só papéis gerenciais).
  final int pendingLinks;

  /// `••••1234` quando conectada, vazio caso contrário.
  String get maskedApiKey => apiKeyLast4 == null ? '' : '••••$apiKeyLast4';

  /// Pode gerar links de pagamento (conectada e ligada).
  bool get isActive => connected && enabled;

  PaymentSettings copyWith({
    String? Function()? handle,
    bool? enabled,
    bool? connected,
    String? Function()? apiKeyLast4,
    int? assuredInstallments,
    int? pixDiscountPercent,
    double? Function()? defaultDepositPercent,
    int? pendingLinks,
  }) => PaymentSettings(
    handle: handle == null ? this.handle : handle(),
    enabled: enabled ?? this.enabled,
    connected: connected ?? this.connected,
    apiKeyLast4: apiKeyLast4 == null ? this.apiKeyLast4 : apiKeyLast4(),
    assuredInstallments: assuredInstallments ?? this.assuredInstallments,
    pixDiscountPercent: pixDiscountPercent ?? this.pixDiscountPercent,
    defaultDepositPercent: defaultDepositPercent == null
        ? this.defaultDepositPercent
        : defaultDepositPercent(),
    pendingLinks: pendingLinks ?? this.pendingLinks,
  );

  @override
  List<Object?> get props => [
    handle,
    enabled,
    connected,
    apiKeyLast4,
    assuredInstallments,
    pixDiscountPercent,
    defaultDepositPercent,
    pendingLinks,
  ];
}

/// Corpo do `PUT /v1/company/payments/infinitepay`.
///
/// A chave (`apiKey`) é omitida quando `null` para preservar a existente;
/// `defaultDepositPercent` vai sempre explícito (inclusive `null`) para que
/// limpar o sinal padrão persista (`null` = pagamento integral).
class PaymentSettingsUpdate extends Equatable {
  const PaymentSettingsUpdate({
    required this.handle,
    required this.enabled,
    required this.assuredInstallments,
    required this.pixDiscountPercent,
    this.apiKey,
    this.defaultDepositPercent,
  });

  final String? handle;
  final bool enabled;
  final int assuredInstallments;
  final int pixDiscountPercent;

  /// Nova chave a enviar. `null` = manter a atual.
  final String? apiKey;

  /// `null` = pagamento integral (enviado explícito para poder limpar).
  final double? defaultDepositPercent;

  Json toJson() => {
    if (apiKey != null && apiKey!.trim().isNotEmpty) 'api_key': apiKey!.trim(),
    'handle': handle?.trim(),
    'enabled': enabled,
    'assured_installments': assuredInstallments,
    'pix_discount_percent': pixDiscountPercent,
    'default_deposit_percent': defaultDepositPercent,
  };

  @override
  List<Object?> get props => [
    handle,
    enabled,
    assuredInstallments,
    pixDiscountPercent,
    apiKey,
    defaultDepositPercent,
  ];
}
