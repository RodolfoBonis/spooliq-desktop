import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/routing/routes.dart';
import 'package:spooliq_desktop/features/auth/presentation/auth_layout.dart';
import 'package:spooliq_desktop/features/auth/presentation/login_cubit.dart';
import 'package:spooliq_desktop/features/auth/presentation/session_cubit.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoginCubit(di()),
      child: BlocListener<LoginCubit, LoginState>(
        listenWhen: (a, b) => b.user != null && a.user != b.user,
        listener: (context, state) =>
            context.read<SessionCubit>().signedIn(state.user!),
        child: const AuthLayout(child: _LoginForm()),
      ),
    );
  }
}

class _LoginForm extends StatefulWidget {
  const _LoginForm();

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() => unawaited(
    context.read<LoginCubit>().submit(
      email: _email.text,
      password: _password.text,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final expired = context.select<SessionCubit, bool>((c) => c.state.expired);
    final state = context.watch<LoginCubit>().state;

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Bem-vindo de volta',
            style: typo.h3.copyWith(
              color: ext.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Entre com sua conta SpoolIQ para continuar.',
            style: typo.body14.copyWith(color: ext.textMuted),
          ),
          const SizedBox(height: 28),
          if (expired && state.error == null) ...[
            const FormaAlertBanner(
              message: 'Sua sessão expirou. Entre novamente.',
              variant: FormaAlertVariant.warning,
            ),
            const SizedBox(height: 16),
          ],
          if (state.error != null) ...[
            FormaAlertBanner(
              message: state.error!,
              variant: FormaAlertVariant.error,
            ),
            const SizedBox(height: 16),
          ],
          FormaTextField(
            label: 'E-mail',
            hint: 'voce@empresa.com',
            controller: _email,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
          ),
          const SizedBox(height: 16),
          FormaTextField(
            label: 'Senha',
            controller: _password,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _submit(),
            suffix: IconButton(
              tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
              iconSize: 18,
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: ext.textHint,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          const SizedBox(height: 24),
          FormaButton.primary(
            label: 'Entrar',
            width: double.infinity,
            isLoading: state.submitting,
            onPressed: _submit,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Ainda não tem conta?',
                style: typo.body14.copyWith(color: ext.textMuted),
              ),
              TextButton(
                onPressed: () => context.go(Routes.register),
                child: const Text('Criar conta grátis'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
