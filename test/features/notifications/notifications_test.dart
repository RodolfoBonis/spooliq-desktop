import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forma_theme_spooliq/forma_theme_spooliq.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/features/notifications/domain/notification.dart';
import 'package:spooliq_desktop/features/notifications/presentation/notification_bell.dart';
import 'package:spooliq_desktop/features/notifications/presentation/notifications_cubit.dart';

class _Repo extends Mock implements NotificationRepository {}

class _FakeNotifier implements SystemNotifier {
  final shown = <String>[];

  @override
  Future<void> show(String title, {String? body, VoidCallback? onClick}) async {
    shown.add(title);
    onClick?.call();
  }
}

AppNotification _n(String id, {String? link, bool read = false}) =>
    AppNotification.fromJson({
      'id': id,
      'type': 'budget_approved',
      'title': 'Orçamento $id aprovado',
      'link': ?link,
      if (read) 'read_at': '2026-10-08T10:00:00Z',
      'created_at': '2026-10-08T09:00:00Z',
    });

Paginated<AppNotification> _page(List<AppNotification> items) => Paginated(
  items: items,
  total: items.length,
  page: 1,
  pageSize: 20,
  totalPages: 1,
);

void main() {
  late _Repo repo;
  late _FakeNotifier notifier;

  setUpAll(() => registerFallbackValue(const PageQuery()));

  setUp(() {
    repo = _Repo();
    notifier = _FakeNotifier();
    when(() => repo.markRead(any())).thenAnswer((_) async {});
    when(() => repo.markAllRead()).thenAnswer((_) async {});
  });

  void unread(List<AppNotification> items) {
    when(() => repo.unreadCount()).thenAnswer((_) async => items.length);
    when(
      () => repo.list(
        page: any(named: 'page'),
        unreadOnly: any(named: 'unreadOnly'),
      ),
    ).thenAnswer((_) async => _page(items));
  }

  test(
    'first poll only sets the badge; later new ones are announced',
    () async {
      final opened = <String>[];
      final cubit = NotificationsCubit(repo, notifier)..onOpen = opened.add;

      unread([_n('1')]);
      await cubit.poll();
      expect(cubit.state.unread, 1);
      expect(notifier.shown, isEmpty, reason: 'no burst on startup');

      unread([_n('2', link: '/budgets/2'), _n('1')]);
      await cubit.poll();
      expect(cubit.state.unread, 2);
      expect(notifier.shown, ['Orçamento 2 aprovado']);
      // Clicar na notificação do sistema abre o link.
      expect(opened, ['/budgets/2']);

      await cubit.close();
    },
  );

  test('mark read updates the badge optimistically', () async {
    final cubit = NotificationsCubit(repo, notifier);
    unread([_n('1'), _n('2')]);
    await cubit.poll();
    await cubit.load();

    await cubit.markRead(cubit.state.items.first);
    expect(cubit.state.unread, 1);
    expect(cubit.state.items.first.isRead, isTrue);
    verify(() => repo.markRead('1')).called(1);

    await cubit.markAllRead();
    expect(cubit.state.unread, 0);
    expect(cubit.state.items.every((n) => n.isRead), isTrue);
    await cubit.close();
  });

  testWidgets('bell shows the unread count and opens the list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    unread([_n('1'), _n('2', read: true)]);
    when(() => repo.unreadCount()).thenAnswer((_) async => 1);
    final cubit = NotificationsCubit(repo, notifier);
    await cubit.poll();

    await tester.pumpWidget(
      MaterialApp(
        theme: SpooliqTheme.light,
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: const Align(
              alignment: Alignment.topRight,
              child: NotificationBell(),
            ),
          ),
        ),
      ),
    );
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byType(NotificationBell));
    await tester.pumpAndSettle();
    expect(find.text('Notificações'), findsOneWidget);
    expect(find.text('Orçamento 1 aprovado'), findsOneWidget);
    expect(find.text('Marcar todas como lidas'), findsOneWidget);
    await cubit.close();
  });
}
