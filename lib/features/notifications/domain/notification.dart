import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:spooliq_desktop/core/network/json.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';

/// Notificação do app (`GET /notifications`).
class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.link,
    this.readAt,
    this.createdAt,
  });

  factory AppNotification.fromJson(Json json) => AppNotification(
    id: json.str('id'),
    type: json.str('type'),
    title: json.str('title'),
    body: json.strOrNull('body'),
    link: json.strOrNull('link'),
    readAt: json.date('read_at'),
    createdAt: json.date('created_at'),
  );

  final String id;
  final String type;
  final String title;
  final String? body;

  /// Rota do app (ex.: `/budgets/<id>`).
  final String? link;
  final DateTime? readAt;
  final DateTime? createdAt;

  bool get isRead => readAt != null;

  IconData get icon => switch (type) {
    'budget_approved' => Icons.check_circle_outline,
    'budget_rejected' => Icons.cancel_outlined,
    'budget_expired' => Icons.timer_off_outlined,
    'low_stock' => Icons.inventory_2_outlined,
    'payment_overdue' => Icons.warning_amber_rounded,
    'payment_received' => Icons.payments_outlined,
    _ => Icons.notifications_none_rounded,
  };

  AppNotification markedRead(DateTime at) => AppNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    link: link,
    readAt: readAt ?? at,
    createdAt: createdAt,
  );

  @override
  List<Object?> get props => [id, readAt];
}

abstract interface class NotificationRepository {
  Future<Paginated<AppNotification>> list({
    PageQuery page = const PageQuery(),
    bool unreadOnly = false,
  });
  Future<int> unreadCount();
  Future<void> markRead(String id);
  Future<void> markAllRead();
}

/// Notificação nativa do sistema (Central de Notificações / Windows).
// Interface (e não função) para trocar a implementação nos testes.
// ignore: one_member_abstracts
abstract interface class SystemNotifier {
  Future<void> show(String title, {String? body, VoidCallback? onClick});
}
