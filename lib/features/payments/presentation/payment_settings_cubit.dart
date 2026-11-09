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
const _unavailableMessage =
    'Os pagamentos estão indisponíveis no momento. Tente novamente em '
    'instantes.';

String friendlyPaymentError(ApiError error) {
  if (error.code == 'infinitepay_invalid_credentials' ||
      error.statusCode == 422) {
    return _invalidCredentialsMessage;
  }
  if (error.statusCode == 503 || error.code == 'payments_not_configured') {
    return _unavailableMessage;
  }
  return error.message;
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
    this.newApiKey,
    this.editingKey = false,
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
  final double pixDiscountPercent;
  final double? defaultDepositPercent;

  /// Nova chave digitada; `null` = manter a atual.
  final String? newApiKey;

  /// O campo de chave está em modo de edição (sempre quando desconectada).
  final bool editingKey;

  final String? loadError;
  final String? saveError;

  bool get connected => original?.connected ?? false;
  int get pendingLinks => original?.pendingLinks ?? 0;
  String get maskedApiKey => original?.maskedApiKey ?? '';

  bool get dirty {
    final o = original;
    if (o == null) return false;
    if ((newApiKey ?? '').trim().isNotEmpty) return true;
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
    double? pixDiscountPercent,
    double? Function()? defaultDepositPercent,
    String? Function()? newApiKey,
    bool? editingKey,
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
    newApiKey: newApiKey == null ? this.newApiKey : newApiKey(),
    editingKey: editingKey ?? this.editingKey,
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
    newApiKey,
    editingKey,
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

  PaymentSettingsState _applyLoaded(PaymentSettings s) => PaymentSettingsState(
    status: PaymentSettingsStatus.ready,
    original: s,
    handle: s.handle ?? '',
    enabled: s.enabled,
    assuredInstallments: s.assuredInstallments,
    pixDiscountPercent: s.pixDiscountPercent,
    defaultDepositPercent: s.defaultDepositPercent,
    // Sem credenciais, o campo de chave já abre em edição.
    editingKey: !s.connected,
  );

  void setHandle(String value) =>
      emit(state.copyWith(handle: value, saveError: () => null));

  void setEnabled({required bool enabled}) =>
      emit(state.copyWith(enabled: enabled, saveError: () => null));

  void setInstallments(int value) => emit(
    state.copyWith(
      assuredInstallments: value.clamp(1, 12),
      saveError: () => null,
    ),
  );

  void setPixDiscount(double value) => emit(
    state.copyWith(
      pixDiscountPercent: value.clamp(0, 30),
      saveError: () => null,
    ),
  );

  void setDefaultDeposit(double? value) => emit(
    state.copyWith(
      defaultDepositPercent: () => value,
      saveError: () => null,
    ),
  );

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

  /// Salva as configurações. Retorna `true` no sucesso.
  Future<bool> save() async {
    emit(
      state.copyWith(
        status: PaymentSettingsStatus.saving,
        saveError: () => null,
      ),
    );
    final update = PaymentSettingsUpdate(
      handle: state.handle.trim().isEmpty ? null : state.handle.trim(),
      apiKey: state.editingKey ? state.newApiKey : null,
      enabled: state.enabled,
      assuredInstallments: state.assuredInstallments,
      pixDiscountPercent: state.pixDiscountPercent,
      defaultDepositPercent: state.defaultDepositPercent,
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
