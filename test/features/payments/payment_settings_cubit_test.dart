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

  group('friendlyPaymentError', () {
    test('invalid credentials only for the specific code', () {
      expect(
        friendlyPaymentError(
          const BusinessError(
            'recusada',
            code: 'infinitepay_invalid_credentials',
            statusCode: 422,
          ),
        ),
        contains('inválida'),
      );
    });

    test('api_key_required maps to the "informe a chave" message', () {
      expect(
        friendlyPaymentError(
          const BusinessError(
            'faltou',
            code: 'api_key_required',
            statusCode: 422,
          ),
        ),
        'Informe a chave de API.',
      );
    });

    test('any other 422 shows the API message', () {
      expect(
        friendlyPaymentError(
          const BusinessError(
            'Handle inválido',
            code: 'validation_error',
            statusCode: 422,
          ),
        ),
        'Handle inválido',
      );
    });

    test('503 maps to the unavailable message', () {
      expect(
        friendlyPaymentError(const ServerError('x', 503)),
        contains('indisponíveis'),
      );
      expect(
        friendlyPaymentError(
          const ServerError('x', 503, 'payments_not_configured'),
        ),
        contains('indisponíveis'),
      );
    });
  });

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
      expect(c.state.editingKey, isFalse);
      expect(c.state.dirty, isFalse);
      expect(c.state.errors, isEmpty);
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
    'blocks save and shows field errors when invalid',
    setUp: () => when(
      () => repo.getSettings(),
    ).thenAnswer((_) async => const PaymentSettings()),
    build: () => PaymentSettingsCubit(repo),
    act: (c) async {
      await c.load();
      // Nada preenchido: handle e chave obrigatórios.
      expect(await c.save(), isFalse);
    },
    verify: (c) {
      expect(c.state.errors, containsPair('handle', isA<String>()));
      expect(c.state.errors, containsPair('api_key', isA<String>()));
      verifyNever(() => repo.updateSettings(any()));
    },
  );

  blocTest<PaymentSettingsCubit, PaymentSettingsState>(
    'rejects a too-short api key and an out-of-range deposit',
    setUp: () => when(
      () => repo.getSettings(),
    ).thenAnswer((_) async => const PaymentSettings()),
    build: () => PaymentSettingsCubit(repo),
    act: (c) async {
      await c.load();
      c
        ..setHandle('loja')
        ..setApiKey('short')
        ..setDefaultDeposit(150);
      expect(await c.save(), isFalse);
    },
    verify: (c) {
      expect(c.state.errors, containsPair('api_key', isA<String>()));
      expect(c.state.errors, containsPair('deposit', isA<String>()));
      verifyNever(() => repo.updateSettings(any()));
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
    'clearing the default deposit sends an explicit null',
    setUp: () {
      when(() => repo.getSettings()).thenAnswer((_) async => connected);
      when(() => repo.updateSettings(any())).thenAnswer(
        (_) async => connected.copyWith(defaultDepositPercent: () => null),
      );
    },
    build: () => PaymentSettingsCubit(repo),
    act: (c) async {
      await c.load();
      c.setDefaultDeposit(null);
      expect(await c.save(), isTrue);
    },
    verify: (c) {
      final captured =
          verify(() => repo.updateSettings(captureAny())).captured.single
              as PaymentSettingsUpdate;
      expect(captured.defaultDepositPercent, isNull);
      expect(c.state.defaultDepositPercent, isNull);
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
        ..setApiKey('invalidkey');
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
        ..setApiKey('a_valid_key');
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
