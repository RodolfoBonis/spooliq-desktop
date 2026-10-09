import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spooliq_desktop/core/auth/session_user.dart';
import 'package:spooliq_desktop/core/network/session_events.dart';
import 'package:spooliq_desktop/features/auth/domain/auth_repository.dart';
import 'package:spooliq_desktop/features/auth/presentation/session_cubit.dart';

class _Repo extends Mock implements AuthRepository {}

SessionUser _user({Set<Role> roles = const {Role.owner}}) => SessionUser(
  id: 'u',
  email: 'a@b.c',
  name: 'Ana',
  organizationId: 'o',
  roles: roles,
  expiresAt: null,
);

void main() {
  late _Repo repo;
  late SessionEvents events;

  setUp(() {
    repo = _Repo();
    events = SessionEvents();
    when(() => repo.logout()).thenAnswer((_) async {});
  });

  tearDown(() => events.dispose());

  SessionCubit build() => SessionCubit(repository: repo, events: events);

  blocTest<SessionCubit, SessionState>(
    'restores a saved session',
    setUp: () => when(() => repo.restore()).thenAnswer((_) async => _user()),
    build: build,
    act: (c) => c.restore(),
    expect: () => [SessionState.authenticated(_user())],
  );

  blocTest<SessionCubit, SessionState>(
    'starts logged out without a saved session',
    setUp: () => when(() => repo.restore()).thenAnswer((_) async => null),
    build: build,
    act: (c) => c.restore(),
    expect: () => [const SessionState.unauthenticated()],
  );

  blocTest<SessionCubit, SessionState>(
    'an expired session logs out and flags it',
    build: build,
    seed: () => SessionState.authenticated(_user()),
    act: (c) async {
      events.emit(const SessionExpired());
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => [const SessionState.unauthenticated(expired: true)],
  );

  blocTest<SessionCubit, SessionState>(
    'subscription blocks are shown and can be cleared',
    build: build,
    seed: () => SessionState.authenticated(_user()),
    act: (c) async {
      events.emit(
        const SubscriptionBlocked(code: 'trial_expired', message: 'Fim'),
      );
      await Future<void>.delayed(Duration.zero);
      c.clearSubscriptionBlock();
    },
    expect: () => [
      SessionState.authenticated(
        _user(),
        block: const SubscriptionBlock(code: 'trial_expired', message: 'Fim'),
      ),
      SessionState.authenticated(_user()),
    ],
  );

  blocTest<SessionCubit, SessionState>(
    'platform admins are never blocked by subscription',
    build: build,
    seed: () =>
        SessionState.authenticated(_user(roles: const {Role.platformAdmin})),
    act: (c) async {
      events.emit(const SubscriptionBlocked(code: 'x', message: 'y'));
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => <SessionState>[],
  );

  blocTest<SessionCubit, SessionState>(
    'logout clears the session',
    build: build,
    seed: () => SessionState.authenticated(_user()),
    act: (c) => c.logout(),
    expect: () => [const SessionState.unauthenticated()],
    verify: (_) => verify(() => repo.logout()).called(1),
  );
}
