import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:spooliq_desktop/core/auth/credential_vault.dart';
import 'package:spooliq_desktop/core/auth/session_user.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/observability/app_logger.dart';
import 'package:spooliq_desktop/features/auth/domain/auth_repository.dart';

class LoginState extends Equatable {
  const LoginState({
    this.submitting = false,
    this.error,
    this.user,
    this.quickLoginLabel,
    this.savedEmail,
    this.remember = true,
  });

  final bool submitting;
  final String? error;
  final SessionUser? user;

  /// "Touch ID" / "Windows Hello"; null quando o login rápido não existe
  /// neste dispositivo.
  final String? quickLoginLabel;

  /// E-mail com credenciais lembradas (habilita o botão de login rápido).
  final String? savedEmail;

  /// Lembrar as credenciais no próximo login com senha.
  final bool remember;

  bool get canQuickLogin => quickLoginLabel != null && savedEmail != null;

  LoginState copyWith({
    bool? submitting,
    String? Function()? error,
    SessionUser? user,
    String? quickLoginLabel,
    String? Function()? savedEmail,
    bool? remember,
  }) {
    return LoginState(
      submitting: submitting ?? this.submitting,
      error: error != null ? error() : this.error,
      user: user ?? this.user,
      quickLoginLabel: quickLoginLabel ?? this.quickLoginLabel,
      savedEmail: savedEmail != null ? savedEmail() : this.savedEmail,
      remember: remember ?? this.remember,
    );
  }

  @override
  List<Object?> get props => [
    submitting,
    error,
    user,
    quickLoginLabel,
    savedEmail,
    remember,
  ];
}

class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._repository, this._vault) : super(const LoginState());

  final AuthRepository _repository;
  final CredentialVault _vault;

  /// Descobre se há login rápido disponível e credenciais lembradas.
  Future<void> load() async {
    final label = await _vault.methodLabel();
    if (label == null) {
      emit(state.copyWith(remember: false));
      return;
    }
    final email = await _vault.savedEmail();
    emit(state.copyWith(quickLoginLabel: label, savedEmail: () => email));
  }

  void setRemember({required bool value}) =>
      emit(state.copyWith(remember: value));

  Future<void> submit({required String email, required String password}) async {
    if (state.submitting) return;
    if (email.trim().isEmpty || password.isEmpty) {
      emit(state.copyWith(error: () => 'Informe e-mail e senha.'));
      return;
    }
    emit(state.copyWith(submitting: true, error: () => null));
    try {
      final user = await _repository.login(email: email, password: password);
      await _rememberOrForget(email: email.trim(), password: password);
      emit(state.copyWith(submitting: false, user: user));
    } on UnauthorizedError {
      emit(
        state.copyWith(
          submitting: false,
          error: () => 'E-mail ou senha incorretos.',
        ),
      );
    } on ApiError catch (e) {
      emit(state.copyWith(submitting: false, error: () => e.message));
    }
  }

  /// Login com Touch ID / Windows Hello usando as credenciais lembradas.
  Future<void> quickLogin() async {
    if (state.submitting || !state.canQuickLogin) return;
    final SavedCredentials? saved;
    try {
      saved = await _vault.unlock();
    } on VaultError catch (e) {
      AppLogger.info(
        'Login rápido indisponível: ${e.message}',
        category: 'auth',
      );
      emit(state.copyWith(error: () => e.message));
      return;
    }
    if (saved == null) return;

    emit(state.copyWith(submitting: true, error: () => null));
    try {
      final user = await _repository.login(
        email: saved.email,
        password: saved.password,
      );
      emit(state.copyWith(submitting: false, user: user));
    } on UnauthorizedError {
      // A senha mudou desde que foi lembrada: esquece e volta ao formulário.
      await _vault.clear();
      emit(
        state.copyWith(
          submitting: false,
          savedEmail: () => null,
          error: () =>
              'A senha salva não é mais válida. Entre com e-mail e senha.',
        ),
      );
    } on ApiError catch (e) {
      emit(state.copyWith(submitting: false, error: () => e.message));
    }
  }

  Future<void> _rememberOrForget({
    required String email,
    required String password,
  }) async {
    if (state.quickLoginLabel == null) return;
    try {
      if (state.remember) {
        await _vault.save(SavedCredentials(email: email, password: password));
      } else {
        await _vault.clear();
      }
    } on Exception catch (e) {
      // Lembrar é conveniência: uma falha no Keychain não bloqueia o login.
      AppLogger.warning(
        'Falha ao lembrar credenciais',
        category: 'auth',
        error: e,
      );
    }
  }
}
