import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/core/auth/credential_vault.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/observability/app_logger.dart';
import 'package:spooliq_desktop/core/ui/feedback.dart';
import 'package:spooliq_desktop/core/ui/form_dialog.dart';
import 'package:spooliq_desktop/core/ui/page_layout.dart';
import 'package:spooliq_desktop/features/account/domain/account.dart';
import 'package:spooliq_desktop/features/auth/presentation/session_cubit.dart';

/// "Meu perfil": nome e senha do próprio usuário.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final AccountRepository _repo = di<AccountRepository>();
  Me? _me;
  String? _error;

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _profileForm = GlobalKey<FormState>();
  bool _savingName = false;

  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  final _passwordForm = GlobalKey<FormState>();
  bool _savingPassword = false;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _current, _new, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final me = await _repo.me();
      if (!mounted) return;
      setState(() => _me = me);
      _name.text = me.name;
      _email.text = me.email;
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _saveName() async {
    if (!_profileForm.currentState!.validate()) return;
    setState(() => _savingName = true);
    try {
      final me = await _repo.updateName(_name.text);
      if (!mounted) return;
      setState(() => _me = me);
      context.read<SessionCubit>().renamed(me.name);
      Toasts.success(context, 'Perfil atualizado');
    } on ApiError catch (e) {
      if (mounted) Toasts.error(context, e);
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _changePassword() async {
    setState(() => _passwordError = null);
    if (!_passwordForm.currentState!.validate()) return;
    setState(() => _savingPassword = true);
    try {
      await _repo.changePassword(
        current: _current.text,
        newPassword: _new.text,
      );
      await _updateRememberedPassword(_new.text);
      if (!mounted) return;
      for (final c in [_current, _new, _confirm]) {
        c.clear();
      }
      Toasts.success(context, 'Senha alterada');
    } on ApiError catch (e) {
      if (mounted) setState(() => _passwordError = e.message);
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  /// Mantém o login por Touch ID / Windows Hello válido após a troca.
  Future<void> _updateRememberedPassword(String password) async {
    final vault = di<CredentialVault>();
    try {
      final email = await vault.savedEmail();
      if (email == null || email != _me?.email) return;
      await vault.save(SavedCredentials(email: email, password: password));
    } on Exception catch (e) {
      // A senha já mudou; só o login rápido pedirá a nova senha uma vez.
      AppLogger.warning('Falha ao atualizar a senha lembrada', error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = _me;
    if (me == null) {
      return _error != null
          ? ErrorView(message: _error!, onRetry: () => unawaited(_load()))
          : const LoadingView();
    }
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;

    return PageLayout(
      title: 'Meu perfil',
      subtitle: me.email,
      scrollable: true,
      maxWidth: 720,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: 'Dados pessoais',
            child: Form(
              key: _profileForm,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FormaTextField(
                    label: 'Nome',
                    controller: _name,
                    validator: (v) =>
                        (v?.trim().length ?? 0) < 2 ? 'Informe seu nome' : null,
                  ),
                  const SizedBox(height: 14),
                  FormaTextField(
                    label: 'E-mail',
                    controller: _email,
                    readOnly: true,
                    helperText:
                        'O e-mail é usado para entrar e não pode '
                        'ser alterado aqui.',
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FormaButton.primary(
                      label: 'Salvar',
                      small: true,
                      isLoading: _savingName,
                      onPressed: () => unawaited(_saveName()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Senha',
            child: Form(
              key: _passwordForm,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FormaTextField(
                    label: 'Senha atual',
                    controller: _current,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    validator: requiredValidator,
                  ),
                  const SizedBox(height: 14),
                  FormaTextField(
                    label: 'Nova senha',
                    controller: _new,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    helperText: 'Mínimo de 8 caracteres.',
                    validator: (v) {
                      final value = v ?? '';
                      if (value.length < 8) {
                        return 'Use pelo menos 8 caracteres';
                      }
                      if (value == _current.text) {
                        return 'A nova senha deve ser diferente da atual';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  FormaTextField(
                    label: 'Confirmar nova senha',
                    controller: _confirm,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: (v) =>
                        v != _new.text ? 'As senhas não conferem' : null,
                  ),
                  if (_passwordError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _passwordError!,
                      style: typo.caption12.copyWith(color: ext.errorColor),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FormaButton.primary(
                      label: 'Alterar senha',
                      small: true,
                      isLoading: _savingPassword,
                      onPressed: () => unawaited(_changePassword()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
