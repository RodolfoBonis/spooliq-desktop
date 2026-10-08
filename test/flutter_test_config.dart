import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Auto-loaded before every test file in this package.
///
/// Disables Google Fonts runtime fetching so widget tests never make network
/// calls (which fail in CI and trigger "test failed after it had already
/// completed" errors).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
