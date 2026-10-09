import 'package:spooliq_desktop/core/network/api_client.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/network/json.dart';
import 'package:spooliq_desktop/features/subscription/domain/billing.dart';

class ApiBillingRepository implements BillingRepository {
  const ApiBillingRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Plan>> plans() async =>
      looseList(await _api.get('/plans', auth: false), Plan.fromJson, 'plans');

  @override
  Future<SubscriptionInfo?> status() async {
    try {
      final j = await _api.getJson('/subscriptions/status');
      return j.isEmpty ? null : SubscriptionInfo.fromJson(j.unwrapData());
    } on NotFoundError {
      return null;
    }
  }

  @override
  Future<List<PaymentMethod>> paymentMethods() async => looseList(
    await _api.get('/payment-methods'),
    PaymentMethod.fromJson,
    'payment_methods',
  );

  @override
  Future<PaymentMethod> addCard(NewCard c, {bool primary = true}) async =>
      PaymentMethod.fromJson(
        (await _api.postJson(
          '/payment-methods',
          body: {
            'holder_name': c.holderName.trim(),
            'number': c.number.replaceAll(RegExp(r'\D'), ''),
            'expiry_month': c.expiryMonth,
            'expiry_year': c.expiryYear,
            'ccv': c.ccv,
            'set_as_primary': primary,
          },
        )).unwrapData(),
      );

  @override
  Future<void> setPrimary(String id) =>
      _api.put('/payment-methods/$id/set-primary');

  @override
  Future<void> removeCard(String id) => _api.delete('/payment-methods/$id');

  @override
  Future<SubscriptionInfo> subscribe({
    required String planId,
    required BillingType type,
    String? paymentMethodId,
  }) async => SubscriptionInfo.fromJson(
    (await _api.postJson(
      '/subscriptions/subscribe',
      body: compactJson({
        'plan_id': planId,
        'billing_type': type.value,
        'payment_method_id': paymentMethodId,
      }),
    )).unwrapData(),
  );

  @override
  Future<void> cancel({required String reason, String? feedback}) =>
      _api.delete(
        '/subscriptions/cancel',
        body: compactJson({
          'reason': reason,
          'feedback': (feedback == null || feedback.trim().isEmpty)
              ? null
              : feedback.trim(),
        }),
      );

  @override
  Future<List<Payment>> payments() async => looseList(
    await _api.get('/company/subscription/payments'),
    Payment.fromJson,
    'payments',
  );
}
