import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_repository.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_status.dart';
import 'package:spooliq_desktop/features/budgets/presentation/board/board_cubit.dart';

import '../../../helpers/fixtures.dart';

class _MockRepo extends Mock implements BudgetRepository {}

Budget _budget(String id, BudgetStatus status) =>
    Budget.fromJson(budgetJson(id: id, status: status.value));

Paginated<Budget> _page(List<Budget> items, {int totalPages = 1}) => Paginated(
  items: items,
  total: items.length,
  page: 1,
  pageSize: 20,
  totalPages: totalPages,
);

void main() {
  late _MockRepo repo;

  setUpAll(() {
    registerFallbackValue(const BudgetFilter());
    registerFallbackValue(const PageQuery());
    registerFallbackValue(BudgetStatus.draft);
  });

  setUp(() {
    repo = _MockRepo();
    when(
      () => repo.list(
        filter: any(named: 'filter'),
        page: any(named: 'page'),
      ),
    ).thenAnswer((inv) async {
      final filter = inv.namedArguments[#filter] as BudgetFilter;
      return switch (filter.status) {
        BudgetStatus.draft => _page([_budget('d1', BudgetStatus.draft)]),
        BudgetStatus.sent => _page([
          _budget('s1', BudgetStatus.sent),
        ], totalPages: 2),
        _ => _page([]),
      };
    });
  });

  group('BoardCubit', () {
    blocTest<BoardCubit, BoardState>(
      'load fills one column per status',
      build: () => BoardCubit(repo),
      act: (c) => c.load(),
      verify: (c) {
        expect(c.state.column(BudgetStatus.draft).items.single.id, 'd1');
        expect(c.state.column(BudgetStatus.sent).hasMore, isTrue);
        expect(c.state.totalCount, 2);
        expect(c.state.isInitialLoading, isFalse);
        verify(
          () => repo.list(
            filter: any(named: 'filter'),
            page: any(named: 'page'),
          ),
        ).called(BudgetStatus.values.length);
      },
    );

    blocTest<BoardCubit, BoardState>(
      'move succeeds and keeps the server version',
      build: () => BoardCubit(repo),
      setUp: () => when(
        () => repo.changeStatus(
          'd1',
          BudgetStatus.sent,
          notes: any(named: 'notes'),
        ),
      ).thenAnswer((_) async => _budget('d1', BudgetStatus.sent)),
      act: (c) async {
        await c.load();
        final result = await c.move(
          c.state.column(BudgetStatus.draft).items.single,
          BudgetStatus.sent,
        );
        expect(result, isA<MoveSucceeded>());
      },
      verify: (c) {
        expect(c.state.column(BudgetStatus.draft).items, isEmpty);
        expect(
          c.state.column(BudgetStatus.sent).items.map((b) => b.id),
          ['d1', 's1'],
        );
        expect(c.state.moving, isEmpty);
      },
    );

    blocTest<BoardCubit, BoardState>(
      'move rolls back on conflict',
      build: () => BoardCubit(repo),
      setUp: () =>
          when(
            () => repo.changeStatus(any(), any(), notes: any(named: 'notes')),
          ).thenThrow(
            const ConflictError(
              'Alterado por outra pessoa',
              code: 'budget_status_conflict',
            ),
          ),
      act: (c) async {
        await c.load();
        final result = await c.move(
          c.state.column(BudgetStatus.draft).items.single,
          BudgetStatus.sent,
        );
        expect(result, isA<MoveFailed>());
      },
      verify: (c) {
        expect(c.state.column(BudgetStatus.draft).items.single.id, 'd1');
        expect(c.state.column(BudgetStatus.sent).items.single.id, 's1');
      },
    );

    blocTest<BoardCubit, BoardState>(
      'rejects disallowed transitions without calling the API',
      build: () => BoardCubit(repo),
      act: (c) async {
        await c.load();
        final result = await c.move(
          c.state.column(BudgetStatus.draft).items.single,
          BudgetStatus.completed,
        );
        expect(result, isA<MoveFailed>());
      },
      verify: (_) => verifyNever(
        () => repo.changeStatus(any(), any(), notes: any(named: 'notes')),
      ),
    );

    blocTest<BoardCubit, BoardState>(
      'loadMore appends the next page without duplicates',
      build: () => BoardCubit(repo),
      act: (c) async {
        await c.load();
        when(
          () => repo.list(
            filter: any(named: 'filter'),
            page: any(named: 'page'),
          ),
        ).thenAnswer(
          (_) async => Paginated(
            items: [
              _budget('s1', BudgetStatus.sent),
              _budget('s2', BudgetStatus.sent),
            ],
            total: 2,
            page: 2,
            pageSize: 20,
            totalPages: 2,
          ),
        );
        await c.loadMore(BudgetStatus.sent);
      },
      verify: (c) {
        final col = c.state.column(BudgetStatus.sent);
        expect(col.items.map((b) => b.id), ['s1', 's2']);
        expect(col.hasMore, isFalse);
      },
    );

    blocTest<BoardCubit, BoardState>(
      'upsert moves an edited budget to its new column',
      build: () => BoardCubit(repo),
      act: (c) async {
        await c.load();
        c.upsert(_budget('d1', BudgetStatus.cancelled));
      },
      verify: (c) {
        expect(c.state.column(BudgetStatus.draft).items, isEmpty);
        expect(c.state.column(BudgetStatus.cancelled).items.single.id, 'd1');
      },
    );
  });
}
