import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forma_theme_spooliq/forma_theme_spooliq.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spooliq_desktop/core/auth/session_user.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/features/auth/presentation/session_cubit.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_repository.dart';
import 'package:spooliq_desktop/features/budgets/presentation/detail/budget_detail_page.dart';
import 'package:spooliq_desktop/features/payments/domain/budget_payment.dart';
import 'package:spooliq_desktop/features/payments/domain/payment_repository.dart';
import 'package:spooliq_desktop/features/payments/domain/payment_settings.dart';

import '../../../helpers/fixtures.dart';

class _Budgets extends Mock implements BudgetRepository {}

class _Payments extends Mock implements PaymentRepository {}

class _Session extends Mock implements SessionCubit {}

void main() {
  setUpAll(() => registerFallbackValue(const PageQuery()));

  testWidgets('payment card shows overpaid and paid-after-cancel notes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final budgets = _Budgets();
    final payments = _Payments();
    when(() => budgets.get('b-1')).thenAnswer(
      (_) async => Budget.fromJson(
        budgetJson(
          status: 'cancelled',
          total: 2000,
          paymentStatus: 'partial',
          amountPaid: 3000,
          balanceDue: 0,
        ),
      ),
    );
    when(
      () => budgets.history('b-1'),
    ).thenAnswer((_) async => const Paginated.empty());
    when(() => payments.budgetPayments('b-1')).thenAnswer(
      (_) async => [
        BudgetPayment.fromJson(const {
          'kind': 'full',
          'amount': 2000,
          'paid_amount': 3000,
          'capture_method': 'credit_card',
          'installments': 3,
          'status': 'paid',
          'status_reason': 'paid_after_cancel',
          'receipt_url': 'https://infinitepay.io/r/1',
        }),
      ],
    );
    when(
      payments.getSettings,
    ).thenAnswer((_) async => const PaymentSettings(connected: true));

    di
      ..allowReassignment = true
      ..registerSingleton<BudgetRepository>(budgets)
      ..registerSingleton<PaymentRepository>(payments);

    final session = _Session();
    const user = SessionUser(
      id: 'u',
      email: 'a@b.c',
      name: 'Ana',
      organizationId: 'o',
      roles: {Role.owner},
      expiresAt: null,
    );
    when(
      () => session.state,
    ).thenReturn(const SessionState.authenticated(user));
    when(() => session.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(
      MaterialApp(
        theme: SpooliqTheme.light,
        home: BlocProvider<SessionCubit>.value(
          value: session,
          child: const Scaffold(body: BudgetDetailPage(id: 'b-1')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Pagamento'), findsOneWidget);
    expect(find.textContaining('Valor pago maior que o total'), findsOneWidget);
    expect(find.textContaining('reembolse pela'), findsOneWidget);
    expect(find.text('Recibo'), findsOneWidget);
  });
}
