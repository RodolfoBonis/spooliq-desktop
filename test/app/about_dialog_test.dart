import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forma_theme_spooliq/forma_theme_spooliq.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:spooliq_desktop/app/shell/about_dialog.dart';
import 'package:spooliq_desktop/core/config/app_config.dart';
import 'package:spooliq_desktop/core/di/injector.dart';

void main() {
  testWidgets('shows version, build and environment', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'SpoolIQ',
      packageName: 'spooliq_desktop',
      version: '0.2.0',
      buildNumber: '7',
      buildSignature: '',
    );
    di
      ..allowReassignment = true
      ..registerSingleton<AppConfig>(
        AppConfig.forFlavor(Flavor.production),
      );

    await tester.pumpWidget(
      MaterialApp(
        theme: SpooliqTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => unawaited(showAboutSpoolIQ(context)),
              child: const Text('sobre'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('sobre'));
    await tester.pumpAndSettle();

    expect(find.text('0.2.0 (7)'), findsOneWidget);
    expect(find.text('production'), findsOneWidget);
  });
}
