import 'package:flutter/foundation.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:spooliq_desktop/features/notifications/domain/notification.dart';

/// [SystemNotifier] com `local_notifier` (macOS e Windows).
class LocalSystemNotifier implements SystemNotifier {
  bool _ready = false;

  @override
  Future<void> show(String title, {String? body, VoidCallback? onClick}) async {
    if (!_ready) {
      await localNotifier.setup(
        appName: 'SpoolIQ',
        // O instalador já cria o atalho no menu Iniciar.
        shortcutPolicy: ShortcutPolicy.ignore,
      );
      _ready = true;
    }
    final notification = LocalNotification(title: title, body: body)
      ..onClick = onClick;
    await notification.show();
  }
}
