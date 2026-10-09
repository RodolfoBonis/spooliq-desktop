import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spooliq_desktop/app/shell/app_menu_bar.dart';
import 'package:spooliq_desktop/core/auth/session_user.dart';

const _owner = SessionUser(
  id: 'u',
  email: 'a@b.c',
  name: 'Ana',
  organizationId: 'o',
  roles: {Role.owner},
  expiresAt: null,
);

Widget _app() => MaterialApp(
  home: AppMenuBar(
    user: _owner,
    onSearch: () {},
    child: const Text('conteúdo'),
  ),
);

void main() {
  testWidgets('builds the native menus on macOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.menu,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.menu,
        null,
      ),
    );

    await tester.pumpWidget(_app());

    final bar = tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar));
    expect(
      bar.menus.map((m) => (m as PlatformMenu).label),
      ['SpoolIQ', 'Arquivo', 'Ir', 'Visualizar', 'Janela'],
    );
    expect(calls.map((c) => c.method), contains('Menu.setMenus'));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('is a no-op on Windows', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.pumpWidget(_app());
    expect(find.byType(PlatformMenuBar), findsNothing);
    expect(find.text('conteúdo'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
