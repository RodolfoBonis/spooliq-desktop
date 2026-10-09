import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forma_theme_spooliq/forma_theme_spooliq.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spooliq_desktop/core/network/api_client.dart';
import 'package:spooliq_desktop/features/subscription/data/api_billing_repository.dart';
import 'package:spooliq_desktop/features/subscription/domain/billing.dart';
import 'package:spooliq_desktop/features/subscription/presentation/cancel_subscription_dialog.dart';

class _Billing extends Mock implements BillingRepository {}

class _Api extends Mock implements ApiClient {}

void main() {
  late _Billing billing;
  bool? result;

  setUp(() {
    billing = _Billing();
    result = null;
    when(
      () => billing.cancel(
        reason: any(named: 'reason'),
        feedback: any(named: 'feedback'),
      ),
    ).thenAnswer((_) async {});
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: SpooliqTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => unawaited(
                showCancelSubscriptionDialog(
                  context,
                  repository: billing,
                ).then((v) => result = v),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('explains the impact before asking for a reason', (
    tester,
  ) async {
    await open(tester);
    expect(find.textContaining('O cancelamento é imediato'), findsOneWidget);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Motivo'), findsOneWidget);
  });

  testWidgets('requires a reason and sends it with the feedback', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancelar assinatura').last);
    await tester.pump();
    expect(find.text('Selecione um motivo.'), findsOneWidget);
    verifyNever(
      () => billing.cancel(
        reason: any(named: 'reason'),
        feedback: any(named: 'feedback'),
      ),
    );

    await tester.tap(find.text('Selecione'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(CancelReason.tooExpensive.label).last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'caro demais');
    await tester.tap(find.text('Cancelar assinatura').last);
    await tester.pumpAndSettle();

    verify(
      () => billing.cancel(reason: 'too_expensive', feedback: 'caro demais'),
    ).called(1);
    expect(result, isTrue);
  });

  testWidgets('keeping the subscription returns false', (tester) async {
    await open(tester);
    await tester.tap(find.text('Manter assinatura'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  test('repository sends reason and trimmed feedback in the body', () async {
    final api = _Api();
    when(
      () => api.delete(any(), body: any(named: 'body')),
    ).thenAnswer((_) async => null);

    await ApiBillingRepository(
      api,
    ).cancel(reason: 'other', feedback: '  sem uso  ');

    verify(
      () => api.delete(
        '/subscriptions/cancel',
        body: {'reason': 'other', 'feedback': 'sem uso'},
      ),
    ).called(1);
  });
}
