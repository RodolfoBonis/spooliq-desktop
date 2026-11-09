import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_repository.dart';
import 'package:spooliq_desktop/features/budgets/presentation/detail/budget_detail_cubit.dart';
import 'package:spooliq_desktop/features/payments/domain/budget_payment.dart';
import 'package:spooliq_desktop/features/payments/domain/payment_repository.dart';
import 'package:spooliq_desktop/features/payments/domain/payment_settings.dart';

import '../../../helpers/fixtures.dart';

class _Repo extends Mock implements BudgetRepository {}

class _Payments extends Mock implements PaymentRepository {}

final _change = StatusChange.fromJson(const {
  'id': 'h1',
  'previous_status': 'draft',
  'new_status': 'sent',
  'changed_by': 'Ana',
});

void main() {
  late _Repo repo;
  late _Payments payments;
  final budget = Budget.fromJson(budgetJson());

  setUp(() {
    repo = _Repo();
    payments = _Payments();
  });

  blocTest<BudgetDetailCubit, BudgetDetailState>(
    'loads the budget and then the full history',
    setUp: () {
      when(() => repo.get('b-1')).thenAnswer((_) async => budget);
      when(() => repo.history('b-1')).thenAnswer(
        (_) async => Paginated(
          items: [_change],
          total: 1,
          page: 1,
          pageSize: 20,
          totalPages: 1,
        ),
      );
    },
    build: () => BudgetDetailCubit(repo, payments, 'b-1'),
    act: (c) async {
      await c.load();
      await Future<void>.delayed(Duration.zero);
    },
    verify: (c) {
      expect(c.state.budget, budget);
      expect(c.state.history, [_change]);
      expect(c.state.loading, isFalse);
      // Rascunho não dispara a busca de pagamentos.
      verifyNever(() => payments.budgetPayments(any()));
    },
  );

  blocTest<BudgetDetailCubit, BudgetDetailState>(
    'keeps the embedded history when the history endpoint fails',
    setUp: () {
      when(() => repo.get('b-1')).thenAnswer((_) async => budget);
      when(
        () => repo.history('b-1'),
      ).thenThrow(const ServerError('falhou'));
    },
    build: () => BudgetDetailCubit(repo, payments, 'b-1'),
    act: (c) async {
      await c.load();
      await Future<void>.delayed(Duration.zero);
    },
    verify: (c) {
      expect(c.state.history, budget.statusHistory);
      expect(c.state.error, isNull);
    },
  );

  blocTest<BudgetDetailCubit, BudgetDetailState>(
    'shows the error when the budget cannot load',
    setUp: () =>
        when(() => repo.get('b-1')).thenThrow(const NotFoundError('sumiu')),
    build: () => BudgetDetailCubit(repo, payments, 'b-1'),
    act: (c) => c.load(),
    verify: (c) {
      expect(c.state.error, 'sumiu');
      expect(c.state.loading, isFalse);
    },
  );

  blocTest<BudgetDetailCubit, BudgetDetailState>(
    'loads payments and integration status for a budget with a balance',
    setUp: () {
      final paid = Budget.fromJson(
        budgetJson(
          status: 'approved',
          paymentStatus: 'partial',
          amountPaid: 1000,
          balanceDue: 24990,
        ),
      );
      final payment = BudgetPayment.fromJson(const {
        'kind': 'deposit',
        'status': 'paid',
        'amount_cents': 1000,
        'paid_amount_cents': 1000,
        'capture_method': 'pix',
        'paid_at': '2026-10-05T10:00:00Z',
        'receipt_url': 'https://infinitepay.io/receipts/abc',
      });
      when(() => repo.get('b-1')).thenAnswer((_) async => paid);
      when(() => repo.history('b-1')).thenThrow(const ServerError('x'));
      when(
        () => payments.budgetPayments('b-1'),
      ).thenAnswer((_) async => [payment]);
      when(() => payments.getSettings()).thenAnswer(
        (_) async => const PaymentSettings(enabled: true, connected: true),
      );
    },
    build: () => BudgetDetailCubit(repo, payments, 'b-1'),
    act: (c) async {
      await c.load();
      await Future<void>.delayed(Duration.zero);
    },
    verify: (c) {
      expect(c.state.payments, hasLength(1));
      expect(c.state.payments.single.kind, PaymentKind.deposit);
      expect(c.state.paymentsEnabled, isTrue);
      verify(() => payments.budgetPayments('b-1')).called(1);
    },
  );
}
