import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spooliq_desktop/core/auth/credential_vault.dart';
import 'package:spooliq_desktop/core/auth/session_user.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/features/auth/domain/auth_repository.dart';
import 'package:spooliq_desktop/features/auth/presentation/login_cubit.dart';

class _Repo extends Mock implements AuthRepository {}

class _Vault extends Mock implements CredentialVault {}

const _user = SessionUser(
  id: 'u',
  email: 'ana@x.com',
  name: 'Ana',
  organizationId: 'o',
  roles: {Role.owner},
  expiresAt: null,
);

const _saved = SavedCredentials(email: 'ana@x.com', password: 's3nha');

void main() {
  late _Repo repo;
  late _Vault vault;

  setUpAll(() => registerFallbackValue(_saved));

  setUp(() {
    repo = _Repo();
    vault = _Vault();
    when(() => vault.methodLabel()).thenAnswer((_) async => 'Touch ID');
    when(() => vault.savedEmail()).thenAnswer((_) async => null);
    when(() => vault.save(any())).thenAnswer((_) async {});
    when(() => vault.clear()).thenAnswer((_) async {});
  });

  void loginSucceeds() => when(
    () => repo.login(
      email: any(named: 'email'),
      password: any(named: 'password'),
    ),
  ).thenAnswer((_) async => _user);

  group('load', () {
    blocTest<LoginCubit, LoginState>(
      'exposes the method and the remembered e-mail',
      setUp: () => when(
        () => vault.savedEmail(),
      ).thenAnswer((_) async => 'ana@x.com'),
      build: () => LoginCubit(repo, vault),
      act: (c) => c.load(),
      verify: (c) {
        expect(c.state.quickLoginLabel, 'Touch ID');
        expect(c.state.canQuickLogin, isTrue);
      },
    );

    blocTest<LoginCubit, LoginState>(
      'turns remembering off when the device has no local auth',
      setUp: () =>
          when(() => vault.methodLabel()).thenAnswer((_) async => null),
      build: () => LoginCubit(repo, vault),
      act: (c) => c.load(),
      verify: (c) {
        expect(c.state.remember, isFalse);
        expect(c.state.canQuickLogin, isFalse);
      },
    );
  });

  group('submit', () {
    blocTest<LoginCubit, LoginState>(
      'remembers the credentials after a successful login',
      setUp: loginSucceeds,
      build: () => LoginCubit(repo, vault),
      act: (c) async {
        await c.load();
        await c.submit(email: ' ana@x.com ', password: 's3nha');
      },
      verify: (c) {
        expect(c.state.user, _user);
        final saved =
            verify(() => vault.save(captureAny())).captured.single
                as SavedCredentials;
        expect(saved.email, 'ana@x.com');
        expect(saved.password, 's3nha');
      },
    );

    blocTest<LoginCubit, LoginState>(
      'forgets the credentials when remembering is unchecked',
      setUp: loginSucceeds,
      build: () => LoginCubit(repo, vault),
      act: (c) async {
        await c.load();
        c.setRemember(value: false);
        await c.submit(email: 'ana@x.com', password: 's3nha');
      },
      verify: (_) {
        verify(() => vault.clear()).called(1);
        verifyNever(() => vault.save(any()));
      },
    );

    blocTest<LoginCubit, LoginState>(
      'does not remember wrong credentials',
      setUp: () => when(
        () => repo.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const UnauthorizedError()),
      build: () => LoginCubit(repo, vault),
      act: (c) async {
        await c.load();
        await c.submit(email: 'ana@x.com', password: 'errada');
      },
      verify: (c) {
        expect(c.state.error, 'E-mail ou senha incorretos.');
        verifyNever(() => vault.save(any()));
      },
    );

    blocTest<LoginCubit, LoginState>(
      'still logs in when the keychain fails',
      setUp: () {
        loginSucceeds();
        when(() => vault.save(any())).thenThrow(Exception('keychain'));
      },
      build: () => LoginCubit(repo, vault),
      act: (c) async {
        await c.load();
        await c.submit(email: 'ana@x.com', password: 's3nha');
      },
      verify: (c) => expect(c.state.user, _user),
    );
  });

  group('quickLogin', () {
    setUp(
      () => when(
        () => vault.savedEmail(),
      ).thenAnswer((_) async => 'ana@x.com'),
    );

    blocTest<LoginCubit, LoginState>(
      'logs in with the unlocked credentials',
      setUp: () {
        loginSucceeds();
        when(() => vault.unlock()).thenAnswer((_) async => _saved);
      },
      build: () => LoginCubit(repo, vault),
      act: (c) async {
        await c.load();
        await c.quickLogin();
      },
      verify: (c) {
        expect(c.state.user, _user);
        verify(
          () => repo.login(email: 'ana@x.com', password: 's3nha'),
        ).called(1);
      },
    );

    blocTest<LoginCubit, LoginState>(
      'does nothing when the prompt is cancelled',
      setUp: () => when(() => vault.unlock()).thenAnswer((_) async => null),
      build: () => LoginCubit(repo, vault),
      act: (c) async {
        await c.load();
        await c.quickLogin();
      },
      verify: (c) {
        expect(c.state.error, isNull);
        verifyNever(
          () => repo.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        );
      },
    );

    blocTest<LoginCubit, LoginState>(
      'shows system failures such as lockout',
      setUp: () => when(
        () => vault.unlock(),
      ).thenThrow(const VaultError('bloqueado')),
      build: () => LoginCubit(repo, vault),
      act: (c) async {
        await c.load();
        await c.quickLogin();
      },
      verify: (c) => expect(c.state.error, 'bloqueado'),
    );

    blocTest<LoginCubit, LoginState>(
      'forgets a password that stopped working',
      setUp: () {
        when(() => vault.unlock()).thenAnswer((_) async => _saved);
        when(
          () => repo.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(const UnauthorizedError());
      },
      build: () => LoginCubit(repo, vault),
      act: (c) async {
        await c.load();
        await c.quickLogin();
      },
      verify: (c) {
        verify(() => vault.clear()).called(1);
        expect(c.state.canQuickLogin, isFalse);
        expect(c.state.error, contains('senha salva'));
      },
    );
  });
}
