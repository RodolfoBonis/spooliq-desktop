import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:spooliq_desktop/core/config/app_config.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/observability/app_bloc_observer.dart';
import 'package:window_manager/window_manager.dart';

Future<void> bootstrap(
  Widget Function() builder, {
  required Flavor flavor,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.forFlavor(flavor);

  // Inter vem empacotada em assets/fonts — nada de download em runtime.
  GoogleFonts.config.allowRuntimeFetching = false;
  Intl.defaultLocale = 'pt_BR';
  await initializeDateFormatting('pt_BR');

  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      title: 'SpoolIQ',
      size: Size(1440, 900),
      minimumSize: Size(1200, 760),
      center: true,
      titleBarStyle: TitleBarStyle.normal,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );

  await configureDependencies(config);
  Bloc.observer = const AppBlocObserver();

  Future<void> run() async => runApp(builder());

  if (!config.hasSentry) {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
    };
    await run();
    return;
  }

  await SentryFlutter.init(
    (o) => o
      ..dsn = config.sentryDsn
      ..environment = config.environment
      ..tracesSampleRate = kReleaseMode ? 0.2 : 1.0
      ..sendDefaultPii = false
      ..attachScreenshot = false,
    appRunner: run,
  );
}
