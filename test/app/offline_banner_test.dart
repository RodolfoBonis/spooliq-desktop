import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forma_theme_spooliq/forma_theme_spooliq.dart';
import 'package:spooliq_desktop/app/shell/offline_banner.dart';
import 'package:spooliq_desktop/core/network/network_status.dart';

void main() {
  testWidgets('appears offline, retries and hides once back online', (
    tester,
  ) async {
    final status = NetworkStatus();
    var pings = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: SpooliqTheme.light,
        home: Scaffold(
          body: OfflineBanner(
            status: status,
            ping: () async {
              pings++;
              status.markOnline();
            },
          ),
        ),
      ),
    );
    expect(find.text('Tentar agora'), findsNothing);

    status.markOffline();
    await tester.pump();
    expect(find.text('Tentar agora'), findsOneWidget);

    await tester.tap(find.text('Tentar agora'));
    await tester.pump();
    expect(pings, 1);
    expect(find.text('Tentar agora'), findsNothing);
  });
}
