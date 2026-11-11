import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/observability/app_logger.dart';
import 'package:spooliq_desktop/features/payments/domain/payment_repository.dart';
import 'package:spooliq_desktop/features/payments/domain/payment_settings.dart';

enum PaymentSettingsStatus { loading, ready, saving, failure }

/// Mensagens amigáveis para os erros esperados da InfinitePay.
const _invalidCredentialsMessage =
    'A chave de API da InfinitePay é inválida. Confira no app da InfinitePay '
    '(Vendas → Checkout → Configurações) e cole a chave novamente.';
const _apiKeyRequiredMessage = 'Informe a chave de API.';
const _unavailableMessage =
    'Os pagamentos estão indisponíveis no momento. Tente novamente em '
    'instantes.';
const _feeRateMissingMessage =
    'Cadastre a taxa do crédito nas parcelas sem juros antes de embutir a '
    'taxa no preço.';
const _feeRateInvalidMessage =
    'Confira as taxas: use valores de 0 a 30% com até 2 casas decimais.';

/// Mensagens de validação das taxas.
const feeRangeMessage = 'A taxa deve estar entre 0 e 30%.';
const feeDecimalsMessage = 'Use no máximo 2 casas decimais.';

/// Traduz os erros conhecidos da InfinitePay; demais erros mostram a mensagem
/// que a própria API enviou.
String friendlyPaymentError(ApiError error) {
  switch (error.code) {
    case 'infinitepay_invalid_credentials':
      return _invalidCredentialsMessage;
    case 'api_key_required':
      return _apiKeyRequiredMessage;
    case 'payment_fee_rate_missing':
      return _feeRateMissingMessage;
    case 'payment_fee_rate_invalid':
      return _feeRateInvalidMessage;
    case 'payments_not_configured':
      return _unavailableMessage;
  }
  if (error.statusCode == 503) return _unavailableMessage;
  return error.message;
}

/// Arredonda uma taxa para 2 casas decimais (ou mantém `null`).
double? roundFeeRate(double? value) =>
    value == null ? null : (value * 100).round() / 100;

/// Erro de validação de uma taxa: fora de faixa ou com casas demais.
String? feeRateError(double? value) {
  if (value == null) return null;
  if (value < 0 || value > 30) return feeRangeMessage;
  if (((value * 100) - (value * 100).round()).abs() > 1e-9) {
    return feeDecimalsMessage;
  }
  return null;
}

class PaymentSettingsState extends Equatable {
  const PaymentSettingsState({
    this.status = PaymentSettingsStatus.loading,
    this.original,
    this.handle = '',
    this.enabled = false,
    this.assuredInstallments = 12,
    this.pixDiscountPercent = 0,
    this.defaultDepositPercent,
    this.pixRate,
    this.credit1xRate,
    this.installmentRates = const {},
    this.embedFeeInPrice = false,
    this.newApiKey,
    this.editingKey = false,
    this.submitted = false,
    this.loadError,
    this.saveError,
  });

  final PaymentSettingsStatus status;

  /// Último estado carregado/salvo do servidor.
  final PaymentSettings? original;

  // Campos do formulário.
  final String handle;
  final bool enabled;
  final int assuredInstallments;
  final int pixDiscountPercent;
  final double? defaultDepositPercent;

  /// Taxas (%) por método; `null` = não informada.
  final double? pixRate;
  final double? credit1xRate;

  /// Taxas (%) por número de parcelas (2–12); valor `null` = não informada.
  final Map<int, double?> installmentRates;

  /// Embutir a taxa de pagamento no preço do orçamento.
  final bool embedFeeInPrice;

  /// Nova chave digitada; `null` = manter a atual.
  final String? newApiKey;

  /// O campo de chave está em modo de edição (sempre quando desconectada).
  final bool editingKey;

  /// Houve uma tentativa de salvar — libera a exibição dos erros por campo.
  final bool submitted;

  final String? loadError;
  final String? saveError;

  bool get connected => original?.connected ?? false;
  int get pendingLinks => original?.pendingLinks ?? 0;
  String get maskedApiKey => original?.maskedApiKey ?? '';
  bool get saving => status == PaymentSettingsStatus.saving;

  /// Taxa de referência para embutir: crédito em [assuredInstallments].
  /// Crédito à vista quando N≤1, senão a parcela correspondente.
  double? get referenceFeeRate => assuredInstallments <= 1
      ? credit1xRate
      : installmentRates[assuredInstallments];

  /// Monta a tabela de taxas a partir do formulário (ignora parcelas vazias).
  FeeRates buildFeeRates() => FeeRates(
    pix: pixRate,
    credit1x: credit1xRate,
    creditInstallments: {
      for (final n in kFeeInstallments)
        if (installmentRates[n] != null) n: installmentRates[n]!,
    },
  );

  /// Parcelas (2–12) com taxa inválida — para o resumo acessível da grade.
  List<int> get invalidInstallments => [
    for (final n in kFeeInstallments)
      if (feeRateError(installmentRates[n]) != null) n,
  ];

  /// Erros de validação por campo, calculados sob demanda.
  Map<String, String> validate() {
    final errors = <String, String>{};
    if (handle.trim().isEmpty) {
      errors['handle'] = 'Informe o @handle da sua conta InfinitePay.';
    }
    final key = (newApiKey ?? '').trim();
    if (!connected) {
      if (key.isEmpty) {
        errors['api_key'] = _apiKeyRequiredMessage;
      } else if (key.length < 8) {
        errors['api_key'] = 'A chave deve ter ao menos 8 caracteres.';
      }
    } else if (editingKey && key.isNotEmpty && key.length < 8) {
      errors['api_key'] = 'A chave deve ter ao menos 8 caracteres.';
    }
    if (assuredInstallments < 1 || assuredInstallments > 12) {
      errors['installments'] = 'Use de 1 a 12 parcelas.';
    }
    if (pixDiscountPercent < 0 || pixDiscountPercent > 30) {
      errors['pix_discount'] = 'O desconto Pix deve estar entre 0 e 30%.';
    }
    final deposit = defaultDepositPercent;
    if (deposit != null && (deposit <= 0 || deposit >= 100)) {
      errors['deposit'] = 'O sinal deve ser maior que 0 e menor que 100%.';
    }
    // Taxas: faixa de 0 a 30% e até 2 casas decimais.
    final pixError = feeRateError(pixRate);
    if (pixError != null) errors['fee_pix'] = pixError;
    final credit1xError = feeRateError(credit1xRate);
    if (credit1xError != null) errors['fee_credit_1x'] = credit1xError;
    for (final n in kFeeInstallments) {
      final error = feeRateError(installmentRates[n]);
      if (error != null) errors['fee_credit_$n'] = error;
    }
    // Para embutir, a taxa de referência precisa estar cadastrada.
    if (embedFeeInPrice && referenceFeeRate == null) {
      errors['embed_fee'] = assuredInstallments <= 1
          ? 'Cadastre a taxa do crédito à vista para embutir no preço.'
          : 'Cadastre a taxa do crédito em ${assuredInstallments}x para '
                'embutir no preço.';
    }
    return errors;
  }

  /// Erros exibidos na UI (só após a 1ª tentativa de salvar).
  Map<String, String> get errors => submitted ? validate() : const {};

  bool get dirty {
    final o = original;
    if (o == null) return false;
    if ((newApiKey ?? '').trim().isNotEmpty) return true;
    if (embedFeeInPrice != o.embedFeeInPrice) return true;
    final fees = o.feeRates;
    if (pixRate != fees?.pix) return true;
    if (credit1xRate != fees?.credit1x) return true;
    for (final n in kFeeInstallments) {
      if (installmentRates[n] != fees?.creditInstallments[n]) return true;
    }
    return handle != (o.handle ?? '') ||
        enabled != o.enabled ||
        assuredInstallments != o.assuredInstallments ||
        pixDiscountPercent != o.pixDiscountPercent ||
        defaultDepositPercent != o.defaultDepositPercent;
  }

  PaymentSettingsState copyWith({
    PaymentSettingsStatus? status,
    PaymentSettings? original,
    String? handle,
    bool? enabled,
    int? assuredInstallments,
    int? pixDiscountPercent,
    double? Function()? defaultDepositPercent,
    double? Function()? pixRate,
    double? Function()? credit1xRate,
    Map<int, double?>? installmentRates,
    bool? embedFeeInPrice,
    String? Function()? newApiKey,
    bool? editingKey,
    bool? submitted,
    String? Function()? loadError,
    String? Function()? saveError,
  }) => PaymentSettingsState(
    status: status ?? this.status,
    original: original ?? this.original,
    handle: handle ?? this.handle,
    enabled: enabled ?? this.enabled,
    assuredInstallments: assuredInstallments ?? this.assuredInstallments,
    pixDiscountPercent: pixDiscountPercent ?? this.pixDiscountPercent,
    defaultDepositPercent: defaultDepositPercent == null
        ? this.defaultDepositPercent
        : defaultDepositPercent(),
    pixRate: pixRate == null ? this.pixRate : pixRate(),
    credit1xRate: credit1xRate == null ? this.credit1xRate : credit1xRate(),
    installmentRates: installmentRates ?? this.installmentRates,
    embedFeeInPrice: embedFeeInPrice ?? this.embedFeeInPrice,
    newApiKey: newApiKey == null ? this.newApiKey : newApiKey(),
    editingKey: editingKey ?? this.editingKey,
    submitted: submitted ?? this.submitted,
    loadError: loadError == null ? this.loadError : loadError(),
    saveError: saveError == null ? this.saveError : saveError(),
  );

  @override
  List<Object?> get props => [
    status,
    original,
    handle,
    enabled,
    assuredInstallments,
    pixDiscountPercent,
    defaultDepositPercent,
    pixRate,
    credit1xRate,
    installmentRates,
    embedFeeInPrice,
    newApiKey,
    editingKey,
    submitted,
    loadError,
    saveError,
  ];
}

/// Gerencia a conexão da empresa com a InfinitePay.
class PaymentSettingsCubit extends Cubit<PaymentSettingsState> {
  PaymentSettingsCubit(this._repo) : super(const PaymentSettingsState());

  final PaymentRepository _repo;

  Future<void> load() async {
    emit(
      state.copyWith(
        status: PaymentSettingsStatus.loading,
        loadError: () => null,
      ),
    );
    try {
      final settings = await _repo.getSettings();
      if (isClosed) return;
      emit(_applyLoaded(settings));
    } on ApiError catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: PaymentSettingsStatus.failure,
          loadError: () => friendlyPaymentError(e),
        ),
      );
    }
  }

  PaymentSettingsState _applyLoaded(PaymentSettings s) {
    final fees = s.feeRates;
    return PaymentSettingsState(
      status: PaymentSettingsStatus.ready,
      original: s,
      handle: s.handle ?? '',
      enabled: s.enabled,
      assuredInstallments: s.assuredInstallments,
      pixDiscountPercent: s.pixDiscountPercent,
      defaultDepositPercent: s.defaultDepositPercent,
      pixRate: fees?.pix,
      credit1xRate: fees?.credit1x,
      installmentRates: {
        for (final n in kFeeInstallments) n: fees?.creditInstallments[n],
      },
      embedFeeInPrice: s.embedFeeInPrice,
      // Sem credenciais, o campo de chave já abre em edição.
      editingKey: !s.connected,
    );
  }

  void setHandle(String value) =>
      emit(state.copyWith(handle: value, saveError: () => null));

  void setEnabled({required bool enabled}) =>
      emit(state.copyWith(enabled: enabled, saveError: () => null));

  // Os valores entram sem clamp: a validação é que sinaliza o que está fora da
  // faixa, para não "esconder" um erro de digitação do usuário.
  void setInstallments(int value) =>
      emit(state.copyWith(assuredInstallments: value, saveError: () => null));

  void setPixDiscount(int value) =>
      emit(state.copyWith(pixDiscountPercent: value, saveError: () => null));

  void setDefaultDeposit(double? value) => emit(
    state.copyWith(defaultDepositPercent: () => value, saveError: () => null),
  );

  // As taxas são arredondadas para 2 casas: a UI nunca guarda mais precisão do
  // que o contrato aceita.
  void setPixRate(double? value) => emit(
    state.copyWith(pixRate: () => roundFeeRate(value), saveError: () => null),
  );

  void setCredit1xRate(double? value) => emit(
    state.copyWith(
      credit1xRate: () => roundFeeRate(value),
      saveError: () => null,
    ),
  );

  void setInstallmentRate(int installments, double? value) {
    final next = Map<int, double?>.from(state.installmentRates)
      ..[installments] = roundFeeRate(value);
    emit(state.copyWith(installmentRates: next, saveError: () => null));
  }

  void setEmbedFeeInPrice({required bool embed}) =>
      emit(state.copyWith(embedFeeInPrice: embed, saveError: () => null));

  /// Começa a trocar a chave de API (campo passa a aceitar uma nova).
  void startEditingKey() =>
      emit(state.copyWith(editingKey: true, newApiKey: () => ''));

  void setApiKey(String value) =>
      emit(state.copyWith(newApiKey: () => value, saveError: () => null));

  /// Cancela a troca da chave, voltando a mostrar a mascarada.
  void cancelEditingKey() {
    if (!state.connected) return;
    emit(state.copyWith(editingKey: false, newApiKey: () => null));
  }

  /// Salva as configurações. Retorna `true` no sucesso. Bloqueia o envio
  /// enquanto houver erro de validação de campo.
  Future<bool> save() async {
    if (state.validate().isNotEmpty) {
      emit(state.copyWith(submitted: true, saveError: () => null));
      return false;
    }
    emit(
      state.copyWith(
        status: PaymentSettingsStatus.saving,
        submitted: true,
        saveError: () => null,
      ),
    );
    final key = (state.newApiKey ?? '').trim();
    final update = PaymentSettingsUpdate(
      // Handle é obrigatório e já validado como não-vazio: nunca enviamos null.
      handle: state.handle.trim(),
      apiKey: state.editingKey && key.isNotEmpty ? key : null,
      enabled: state.enabled,
      assuredInstallments: state.assuredInstallments,
      pixDiscountPercent: state.pixDiscountPercent,
      defaultDepositPercent: state.defaultDepositPercent,
      feeRates: state.buildFeeRates(),
      embedFeeInPrice: state.embedFeeInPrice,
    );
    try {
      final saved = await _repo.updateSettings(update);
      AppLogger.info('Pagamentos atualizados', category: 'payments');
      if (isClosed) return true;
      emit(_applyLoaded(saved));
      return true;
    } on ApiError catch (e) {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: PaymentSettingsStatus.ready,
            saveError: () => friendlyPaymentError(e),
          ),
        );
      }
      return false;
    }
  }

  /// Desconecta a integração. Retorna `true` no sucesso.
  Future<bool> disconnect() async {
    emit(
      state.copyWith(
        status: PaymentSettingsStatus.saving,
        saveError: () => null,
      ),
    );
    try {
      final result = await _repo.disconnect();
      AppLogger.info('Pagamentos desconectados', category: 'payments');
      if (isClosed) return true;
      // A resposta pode não trazer o estado completo: garantimos desconectado.
      emit(
        _applyLoaded(
          result.connected
              ? result.copyWith(connected: false, enabled: false)
              : result,
        ),
      );
      return true;
    } on ApiError catch (e) {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: PaymentSettingsStatus.ready,
            saveError: () => friendlyPaymentError(e),
          ),
        );
      }
      return false;
    }
  }
}
