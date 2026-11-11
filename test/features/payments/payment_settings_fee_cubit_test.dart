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

  // Empresa conectada que absorve até 3x, sem tabela de taxas cadastrada.
  const connected = PaymentSettings(
    handle: 'loja',
    enabled: true,
    connected: true,
    apiKeyLast4: '1234',
    assuredInstallments: 3,
  );

  test('friendlyPaymentError maps payment_fee_rate_missing', () {
    expect(
      friendlyPaymentError(
        const BusinessError(
          'missing',
          code: 'payment_fee_rate_missing',
          statusCode: 422,
        ),
      ),
      contains('Cadastre a taxa'),
    );
  });

  test('friendlyPaymentError maps payment_fee_rate_invalid', () {
    expect(
      friendlyPaymentError(
        const BusinessError(
          'invalid',
          code: 'payment_fee_rate_invalid',
          statusCode: 422,
        ),
      ),
      'Alguma taxa está fora do limite (0 a 30%) ou tem mais de 2 casas '
      'decimais.',
    );
  });

  blocTest<PaymentSettingsCubit, PaymentSettingsState>(
    'seeds the fee form from the loaded table',
    setUp: () => when(() => repo.getSettings()).thenAnswer(
      (_) async => connected.copyWith(
        feeRates: () => const FeeRates(
          pix: 0,
          credit1x: 4.2,
          creditInstallments: {3: 6.1},
        ),
        embedFeeInPrice: true,
      ),
    ),
    build: () => PaymentSettingsCubit(repo),
    act: (c) => c.load(),
    verify: (c) {
      expect(c.state.pixRate, 0);
      expect(c.state.credit1xRate, 4.2);
      expect(c.state.installmentRates[3], 6.1);
      expect(c.state.embedFeeInPrice, isTrue);
      // Referência = crédito em 3x (parcelas sem juros).
      expect(c.state.referenceFeeRate, 6.1);
      expect(c.state.dirty, isFalse);
    },
  );

  blocTest<PaymentSettingsCubit, PaymentSettingsState>(
    'serializes the fee table and embed flag on save',
    setUp: () {
      when(() => repo.getSettings()).thenAnswer((_) async => connected);
      when(() => repo.updateSettings(any())).thenAnswer((_) async => connected);
    },
    build: () => PaymentSettingsCubit(repo),
    act: (c) async {
      await c.load();
      c
        ..setPixRate(0)
        ..setCredit1xRate(4.2)
        ..setInstallmentRate(3, 6.1)
        ..setEmbedFeeInPrice(embed: true);
      await c.save();
    },
    verify: (c) {
      final update =
          verify(() => repo.updateSettings(captureAny())).captured.single
              as PaymentSettingsUpdate;
      expect(update.embedFeeInPrice, isTrue);
      final json = update.toJson();
      expect(json['embed_fee_in_price'], isTrue);
      expect(json['fee_rates'], {
        'pix': 0,
        'credit_1x': 4.2,
        'credit_installments': {'3': 6.1},
      });
    },
  );

  blocTest<PaymentSettingsCubit, PaymentSettingsState>(
    'blocks save when embed is on but the reference rate is missing',
    setUp: () =>
        when(() => repo.getSettings()).thenAnswer((_) async => connected),
    build: () => PaymentSettingsCubit(repo),
    act: (c) async {
      await c.load();
      // Liga o interruptor sem cadastrar a taxa de 3x (parcelas sem juros).
      c.setEmbedFeeInPrice(embed: true);
      expect(await c.save(), isFalse);
    },
    verify: (c) {
      expect(c.state.errors, containsPair('embed_fee', contains('3x')));
      verifyNever(() => repo.updateSettings(any()));
    },
  );

  blocTest<PaymentSettingsCubit, PaymentSettingsState>(
    'allows embed once the reference rate exists',
    setUp: () {
      when(() => repo.getSettings()).thenAnswer((_) async => connected);
      when(() => repo.updateSettings(any())).thenAnswer((_) async => connected);
    },
    build: () => PaymentSettingsCubit(repo),
    act: (c) async {
      await c.load();
      c
        ..setInstallmentRate(3, 6.1)
        ..setEmbedFeeInPrice(embed: true);
      expect(await c.save(), isTrue);
    },
    verify: (c) {
      expect(c.state.errors, isEmpty);
      verify(() => repo.updateSettings(any())).called(1);
    },
  );

  blocTest<PaymentSettingsCubit, PaymentSettingsState>(
    'rejects an out-of-range fee',
    setUp: () =>
        when(() => repo.getSettings()).thenAnswer((_) async => connected),
    build: () => PaymentSettingsCubit(repo),
    act: (c) async {
      await c.load();
      c.setPixRate(40);
      expect(await c.save(), isFalse);
    },
    verify: (c) {
      expect(c.state.errors, containsPair('fee_pix', isA<String>()));
      verifyNever(() => repo.updateSettings(any()));
    },
  );

  blocTest<PaymentSettingsCubit, PaymentSettingsState>(
    'maps a 422 payment_fee_rate_missing from the server to a friendly error',
    setUp: () {
      when(() => repo.getSettings()).thenAnswer((_) async => connected);
      when(() => repo.updateSettings(any())).thenThrow(
        const BusinessError(
          'missing',
          code: 'payment_fee_rate_missing',
          statusCode: 422,
        ),
      );
    },
    build: () => PaymentSettingsCubit(repo),
    act: (c) async {
      await c.load();
      // Passa na validação local (taxa existe), mas o backend recusa.
      c
        ..setInstallmentRate(3, 6.1)
        ..setEmbedFeeInPrice(embed: true);
      expect(await c.save(), isFalse);
    },
    verify: (c) => expect(c.state.saveError, contains('Cadastre a taxa')),
  );

  blocTest<PaymentSettingsCubit, PaymentSettingsState>(
    'rounds fee rates to 2 decimals in the setters',
    setUp: () =>
        when(() => repo.getSettings()).thenAnswer((_) async => connected),
    build: () => PaymentSettingsCubit(repo),
    act: (c) async {
      await c.load();
      c
        ..setPixRate(4.567)
        ..setCredit1xRate(4.999)
        ..setInstallmentRate(3, 6.001);
    },
    verify: (c) {
      expect(c.state.pixRate, 4.57);
      expect(c.state.credit1xRate, 5.0);
      expect(c.state.installmentRates[3], 6.0);
    },
  );

  test('validate() rejects more than 2 decimals', () {
    const state = PaymentSettingsState(
      status: PaymentSettingsStatus.ready,
      original: connected,
      handle: 'loja',
      pixRate: 4.999,
    );
    expect(
      state.validate(),
      containsPair('fee_pix', 'Use no máximo 2 casas decimais.'),
    );
  });

  blocTest<PaymentSettingsCubit, PaymentSettingsState>(
    're-checks the reference rate when the installments change with embed on',
    setUp: () =>
        when(() => repo.getSettings()).thenAnswer((_) async => connected),
    build: () => PaymentSettingsCubit(repo),
    act: (c) async {
      await c.load();
      // 3x cadastrada e embute: válido enquanto as parcelas sem juros são 3.
      c
        ..setInstallmentRate(3, 6.1)
        ..setEmbedFeeInPrice(embed: true);
      expect(c.state.validate(), isEmpty);
      // Passa a absorver até 6x, sem taxa de 6x → referência some.
      c.setInstallments(6);
    },
    verify: (c) {
      expect(c.state.referenceFeeRate, isNull);
      expect(c.state.validate(), containsPair('embed_fee', contains('6x')));
    },
  );
}
