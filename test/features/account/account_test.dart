import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forma_theme_spooliq/forma_theme_spooliq.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spooliq_desktop/core/auth/credential_vault.dart';
import 'package:spooliq_desktop/core/auth/session_user.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/network/api_client.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/network/session_events.dart';
import 'package:spooliq_desktop/features/account/data/api_account_repository.dart';
import 'package:spooliq_desktop/features/account/domain/account.dart';
import 'package:spooliq_desktop/features/account/presentation/account_page.dart';
import 'package:spooliq_desktop/features/account/presentation/forgot_password_dialog.dart';
import 'package:spooliq_desktop/features/auth/domain/auth_repository.dart';
import 'package:spooliq_desktop/features/auth/presentation/session_cubit.dart';

class _Api extends Mock implements ApiClient {}

class _Account extends Mock implements AccountRepository {}

class _Auth extends Mock implements AuthRepository {}

class _Vault extends Mock implements CredentialVault {}

const _me = Me(id: 'kc', name: 'Ana', email: 'ana@x.com', userType: 'owner');

const _user = SessionUser(
  id: 'kc',
  email: 'ana@x.com',
  name: 'Ana',
  organizationId: 'o',
  roles: {Role.owner},
  expiresAt: null,
);

void main() {
  group('ApiAccountRepository', () {
    late _Api api;

    setUp(() {
      api = _Api();
      when(
        () => api.post(
          any(),
          body: any(named: 'body'),
          auth: any(named: 'auth'),
        ),
      ).thenAnswer((_) async => null);
    });

    test('forgot password is a public request', () async {
      await ApiAccountRepository(api).forgotPassword(' ana@x.com ');
      verify(
        () => api.post(
          '/password/forgot',
          body: {'email': 'ana@x.com'},
          auth: false,
        ),
      ).called(1);
    });

    test('change password sends both passwords', () async {
      await ApiAccountRepository(
        api,
      ).changePassword(current: 'old-pass', newPassword: 'new-pass-1');
      verify(
        () => api.post(
          '/me/password',
          body: {'current_password': 'old-pass', 'new_password': 'new-pass-1'},
        ),
      ).called(1);
    });
  });

  group('AccountPage', () {
    late _Account account;
    late _Vault vault;
    late SessionCubit session;

    setUpAll(
      () => registerFallbackValue(
        const SavedCredentials(email: '', password: ''),
      ),
    );

    setUp(() {
      account = _Account();
      vault = _Vault();
      when(() => vault.savedEmail()).thenAnswer((_) async => 'ana@x.com');
      when(() => vault.save(any())).thenAnswer((_) async {});
      di
        ..allowReassignment = true
        ..registerSingleton<AccountRepository>(account)
        ..registerSingleton<CredentialVault>(vault);
      when(() => account.me()).thenAnswer((_) async => _me);
      session = SessionCubit(repository: _Auth(), events: SessionEvents())
        ..signedIn(_user);
    });

    tearDown(() => session.close());

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: SpooliqTheme.light,
          home: BlocProvider.value(
            value: session,
            child: const Scaffold(body: AccountPage()),
          ),
        ),
      );
      await tester.pump();
    }

    Finder field(String label) => find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Column)),
      matching: find.byType(TextField),
    );

    testWidgets('renaming updates the session name', (tester) async {
      when(
        () => account.updateName(any()),
      ).thenAnswer(
        (_) async => const Me(id: 'kc', name: 'Ana Souza', email: 'ana@x.com'),
      );

      await pump(tester);
      await tester.enterText(field('Nome').first, 'Ana Souza');
      await tester.tap(find.text('Salvar'));
      await tester.pump();

      verify(() => account.updateName('Ana Souza')).called(1);
      expect(session.state.user?.name, 'Ana Souza');
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('validates the new password before calling the API', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(field('Senha atual').first, 'old-pass');
      await tester.enterText(field('Nova senha').first, 'curta');
      await tester.tap(find.text('Alterar senha'));
      await tester.pump();

      expect(find.text('Use pelo menos 8 caracteres'), findsOneWidget);
      verifyNever(
        () => account.changePassword(
          current: any(named: 'current'),
          newPassword: any(named: 'newPassword'),
        ),
      );
    });

    testWidgets('shows the API error for a wrong current password', (
      tester,
    ) async {
      when(
        () => account.changePassword(
          current: any(named: 'current'),
          newPassword: any(named: 'newPassword'),
        ),
      ).thenThrow(const ValidationError('Senha atual incorreta'));

      await pump(tester);
      await tester.enterText(field('Senha atual').first, 'errada!!');
      await tester.enterText(field('Nova senha').first, 'nova-senha-1');
      await tester.enterText(
        field('Confirmar nova senha').first,
        'nova-senha-1',
      );
      await tester.tap(find.text('Alterar senha'));
      await tester.pump();

      expect(find.text('Senha atual incorreta'), findsOneWidget);
    });
  });

  testWidgets('changing the password updates the Touch ID credential', (
    tester,
  ) async {
    final account = _Account();
    final vault = _Vault();
    when(account.me).thenAnswer((_) async => _me);
    when(
      () => account.changePassword(
        current: any(named: 'current'),
        newPassword: any(named: 'newPassword'),
      ),
    ).thenAnswer((_) async {});
    when(vault.savedEmail).thenAnswer((_) async => 'ana@x.com');
    when(() => vault.save(any())).thenAnswer((_) async {});
    di
      ..allowReassignment = true
      ..registerSingleton<AccountRepository>(account)
      ..registerSingleton<CredentialVault>(vault);
    final session = SessionCubit(repository: _Auth(), events: SessionEvents())
      ..signedIn(_user);
    addTearDown(session.close);
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: SpooliqTheme.light,
        home: BlocProvider.value(
          value: session,
          child: const Scaffold(body: AccountPage()),
        ),
      ),
    );
    await tester.pump();

    Finder field(String label) => find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Column)),
      matching: find.byType(TextField),
    );
    await tester.enterText(field('Senha atual').first, 'old-pass');
    await tester.enterText(field('Nova senha').first, 'nova-senha-1');
    await tester.enterText(field('Confirmar nova senha').first, 'nova-senha-1');
    await tester.tap(find.text('Alterar senha'));
    await tester.pump();
    await tester.pump();

    final saved =
        verify(() => vault.save(captureAny())).captured.single
            as SavedCredentials;
    expect(saved.email, 'ana@x.com');
    expect(saved.password, 'nova-senha-1');
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('forgot password dialog sends the e-mail', (tester) async {
    final account = _Account();
    di
      ..allowReassignment = true
      ..registerSingleton<AccountRepository>(account);
    when(() => account.forgotPassword(any())).thenAnswer((_) async {});

    await tester.pumpWidget(
      MaterialApp(
        theme: SpooliqTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => unawaited(
                showForgotPasswordDialog(context, email: 'ana@x.com'),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enviar link'));
    await tester.pump();

    verify(() => account.forgotPassword('ana@x.com')).called(1);
    await tester.pump(const Duration(seconds: 5));
  });
}
