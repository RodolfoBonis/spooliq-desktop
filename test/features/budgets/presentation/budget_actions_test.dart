import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spooliq_desktop/core/auth/session_user.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget.dart';
import 'package:spooliq_desktop/features/budgets/presentation/budget_actions.dart';

import '../../../helpers/fixtures.dart';

void main() {
  const user = SessionUser(
    id: 'u',
    email: 'a@b.c',
    name: 'Ana',
    organizationId: 'o',
    roles: {Role.owner},
    expiresAt: null,
  );

  Budget budget({required String status, required int balanceDue}) =>
      Budget.fromJson(
        budgetJson(status: status, balanceDue: balanceDue, amountPaid: 0),
      );

  testWidgets('canCopyPaymentLink gates on status, balance and integration', (
    tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox();
          },
        ),
      ),
    );

    BudgetActions actions({required bool enabled}) => BudgetActions(
      context: ctx,
      user: user,
      paymentsEnabled: enabled,
      onChanged: (_) {},
      onDeleted: (_) {},
    );

    final enabled = actions(enabled: true);
    final disabled = actions(enabled: false);

    // Aprovado, com saldo e integração ativa → pode copiar.
    expect(
      enabled.canCopyPaymentLink(budget(status: 'approved', balanceDue: 1000)),
      isTrue,
    );
    expect(
      enabled.canCopyPaymentLink(budget(status: 'printing', balanceDue: 500)),
      isTrue,
    );
    expect(
      enabled.canCopyPaymentLink(budget(status: 'completed', balanceDue: 200)),
      isTrue,
    );

    // Integração desligada → nunca.
    expect(
      disabled.canCopyPaymentLink(budget(status: 'approved', balanceDue: 1000)),
      isFalse,
    );

    // Sem saldo → não.
    expect(
      enabled.canCopyPaymentLink(budget(status: 'approved', balanceDue: 0)),
      isFalse,
    );

    // Status fora da faixa pagável → não.
    expect(
      enabled.canCopyPaymentLink(budget(status: 'sent', balanceDue: 1000)),
      isFalse,
    );
    expect(
      enabled.canCopyPaymentLink(budget(status: 'draft', balanceDue: 1000)),
      isFalse,
    );
  });
}
