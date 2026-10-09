import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/core/observability/app_logger.dart';
import 'package:spooliq_desktop/features/notifications/domain/notification.dart';

class NotificationsState extends Equatable {
  const NotificationsState({
    this.unread = 0,
    this.items = const [],
    this.loading = false,
    this.error,
  });

  final int unread;

  /// Página mais recente (carregada ao abrir o painel).
  final List<AppNotification> items;
  final bool loading;
  final String? error;

  NotificationsState copyWith({
    int? unread,
    List<AppNotification>? items,
    bool? loading,
    String? Function()? error,
  }) => NotificationsState(
    unread: unread ?? this.unread,
    items: items ?? this.items,
    loading: loading ?? this.loading,
    error: error != null ? error() : this.error,
  );

  @override
  List<Object?> get props => [unread, items, loading, error];
}

/// Contador de não lidas (com polling) e lista do painel. Notificações novas
/// também aparecem como notificação nativa do sistema.
class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit(
    this._repo,
    this._notifier, {
    this.interval = const Duration(seconds: 60),
  }) : super(const NotificationsState());

  final NotificationRepository _repo;
  final SystemNotifier _notifier;
  final Duration interval;

  /// Abre o link de uma notificação (definido pelo shell, que tem o router).
  void Function(String link)? onOpen;

  Timer? _timer;
  bool _primed = false;
  final Set<String> _announced = {};

  void start() {
    _timer?.cancel();
    unawaited(poll());
    _timer = Timer.periodic(interval, (_) => unawaited(poll()));
  }

  /// Atualiza o contador; se subiu, anuncia as novas no sistema.
  Future<void> poll() async {
    try {
      final count = await _repo.unreadCount();
      if (isClosed) return;
      final grew = count > state.unread;
      emit(state.copyWith(unread: count));
      if (!_primed) {
        // Na abertura do app o badge basta: não dispara uma rajada de avisos.
        _primed = true;
        await _rememberUnread();
        return;
      }
      if (grew) await _announceNew();
    } on ApiError catch (e) {
      AppLogger.info('Falha ao consultar notificações: ${e.message}');
    }
  }

  Future<void> _rememberUnread() async {
    final page = await _repo.list(unreadOnly: true);
    _announced.addAll(page.items.map((n) => n.id));
  }

  Future<void> _announceNew() async {
    final page = await _repo.list(
      page: const PageQuery(pageSize: 10),
      unreadOnly: true,
    );
    for (final n in page.items.reversed) {
      if (!_announced.add(n.id)) continue;
      try {
        await _notifier.show(
          n.title,
          body: n.body,
          onClick: n.link == null ? null : () => onOpen?.call(n.link!),
        );
      } on Object catch (e, st) {
        // Sem permissão de notificação no sistema, por exemplo.
        unawaited(AppLogger.error(e, st, reason: 'system_notification'));
      }
    }
  }

  /// Carrega a lista do painel.
  Future<void> load() async {
    emit(state.copyWith(loading: true, error: () => null));
    try {
      final page = await _repo.list(page: const PageQuery(pageSize: 30));
      if (isClosed) return;
      emit(state.copyWith(items: page.items, loading: false));
    } on ApiError catch (e) {
      if (isClosed) return;
      emit(state.copyWith(loading: false, error: () => e.message));
    }
  }

  Future<void> markRead(AppNotification n) async {
    if (n.isRead) return;
    final now = DateTime.now();
    emit(
      state.copyWith(
        unread: state.unread > 0 ? state.unread - 1 : 0,
        items: [
          for (final i in state.items)
            if (i.id == n.id) i.markedRead(now) else i,
        ],
      ),
    );
    try {
      await _repo.markRead(n.id);
    } on ApiError catch (e) {
      AppLogger.info('Falha ao marcar notificação: ${e.message}');
    }
  }

  Future<void> markAllRead() async {
    final now = DateTime.now();
    emit(
      state.copyWith(
        unread: 0,
        items: [for (final i in state.items) i.markedRead(now)],
      ),
    );
    try {
      await _repo.markAllRead();
    } on ApiError catch (e) {
      AppLogger.info('Falha ao marcar notificações: ${e.message}');
      await poll();
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
