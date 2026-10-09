import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:spooliq_desktop/core/format/formatters.dart';
import 'package:spooliq_desktop/core/ui/feedback.dart';
import 'package:spooliq_desktop/features/notifications/domain/notification.dart';
import 'package:spooliq_desktop/features/notifications/presentation/notifications_cubit.dart';

/// Sino da barra superior com o contador de não lidas.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final unread = context.select<NotificationsCubit, int>(
      (c) => c.state.unread,
    );
    return Tooltip(
      message: unread == 0 ? 'Notificações' : '$unread não lida(s)',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          FormaIconButton(
            icon: Icon(
              unread == 0
                  ? Icons.notifications_none_rounded
                  : Icons.notifications_active_outlined,
              size: 20,
            ),
            onPressed: () => unawaited(_open(context)),
          ),
          if (unread > 0)
            Positioned(
              right: 2,
              top: 2,
              child: IgnorePointer(
                child: Container(
                  constraints: const BoxConstraints(minWidth: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: ext.primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    textAlign: TextAlign.center,
                    style: typo.caption12.copyWith(
                      color: Colors.white,
                      fontSize: 10,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context) {
    final cubit = context.read<NotificationsCubit>();
    unawaited(cubit.load());
    return FormaSideSheet.show<void>(
      context,
      width: 440,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _NotificationsSheet(
          onOpen: (link) {
            Navigator.of(context).pop();
            context.go(link);
          },
        ),
      ),
    );
  }
}

class _NotificationsSheet extends StatelessWidget {
  const _NotificationsSheet({required this.onOpen});

  final void Function(String link) onOpen;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<NotificationsCubit>().state;
    final cubit = context.read<NotificationsCubit>();
    return FormaSideSheetScaffold(
      title: 'Notificações',
      subtitle: state.unread == 0
          ? 'Tudo em dia'
          : '${state.unread} não lida(s)',
      body: switch (state) {
        NotificationsState(loading: true, items: []) => const LoadingView(),
        NotificationsState(:final error?, items: []) => ErrorView(
          message: error,
          onRetry: () => unawaited(cubit.load()),
        ),
        NotificationsState(items: []) => const FormaEmptyState(
          icon: Icons.notifications_off_outlined,
          title: 'Nenhuma notificação',
          message:
              'Aprovações de clientes, estoque baixo e avisos da '
              'assinatura aparecem aqui.',
        ),
        _ => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.unread > 0)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => unawaited(cubit.markAllRead()),
                  icon: const Icon(Icons.done_all_rounded, size: 16),
                  label: const Text('Marcar todas como lidas'),
                ),
              ),
            for (final n in state.items)
              _NotificationTile(
                notification: n,
                onTap: () {
                  unawaited(cubit.markRead(n));
                  if (n.link != null) onOpen(n.link!);
                },
              ),
          ],
        ),
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final n = notification;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              n.icon,
              size: 18,
              color: n.isRead ? ext.textHint : ext.primaryColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    style: (n.isRead ? typo.body14 : typo.body14Medium)
                        .copyWith(
                          color: ext.textPrimary,
                        ),
                  ),
                  if (n.body != null && n.body!.isNotEmpty)
                    Text(
                      n.body!,
                      style: typo.body13.copyWith(color: ext.textMuted),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    Fmt.relative(n.createdAt),
                    style: typo.caption12.copyWith(color: ext.textHint),
                  ),
                ],
              ),
            ),
            if (!n.isRead)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 8),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: ext.primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
