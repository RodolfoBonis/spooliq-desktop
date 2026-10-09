import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Auto-loaded before every test file in this package.
///
/// Disables Google Fonts runtime fetching so widget tests never make network
/// calls (which fail in CI and trigger "test failed after it had already
/// completed" errors), and sets up pt-BR formatting like `bootstrap.dart`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  Intl.defaultLocale = 'pt_BR';
  await initializeDateFormatting('pt_BR');
  await testMain();
}
