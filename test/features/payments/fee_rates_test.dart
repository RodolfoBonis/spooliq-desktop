import 'package:flutter_test/flutter_test.dart';
import 'package:spooliq_desktop/features/payments/domain/payment_settings.dart';

void main() {
  group('FeeRates.fromJson', () {
    test('reads pix, credit à vista and the installment grid', () {
      final rates = FeeRates.fromJson(const {
        'pix': 0.0,
        'credit_1x': 4.2,
        'credit_installments': {'2': 5.4, '3': 6.1, '12': 15.9},
      });
      expect(rates.pix, 0.0);
      expect(rates.credit1x, 4.2);
      expect(rates.creditInstallments[2], 5.4);
      expect(rates.creditInstallments[3], 6.1);
      expect(rates.creditInstallments[12], 15.9);
      expect(rates.hasAny, isTrue);
    });

    test('an empty table reports hasAny == false', () {
      final rates = FeeRates.fromJson(const {});
      expect(rates.pix, isNull);
      expect(rates.credit1x, isNull);
      expect(rates.creditInstallments, isEmpty);
      expect(rates.hasAny, isFalse);
    });

    test('ignores installment keys that are not numbers', () {
      final rates = FeeRates.fromJson(const {
        'credit_installments': {'2': 5.4, 'x': 9.9},
      });
      expect(rates.creditInstallments.keys, [2]);
    });

    test('rateForInstallments uses credit à vista for N<=1', () {
      final rates = FeeRates.fromJson(const {
        'credit_1x': 4.2,
        'credit_installments': {'3': 6.1},
      });
      expect(rates.rateForInstallments(1), 4.2);
      expect(rates.rateForInstallments(0), 4.2);
      expect(rates.rateForInstallments(3), 6.1);
      // Parcela sem taxa cadastrada = desconhecida.
      expect(rates.rateForInstallments(6), isNull);
    });
  });

  group('FeeRates.toJson', () {
    test('includes informed rates (0 is valid) and omits nulls', () {
      final json = const FeeRates(
        pix: 0,
        credit1x: 4.2,
        creditInstallments: {3: 6.1},
      ).toJson();
      expect(json['pix'], 0);
      expect(json['credit_1x'], 4.2);
      expect(json['credit_installments'], {'3': 6.1});
    });

    test('drops a null pix/credit_1x', () {
      final json = const FeeRates(creditInstallments: {2: 5}).toJson();
      expect(json.containsKey('pix'), isFalse);
      expect(json.containsKey('credit_1x'), isFalse);
      expect(json['credit_installments'], {'2': 5});
    });
  });

  group('PaymentSettings.fromJson with fees', () {
    test('reads fee_rates and embed_fee_in_price', () {
      final s = PaymentSettings.fromJson(const {
        'connected': true,
        'enabled': true,
        'handle': 'loja',
        'assured_installments': 3,
        'fee_rates': {
          'pix': 0.0,
          'credit_1x': 4.2,
          'credit_installments': {'3': 6.1},
        },
        'embed_fee_in_price': true,
      });
      expect(s.feeRates, isNotNull);
      expect(s.embedFeeInPrice, isTrue);
      // Referência = crédito nas parcelas sem juros (3x).
      expect(s.referenceFeeRate, 6.1);
    });

    test('a missing fee_rates means not configured', () {
      final s = PaymentSettings.fromJson(const {
        'connected': true,
        'enabled': true,
        'handle': 'loja',
      });
      expect(s.feeRates, isNull);
      expect(s.embedFeeInPrice, isFalse);
      expect(s.referenceFeeRate, isNull);
    });
  });

  group('PaymentSettingsUpdate.toJson with fees', () {
    test('serializes fee_rates and embed_fee_in_price', () {
      final body = const PaymentSettingsUpdate(
        handle: 'loja',
        enabled: true,
        assuredInstallments: 3,
        pixDiscountPercent: 0,
        feeRates: FeeRates(
          pix: 0,
          credit1x: 4.2,
          creditInstallments: {3: 6.1},
        ),
        embedFeeInPrice: true,
      ).toJson();
      expect(body['embed_fee_in_price'], isTrue);
      expect(body['fee_rates'], {
        'pix': 0,
        'credit_1x': 4.2,
        'credit_installments': {'3': 6.1},
      });
    });

    test('sends fee_rates null when the table is empty', () {
      final body = const PaymentSettingsUpdate(
        handle: 'loja',
        enabled: true,
        assuredInstallments: 12,
        pixDiscountPercent: 0,
        feeRates: FeeRates(),
      ).toJson();
      expect(body.containsKey('fee_rates'), isTrue);
      expect(body['fee_rates'], isNull);
      expect(body['embed_fee_in_price'], isFalse);
    });
  });
}
