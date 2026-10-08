import 'dart:async';

import 'package:equatable/equatable.dart';

/// Eventos globais de sessão emitidos pela camada de rede.
sealed class SessionEvent extends Equatable {
  const SessionEvent();

  @override
  List<Object?> get props => [];
}

/// Refresh falhou ou não é possível: precisa logar de novo.
final class SessionExpired extends SessionEvent {
  const SessionExpired();
}

/// Gate de assinatura bloqueou a requisição (402/403).
final class SubscriptionBlocked extends SessionEvent {
  const SubscriptionBlocked({required this.code, required this.message});

  final String code;
  final String message;

  @override
  List<Object?> get props => [code, message];
}

/// Barramento simples (broadcast) entre a rede e o estado de sessão.
class SessionEvents {
  final _controller = StreamController<SessionEvent>.broadcast();

  Stream<SessionEvent> get stream => _controller.stream;

  void emit(SessionEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }

  Future<void> dispose() => _controller.close();
}
