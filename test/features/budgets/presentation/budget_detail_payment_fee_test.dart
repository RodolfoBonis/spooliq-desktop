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

  Future<void> pumpDetail(
    WidgetTester tester, {
    required BudgetPaymentsResult paymentsResult,
  }) async {
    tester.view.physicalSize = const Size(1500, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final budgets = _Budgets();
    final payments = _Payments();
    when(() => budgets.get('b-1')).thenAnswer(
      (_) async => Budget.fromJson(
        budgetJson(
          status: 'approved',
          total: 21712,
          paymentStatus: 'paid',
          amountPaid: 21712,
          balanceDue: 0,
        ),
      ),
    );
    when(
      () => budgets.history('b-1'),
    ).thenAnswer((_) async => const Paginated.empty());
    when(
      () => payments.budgetPayments('b-1'),
    ).thenAnswer((_) async => paymentsResult);
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
  }

  testWidgets('shows the net received total and per-line fee', (tester) async {
    await pumpDetail(
      tester,
      paymentsResult: BudgetPaymentsResult(
        feesCents: 1715,
        netReceivedCents: 19997,
        payments: [
          BudgetPayment.fromJson(const {
            'kind': 'full',
            'amount': 21712,
            'paid_amount': 21712,
            'capture_method': 'credit_card',
            'installments': 4,
            'status': 'paid',
            'fee_amount': 1715,
            'net_amount': 19997,
            'fee_rate_percent': 7.9,
          }),
        ],
      ),
    );

    expect(find.textContaining('Líquido recebido ≈'), findsOneWidget);
    expect(find.textContaining('Você recebe ≈'), findsOneWidget);
    expect(find.textContaining('taxa ≈'), findsOneWidget);
    expect(
      find.text('Cadastre suas taxas para ver quanto recebe'),
      findsNothing,
    );
  });

  testWidgets('shows the fee CTA when the estimate is unknown', (tester) async {
    await pumpDetail(
      tester,
      paymentsResult: BudgetPaymentsResult(
        payments: [
          BudgetPayment.fromJson(const {
            'kind': 'full',
            'amount': 21712,
            'paid_amount': 21712,
            'capture_method': 'credit_card',
            'installments': 4,
            'status': 'paid',
          }),
        ],
      ),
    );

    expect(
      find.text('Cadastre suas taxas para ver quanto recebe'),
      findsOneWidget,
    );
    expect(find.textContaining('Líquido recebido ≈'), findsNothing);
  });
}
