import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_repository.dart';
import 'package:spooliq_desktop/features/budgets/presentation/detail/budget_detail_cubit.dart';

import '../../../helpers/fixtures.dart';

class _Repo extends Mock implements BudgetRepository {}

final _change = StatusChange.fromJson(const {
  'id': 'h1',
  'previous_status': 'draft',
  'new_status': 'sent',
  'changed_by': 'Ana',
});

void main() {
  late _Repo repo;
  final budget = Budget.fromJson(budgetJson());

  setUp(() => repo = _Repo());

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
    build: () => BudgetDetailCubit(repo, 'b-1'),
    act: (c) async {
      await c.load();
      await Future<void>.delayed(Duration.zero);
    },
    verify: (c) {
      expect(c.state.budget, budget);
      expect(c.state.history, [_change]);
      expect(c.state.loading, isFalse);
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
    build: () => BudgetDetailCubit(repo, 'b-1'),
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
    build: () => BudgetDetailCubit(repo, 'b-1'),
    act: (c) => c.load(),
    verify: (c) {
      expect(c.state.error, 'sumiu');
      expect(c.state.loading, isFalse);
    },
  );
}
