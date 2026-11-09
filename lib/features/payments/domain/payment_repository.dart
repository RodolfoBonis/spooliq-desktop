import 'package:spooliq_desktop/features/payments/domain/budget_payment.dart';
import 'package:spooliq_desktop/features/payments/domain/payment_settings.dart';

/// Integração de pagamentos (InfinitePay) por empresa e cobranças por
/// orçamento.
abstract interface class PaymentRepository {
  /// `GET /v1/company/payments/infinitepay`.
  Future<PaymentSettings> getSettings();

  /// `PUT /v1/company/payments/infinitepay`.
  Future<PaymentSettings> updateSettings(PaymentSettingsUpdate update);

  /// `DELETE /v1/company/payments/infinitepay` — desconecta, mantendo
  /// credenciais por 7 dias para confirmações atrasadas.
  Future<PaymentSettings> disconnect();

  /// `GET /v1/budgets/:id/payments`.
  Future<BudgetPaymentsResult> budgetPayments(String budgetId);

  /// `POST /v1/budgets/:id/payments/link` — gera ou reaproveita o link.
  Future<PaymentLink> createBudgetPaymentLink(String budgetId);
}
