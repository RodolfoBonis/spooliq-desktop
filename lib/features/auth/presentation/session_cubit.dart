import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:spooliq_desktop/core/auth/session_user.dart';
import 'package:spooliq_desktop/core/network/session_events.dart';
import 'package:spooliq_desktop/features/auth/domain/auth_repository.dart';

enum SessionStatus { unknown, authenticated, unauthenticated }

/// Bloqueio do gate de assinatura (trial expirado, pagamento pendente…).
class SubscriptionBlock extends Equatable {
  const SubscriptionBlock({required this.code, required this.message});

  final String code;
  final String message;

  @override
  List<Object?> get props => [code, message];
}

class SessionState extends Equatable {
  const SessionState._({
    required this.status,
    this.user,
    this.expired = false,
    this.subscriptionBlock,
  });

  const SessionState.unknown() : this._(status: SessionStatus.unknown);

  const SessionState.authenticated(SessionUser user, {SubscriptionBlock? block})
    : this._(
        status: SessionStatus.authenticated,
        user: user,
        subscriptionBlock: block,
      );

  const SessionState.unauthenticated({bool expired = false})
    : this._(status: SessionStatus.unauthenticated, expired: expired);

  final SessionStatus status;
  final SessionUser? user;

  /// Saiu por expiração (mostra aviso na tela de login).
  final bool expired;
  final SubscriptionBlock? subscriptionBlock;

  bool get isAuthenticated => status == SessionStatus.authenticated;

  @override
  List<Object?> get props => [status, user, expired, subscriptionBlock];
}

/// Estado global de sessão. Escuta eventos da camada de rede.
class SessionCubit extends Cubit<SessionState> {
  SessionCubit({
    required AuthRepository repository,
    required SessionEvents events,
  }) : _repository = repository,
       super(const SessionState.unknown()) {
    _sub = events.stream.listen(_onEvent);
  }

  final AuthRepository _repository;
  late final StreamSubscription<SessionEvent> _sub;

  Future<void> restore() async {
    final user = await _repository.restore();
    _setUser(user);
    emit(
      user == null
          ? const SessionState.unauthenticated()
          : SessionState.authenticated(user),
    );
  }

  /// Chamado pelo LoginCubit após autenticar.
  void signedIn(SessionUser user) {
    _setUser(user);
    emit(SessionState.authenticated(user));
  }

  Future<void> logout() async {
    await _repository.logout();
    _setUser(null);
    emit(const SessionState.unauthenticated());
  }

  /// Reflete no shell o nome editado em "Meu perfil".
  void renamed(String name) {
    final current = state;
    final user = current.user;
    if (user == null) return;
    emit(
      SessionState.authenticated(
        user.withName(name),
        block: current.subscriptionBlock,
      ),
    );
  }

  void clearSubscriptionBlock() {
    final user = state.user;
    if (user != null) emit(SessionState.authenticated(user));
  }

  void _onEvent(SessionEvent event) {
    switch (event) {
      case SessionExpired():
        if (state.status != SessionStatus.authenticated) return;
        _setUser(null);
        emit(const SessionState.unauthenticated(expired: true));
      case SubscriptionBlocked(:final code, :final message):
        final user = state.user;
        if (user == null || user.isPlatformAdmin) return;
        emit(
          SessionState.authenticated(
            user,
            block: SubscriptionBlock(code: code, message: message),
          ),
        );
    }
  }

  void _setUser(SessionUser? user) {
    unawaited(
      Future.sync(
        () => Sentry.configureScope((scope) async {
          await scope.setUser(
            user == null
                ? null
                : SentryUser(
                    id: user.id,
                    data: {'organization_id': user.organizationId},
                  ),
          );
        }),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
