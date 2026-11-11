import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forma_theme_spooliq/forma_theme_spooliq.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/features/payments/domain/payment_repository.dart';
import 'package:spooliq_desktop/features/payments/domain/payment_settings.dart';
import 'package:spooliq_desktop/features/payments/presentation/payment_settings_cubit.dart';
import 'package:spooliq_desktop/features/payments/presentation/payment_settings_page.dart';

class _Repo extends Mock implements PaymentRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const PaymentSettingsUpdate(
        handle: 'x',
        enabled: false,
        assuredInstallments: 12,
        pixDiscountPercent: 0,
      ),
    );
  });

  late _Repo repo;

  setUp(() {
    repo = _Repo();
    when(repo.getSettings).thenAnswer(
      (_) async => const PaymentSettings(
        handle: 'loja',
        enabled: true,
        connected: true,
        apiKeyLast4: '1234',
        assuredInstallments: 3,
      ),
    );
    di
      ..allowReassignment = true
      ..registerSingleton<PaymentRepository>(repo);
  });

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: SpooliqTheme.light,
        home: const Scaffold(body: PaymentSettingsPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Finder editableFor(String key) => find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(EditableText),
  );

  // Dispara o save pelo cubit: a barra de salvar fica ancorada no rodapé e sai
  // da tela nos testes, mas o caminho de validação é o mesmo do botão.
  Future<bool> trySave(WidgetTester tester) {
    // Lê o cubit por um descendente: o provider é criado dentro da página.
    final context = tester.element(find.byKey(const ValueKey('fee-pix')));
    return context.read<PaymentSettingsCubit>().save();
  }

  testWidgets('typing 40 in a fee field shows an error and blocks save', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.enterText(editableFor('fee-pix'), '40');
    await tester.pump(const Duration(milliseconds: 250));

    expect(await trySave(tester), isFalse);
    await tester.pump();

    expect(find.textContaining('entre 0 e 30%'), findsWidgets);
    verifyNever(() => repo.updateSettings(any()));
  });

  testWidgets('an invalid installment is listed in the grid summary', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.enterText(editableFor('fee-credit-3'), '40');
    await tester.pump(const Duration(milliseconds: 250));

    expect(await trySave(tester), isFalse);
    await tester.pump();

    expect(find.textContaining('Taxas inválidas em 3x'), findsOneWidget);
    verifyNever(() => repo.updateSettings(any()));
  });
}
