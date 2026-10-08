import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/core/state/paged_list_cubit.dart';

typedef _Item = ({String id, String name});

Paginated<_Item> _page(List<_Item> items) => Paginated(
  items: items,
  total: items.length,
  page: 1,
  pageSize: 20,
  totalPages: 1,
);

void main() {
  blocTest<PagedListCubit<_Item>, PagedListState<_Item>>(
    'load emits loading then data',
    build: () => PagedListCubit(
      (_) async => _page([(id: '1', name: 'a')]),
      idOf: (i) => i.id,
    ),
    act: (c) => c.load(),
    expect: () => [
      isA<PagedListState<_Item>>().having((s) => s.loading, 'loading', isTrue),
      isA<PagedListState<_Item>>()
          .having((s) => s.items.length, 'items', 1)
          .having((s) => s.loading, 'loading', isFalse),
    ],
  );

  blocTest<PagedListCubit<_Item>, PagedListState<_Item>>(
    'discards stale responses (latest search wins)',
    build: () {
      final slow = Completer<Paginated<_Item>>();
      return PagedListCubit<_Item>(
        (q) => q.search == 'old'
            ? slow.future
            : Future.value(_page([(id: 'n', name: 'new')])),
        idOf: (i) => i.id,
      );
    },
    act: (c) async {
      c
        ..search('old')
        ..search('new');
      await Future<void>.delayed(Duration.zero);
    },
    verify: (c) => expect(c.state.items.single.id, 'n'),
  );

  blocTest<PagedListCubit<_Item>, PagedListState<_Item>>(
    'exposes API errors',
    build: () => PagedListCubit<_Item>(
      (_) async => throw const NetworkError(),
      idOf: (i) => i.id,
    ),
    act: (c) => c.load(),
    verify: (c) => expect(c.state.error, isNotNull),
  );

  blocTest<PagedListCubit<_Item>, PagedListState<_Item>>(
    'upsert and remove update the page locally',
    build: () => PagedListCubit(
      (_) async => _page([(id: '1', name: 'a')]),
      idOf: (i) => i.id,
    ),
    act: (c) async {
      await c.load();
      c
        ..upsert((id: '2', name: 'b'))
        ..upsert((id: '1', name: 'a2'))
        ..remove('2');
    },
    verify: (c) {
      expect(c.state.items, [(id: '1', name: 'a2')]);
      expect(c.state.page.total, 1);
    },
  );
}
