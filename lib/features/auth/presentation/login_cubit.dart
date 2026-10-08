import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:spooliq_desktop/core/auth/session_user.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/features/auth/domain/auth_repository.dart';

class LoginState extends Equatable {
  const LoginState({this.submitting = false, this.error, this.user});

  final bool submitting;
  final String? error;
  final SessionUser? user;

  @override
  List<Object?> get props => [submitting, error, user];
}

class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._repository) : super(const LoginState());

  final AuthRepository _repository;

  Future<void> submit({required String email, required String password}) async {
    if (state.submitting) return;
    if (email.trim().isEmpty || password.isEmpty) {
      emit(const LoginState(error: 'Informe e-mail e senha.'));
      return;
    }
    emit(const LoginState(submitting: true));
    try {
      final user = await _repository.login(email: email, password: password);
      emit(LoginState(user: user));
    } on UnauthorizedError {
      emit(const LoginState(error: 'E-mail ou senha incorretos.'));
    } on ApiError catch (e) {
      emit(LoginState(error: e.message));
    }
  }
}
