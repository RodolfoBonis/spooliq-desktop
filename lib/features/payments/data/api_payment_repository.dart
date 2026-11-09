import 'package:spooliq_desktop/core/network/api_client.dart';
import 'package:spooliq_desktop/core/network/json.dart';
import 'package:spooliq_desktop/features/payments/domain/budget_payment.dart';
import 'package:spooliq_desktop/features/payments/domain/payment_repository.dart';
import 'package:spooliq_desktop/features/payments/domain/payment_settings.dart';

class ApiPaymentRepository implements PaymentRepository {
  const ApiPaymentRepository(this._api);

  final ApiClient _api;

  static const _settingsPath = '/company/payments/infinitepay';

  @override
  Future<PaymentSettings> getSettings() async =>
      PaymentSettings.fromJson(await _api.getJson(_settingsPath));

  @override
  Future<PaymentSettings> updateSettings(PaymentSettingsUpdate update) async =>
      PaymentSettings.fromJson(
        await _api.putJson(_settingsPath, body: update.toJson()),
      );

  @override
  Future<PaymentSettings> disconnect() async {
    final body = await _api.delete(_settingsPath);
    // A API pode responder 204 (sem corpo) ou o estado desconectado.
    return body is Map
        ? PaymentSettings.fromJson(Map<String, dynamic>.from(body))
        : const PaymentSettings();
  }

  @override
  Future<List<BudgetPayment>> budgetPayments(String budgetId) async {
    // `BudgetPaymentsResponse`: {status,total,paid,balance,deposit_percent,
    // payments:[...]}. A agregação (pago/saldo) vem do próprio orçamento; aqui
    // só interessam as linhas.
    final body = await _api.getJson('/budgets/$budgetId/payments');
    return body.list('payments', BudgetPayment.fromJson);
  }

  @override
  Future<PaymentLink> createBudgetPaymentLink(String budgetId) async =>
      PaymentLink.fromJson(
        await _api.postJson('/budgets/$budgetId/payments/link'),
      );
}
