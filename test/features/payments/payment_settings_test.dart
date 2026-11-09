import 'package:flutter_test/flutter_test.dart';
import 'package:spooliq_desktop/features/payments/domain/payment_settings.dart';

void main() {
  group('PaymentSettings.fromJson', () {
    test('reads the connected integration with last4 and pending links', () {
      final s = PaymentSettings.fromJson(const {
        'provider': 'infinitepay',
        'connected': true,
        'enabled': true,
        'handle': 'loja',
        'api_key_last4': '1234',
        'assured_installments': 6,
        'pix_discount_percent': 5,
        'default_deposit_percent': 50,
        'pending_links': 2,
      });
      expect(s.connected, isTrue);
      expect(s.enabled, isTrue);
      expect(s.isActive, isTrue);
      expect(s.maskedApiKey, '••••1234');
      expect(s.assuredInstallments, 6);
      expect(s.pixDiscountPercent, 5);
      expect(s.defaultDepositPercent, 50);
      expect(s.pendingLinks, 2);
    });

    test('defaults a disconnected integration', () {
      final s = PaymentSettings.fromJson(const {
        'provider': 'infinitepay',
        'connected': false,
        'enabled': false,
        'handle': '',
      });
      expect(s.connected, isFalse);
      expect(s.isActive, isFalse);
      expect(s.maskedApiKey, '');
      expect(s.defaultDepositPercent, isNull);
      expect(s.pendingLinks, 0);
    });

    test('derives connected from verified_at when the flag is absent', () {
      final s = PaymentSettings.fromJson(const {
        'enabled': true,
        'handle': 'loja',
        'verified_at': '2026-11-01T10:00:00Z',
      });
      expect(s.connected, isTrue);
    });
  });

  group('PaymentSettingsUpdate.toJson', () {
    test('omits api_key when null and sends default_deposit_percent null', () {
      final body = const PaymentSettingsUpdate(
        handle: 'loja',
        enabled: true,
        assuredInstallments: 6,
        pixDiscountPercent: 5,
      ).toJson();
      expect(body.containsKey('api_key'), isFalse);
      expect(body.containsKey('default_deposit_percent'), isTrue);
      expect(body['default_deposit_percent'], isNull);
      expect(body['handle'], 'loja');
      expect(body['enabled'], true);
    });

    test('omits api_key when blank', () {
      final body = const PaymentSettingsUpdate(
        handle: 'loja',
        apiKey: '   ',
        enabled: true,
        assuredInstallments: 12,
        pixDiscountPercent: 0,
      ).toJson();
      expect(body.containsKey('api_key'), isFalse);
    });

    test('sends a trimmed api_key and the deposit when present', () {
      final body = const PaymentSettingsUpdate(
        handle: 'loja',
        apiKey: '  sk_live_secret  ',
        enabled: true,
        assuredInstallments: 12,
        pixDiscountPercent: 0,
        defaultDepositPercent: 40,
      ).toJson();
      expect(body['api_key'], 'sk_live_secret');
      expect(body['default_deposit_percent'], 40);
    });
  });
}
