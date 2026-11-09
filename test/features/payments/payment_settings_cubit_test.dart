import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/features/payments/domain/payment_repository.dart';
import 'package:spooliq_desktop/features/payments/domain/payment_settings.dart';
import 'package:spooliq_desktop/features/payments/presentation/payment_settings_cubit.dart';

class _Repo extends Mock implements PaymentRepository {}

void main() {
  late _Repo repo;

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

  setUp(() => repo = _Repo());

  const connected = PaymentSettings(
    handle: 'loja',
    enabled: true,
    connected: true,
    apiKeyLast4: '1234',
    assuredInstallments: 6,
    pixDiscountPercent: 5,
    defaultDepositPercent: 50,
    pendingLinks: 2,
  );

  blocTest<PaymentSettingsCubit, PaymentSettingsState>(
    'loads the settings and seeds the form',
    setUp: () =>
        when(() => repo.getSettings()).thenAnswer((_) async => connected),
    build: () => PaymentSettingsCubit(repo),
    act: (c) => c.load(),
    verify: (c) {
      expect(c.state.status, PaymentSettingsStatus.ready);
      expect(c.state.connected, isTrue);
      expect(c.state.maskedApiKey, '••••1234');
      expect(c.state.pendingLinks, 2);
      expect(c.state.handle, 'loja');
      expect(c.state.defaultDepositPercent, 50);
      // Conectada: a chave começa mascarada, sem edição.
      expect(c.state.editingKey, isFalse);
      expect(c.state.dirty, isFalse);
    },
  );

  blocTest<PaymentSettingsCubit, PaymentSettingsState>(
    'opens the key field in edit mode when not connected',
    setUp: () => when(
      () => repo.getSettings(),
    ).thenAnswer((_) async => const PaymentSettings()),
    build: () => PaymentSettingsCubit(repo),
    act: (c) => c.load(),
    verify: (c) => expect(c.state.editingKey, isTrue),
  );

  blocTest<PaymentSettingsCubit, PaymentSettingsState>(
    'surfaces a friendly message when the GET is unavailable (503)',
    setUp: () => when(
      () => repo.getSettings(),
    ).thenThrow(const ServerError('x', 503, 'payments_not_configured')),
    build: () => PaymentSettingsCubit(repo),
    act: (c) => c.load(),
    verify: (c) {
      expect(c.state.status, PaymentSettingsStatus.failure);
      expect(c.state.loadError, contains('indisponíveis'));
    },
  );

  blocTest<PaymentSettingsCubit, PaymentSettingsState>(
    'saves and only sends the api key while editing it',
    setUp: () {
      when(
        () => repo.getSettings(),
      ).thenAnswer((_) async => const PaymentSettings());
      when(() => repo.updateSettings(any())).thenAnswer(
        (_) async => const PaymentSettings(
          handle: 'loja',
          enabled: true,
          connected: true,
          apiKeyLast4: '9999',
        ),
      );
    },
    build: () => PaymentSettingsCubit(repo),
    act: (c) async {
      await c.load();
      c
        ..setHandle('loja')
        ..setApiKey('sk_live_secret')
        ..setEnabled(enabled: true);
      expect(await c.save(), isTrue);
    },
    verify: (c) {
      final captured =
          verify(() => repo.updateSettings(captureAny())).captured.single
              as PaymentSettingsUpdate;
      expect(captured.apiKey, 'sk_live_secret');
      expect(captured.handle, 'loja');
      expect(captured.enabled, isTrue);
      expect(c.state.connected, isTrue);
      expect(c.state.maskedApiKey, '••••9999');
      expect(c.state.editingKey, isFalse);
      expect(c.state.dirty, isFalse);
    },
  );

  blocTest<PaymentSettingsCubit, PaymentSettingsState>(
    'does not resend the key when connected and not editing',
    setUp: () {
      when(() => repo.getSettings()).thenAnswer((_) async => connected);
      when(() => repo.updateSettings(any())).thenAnswer((_) async => connected);
    },
    build: () => PaymentSettingsCubit(repo),
    act: (c) async {
      await c.load();
      c.setInstallments(10);
      await c.save();
    },
    verify: (c) {
      final captured =
          verify(() => repo.updateSettings(captureAny())).captured.single
              as PaymentSettingsUpdate;
      expect(captured.apiKey, isNull);
      expect(captured.assuredInstallments, 10);
    },
  );

  blocTest<PaymentSettingsCubit, PaymentSettingsState>(
    'maps 422 invalid credentials to a friendly message',
    setUp: () {
      when(
        () => repo.getSettings(),
      ).thenAnswer((_) async => const PaymentSettings());
      when(() => repo.updateSettings(any())).thenThrow(
        const BusinessError(
          'invalid',
          code: 'infinitepay_invalid_credentials',
          statusCode: 422,
        ),
      );
    },
    build: () => PaymentSettingsCubit(repo),
    act: (c) async {
      await c.load();
      c
        ..setHandle('loja')
        ..setApiKey('bad');
      expect(await c.save(), isFalse);
    },
    verify: (c) {
      expect(c.state.status, PaymentSettingsStatus.ready);
      expect(c.state.saveError, contains('inválida'));
    },
  );

  blocTest<PaymentSettingsCubit, PaymentSettingsState>(
    'maps a 503 on save to a friendly message',
    setUp: () {
      when(
        () => repo.getSettings(),
      ).thenAnswer((_) async => const PaymentSettings());
      when(
        () => repo.updateSettings(any()),
      ).thenThrow(const ServerError('x', 503));
    },
    build: () => PaymentSettingsCubit(repo),
    act: (c) async {
      await c.load();
      c
        ..setHandle('loja')
        ..setApiKey('k');
      expect(await c.save(), isFalse);
    },
    verify: (c) => expect(c.state.saveError, contains('indisponíveis')),
  );

  blocTest<PaymentSettingsCubit, PaymentSettingsState>(
    'disconnect resets to a disconnected, disabled state',
    setUp: () {
      when(() => repo.getSettings()).thenAnswer((_) async => connected);
      when(() => repo.disconnect()).thenAnswer(
        (_) async => const PaymentSettings(handle: 'loja'),
      );
    },
    build: () => PaymentSettingsCubit(repo),
    act: (c) async {
      await c.load();
      expect(await c.disconnect(), isTrue);
    },
    verify: (c) {
      expect(c.state.connected, isFalse);
      expect(c.state.enabled, isFalse);
      expect(c.state.editingKey, isTrue);
      verify(() => repo.disconnect()).called(1);
    },
  );
}
