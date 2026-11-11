import 'package:equatable/equatable.dart';
import 'package:spooliq_desktop/core/network/json.dart';

/// Parcelas do cartão com taxa cadastrável (crédito à vista é tratado à parte).
const List<int> kFeeInstallments = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

/// Tabela de taxas da InfinitePay por método de pagamento.
///
/// Cada taxa é um percentual (0–30, até 2 casas) sobre o valor cobrado.
/// Uma parcela sem taxa informada é "desconhecida": a estimativa para ela
/// fica nula. [FeeRates] inteiramente vazio significa não cadastrado.
class FeeRates extends Equatable {
  const FeeRates({this.pix, this.credit1x, this.creditInstallments = const {}});

  factory FeeRates.fromJson(Json json) {
    final installments = <int, double>{};
    final raw = json.obj('credit_installments');
    if (raw != null) {
      for (final entry in raw.entries) {
        final n = int.tryParse(entry.key);
        final value = raw.dblOrNull(entry.key);
        if (n != null && value != null) installments[n] = value;
      }
    }
    return FeeRates(
      pix: json.dblOrNull('pix'),
      credit1x: json.dblOrNull('credit_1x'),
      creditInstallments: installments,
    );
  }

  /// Taxa do Pix (`null` = não cadastrada).
  final double? pix;

  /// Taxa do crédito à vista (`null` = não cadastrada).
  final double? credit1x;

  /// Taxas por número de parcelas (2–12); ausente = desconhecida.
  final Map<int, double> creditInstallments;

  /// Alguma taxa cadastrada? Vazio = integração sem tabela.
  bool get hasAny =>
      pix != null || credit1x != null || creditInstallments.isNotEmpty;

  /// Taxa do crédito em [installments] parcelas: 1 (ou 0) = crédito à vista,
  /// N≥2 = `credit_installments[N]`. `null` quando não cadastrada.
  double? rateForInstallments(int installments) =>
      installments <= 1 ? credit1x : creditInstallments[installments];

  /// Corpo `fee_rates`. Só inclui taxas informadas (0 é válido; `null` não).
  Json toJson() => {
    if (pix != null) 'pix': pix,
    if (credit1x != null) 'credit_1x': credit1x,
    'credit_installments': {
      for (final e in creditInstallments.entries) '${e.key}': e.value,
    },
  };

  @override
  List<Object?> get props => [pix, credit1x, creditInstallments];
}

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
    this.feeRates,
    this.embedFeeInPrice = false,
  });

  factory PaymentSettings.fromJson(Json json) {
    final j = json.unwrapData();
    final last4 = j.strOrNull('api_key_last4');
    // Alguns papéis não recebem last4; `connected` chega explícito ou é
    // derivado do carimbo de verificação.
    final connected =
        j.boolOrNull('connected') ??
        (last4 != null || j.date('verified_at') != null);
    final feeRatesJson = j.obj('fee_rates');
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
      // Ausente/nulo = tabela não cadastrada.
      feeRates: feeRatesJson == null ? null : FeeRates.fromJson(feeRatesJson),
      embedFeeInPrice: j.boolean('embed_fee_in_price'),
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

  /// Tabela de taxas por método; `null` = não cadastrada.
  final FeeRates? feeRates;

  /// Embutir a taxa de pagamento no preço do orçamento.
  final bool embedFeeInPrice;

  /// `••••1234` quando conectada, vazio caso contrário.
  String get maskedApiKey => apiKeyLast4 == null ? '' : '••••$apiKeyLast4';

  /// Pode gerar links de pagamento (conectada e ligada).
  bool get isActive => connected && enabled;

  /// Taxa de referência usada ao embutir: crédito em [assuredInstallments].
  double? get referenceFeeRate =>
      feeRates?.rateForInstallments(assuredInstallments);

  PaymentSettings copyWith({
    String? Function()? handle,
    bool? enabled,
    bool? connected,
    String? Function()? apiKeyLast4,
    int? assuredInstallments,
    int? pixDiscountPercent,
    double? Function()? defaultDepositPercent,
    int? pendingLinks,
    FeeRates? Function()? feeRates,
    bool? embedFeeInPrice,
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
    feeRates: feeRates == null ? this.feeRates : feeRates(),
    embedFeeInPrice: embedFeeInPrice ?? this.embedFeeInPrice,
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
    feeRates,
    embedFeeInPrice,
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
    this.feeRates,
    this.embedFeeInPrice = false,
  });

  final String? handle;
  final bool enabled;
  final int assuredInstallments;
  final int pixDiscountPercent;

  /// Nova chave a enviar. `null` = manter a atual.
  final String? apiKey;

  /// `null` = pagamento integral (enviado explícito para poder limpar).
  final double? defaultDepositPercent;

  /// Tabela de taxas; `null`/vazia envia `fee_rates: null` (limpa a tabela).
  final FeeRates? feeRates;

  /// Embutir a taxa no preço.
  final bool embedFeeInPrice;

  Json toJson() => {
    if (apiKey != null && apiKey!.trim().isNotEmpty) 'api_key': apiKey!.trim(),
    'handle': handle?.trim(),
    'enabled': enabled,
    'assured_installments': assuredInstallments,
    'pix_discount_percent': pixDiscountPercent,
    'default_deposit_percent': defaultDepositPercent,
    // Explícito (inclusive null) para poder limpar a tabela.
    'fee_rates': feeRates == null || !feeRates!.hasAny
        ? null
        : feeRates!.toJson(),
    'embed_fee_in_price': embedFeeInPrice,
  };

  @override
  List<Object?> get props => [
    handle,
    enabled,
    assuredInstallments,
    pixDiscountPercent,
    apiKey,
    defaultDepositPercent,
    feeRates,
    embedFeeInPrice,
  ];
}
