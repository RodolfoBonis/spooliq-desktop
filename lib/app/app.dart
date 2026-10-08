import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:forma_theme_spooliq/forma_theme_spooliq.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:spooliq_desktop/app/theme_mode_cubit.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/routing/app_router.dart';
import 'package:spooliq_desktop/features/auth/presentation/session_cubit.dart';
import 'package:spooliq_desktop/features/company/presentation/current_company_cubit.dart';

class SpoolIqApp extends StatefulWidget {
  const SpoolIqApp({super.key});

  @override
  State<SpoolIqApp> createState() => _SpoolIqAppState();
}

class _SpoolIqAppState extends State<SpoolIqApp> {
  late final SessionCubit _session;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _session = SessionCubit(repository: di(), events: di());
    unawaited(_session.restore());
    _router = buildRouter(_session);
  }

  @override
  void dispose() {
    _router.dispose();
    unawaited(_session.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _session),
        BlocProvider(create: (_) => ThemeModeCubit(di())),
        BlocProvider(create: (_) => CurrentCompanyCubit(di())),
      ],
      child: BlocListener<SessionCubit, SessionState>(
        listenWhen: (a, b) => a.isAuthenticated && !b.isAuthenticated,
        listener: (context, _) => context.read<CurrentCompanyCubit>().clear(),
        child: BlocBuilder<ThemeModeCubit, ThemeMode>(
          builder: (context, mode) => MaterialApp.router(
            title: 'SpoolIQ',
            debugShowCheckedModeBanner: false,
            theme: SpooliqTheme.light,
            darkTheme: SpooliqTheme.dark,
            themeMode: mode,
            routerConfig: _router,
            locale: const Locale('pt', 'BR'),
            supportedLocales: const [Locale('pt', 'BR')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => SentryWidget(child: child!),
          ),
        ),
      ),
    );
  }
}
