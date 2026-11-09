import 'package:flutter_test/flutter_test.dart';
import 'package:spooliq_desktop/features/payments/domain/payment_urls.dart';

void main() {
  group('isInfinitePayUrl', () {
    test('accepts https on infinitepay.io and subdomains', () {
      expect(isInfinitePayUrl('https://infinitepay.io/receipts/abc'), isTrue);
      expect(
        isInfinitePayUrl('https://checkout.infinitepay.io/links/x'),
        isTrue,
      );
    });

    test('is case-insensitive on the host', () {
      expect(isInfinitePayUrl('https://INFINITEPAY.IO/r/1'), isTrue);
      expect(isInfinitePayUrl('HTTPS://Checkout.InfinitePay.io/r'), isTrue);
    });

    test('rejects null, empty and malformed', () {
      expect(isInfinitePayUrl(null), isFalse);
      expect(isInfinitePayUrl(''), isFalse);
      expect(isInfinitePayUrl('not a url'), isFalse);
    });

    test('rejects non-https schemes', () {
      expect(isInfinitePayUrl('http://infinitepay.io/r/1'), isFalse);
      expect(isInfinitePayUrl('ftp://infinitepay.io/r/1'), isFalse);
    });

    test('rejects look-alike hosts', () {
      expect(isInfinitePayUrl('https://infinitepay.io.evil.com/r'), isFalse);
      expect(isInfinitePayUrl('https://evil-infinitepay.io/r'), isFalse);
      expect(isInfinitePayUrl('https://notinfinitepay.io/r'), isFalse);
    });

    test('rejects a trailing dot FQDN', () {
      expect(isInfinitePayUrl('https://infinitepay.io./r'), isFalse);
    });

    test('rejects embedded userinfo (host spoofing vector)', () {
      expect(isInfinitePayUrl('https://infinitepay.io@evil.com/r'), isFalse);
      expect(isInfinitePayUrl('https://evil.com@infinitepay.io/r'), isFalse);
    });
  });
}
