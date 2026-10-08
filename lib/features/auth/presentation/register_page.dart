import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/format/masks.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/routing/routes.dart';
import 'package:spooliq_desktop/features/auth/domain/auth_repository.dart';
import 'package:spooliq_desktop/features/auth/presentation/auth_layout.dart';
import 'package:spooliq_desktop/features/auth/presentation/session_cubit.dart';

/// Cadastro em dois passos: conta e empresa (14 dias de teste).
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _accountForm = GlobalKey<FormState>();
  final _companyForm = GlobalKey<FormState>();
  final _c = <String, TextEditingController>{
    for (final k in [
      'name',
      'email',
      'password',
      'confirm',
      'companyName',
      'tradeName',
      'document',
      'phone',
      'zip',
      'address',
      'number',
      'complement',
      'neighborhood',
      'city',
      'state',
    ])
      k: TextEditingController(),
  };
  int _step = 0;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _v(String k) => _c[k]!.text.trim();

  void _next() {
    if (_accountForm.currentState!.validate()) setState(() => _step = 1);
  }

  Future<void> _submit() async {
    if (!_companyForm.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final repo = di<AuthRepository>();
    try {
      await repo.register(
        RegisterData(
          name: _v('name'),
          email: _v('email'),
          password: _c['password']!.text,
          companyName: _v('companyName'),
          companyTradeName: _v('tradeName').isEmpty ? null : _v('tradeName'),
          companyDocument: _v('document'),
          companyPhone: _v('phone'),
          address: _v('address'),
          addressNumber: _v('number'),
          complement: _v('complement').isEmpty ? null : _v('complement'),
          neighborhood: _v('neighborhood'),
          city: _v('city'),
          state: _v('state'),
          zipCode: _v('zip'),
        ),
      );
      final user = await repo.login(
        email: _v('email'),
        password: _c['password']!.text,
      );
      if (!mounted) return;
      context.read<SessionCubit>().signedIn(user);
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e is ValidationError && e.fields.isNotEmpty
            ? '${e.message}\n${e.fields.values.join('\n')}'
            : e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;

    return AuthLayout(
      formWidth: 460,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Crie sua conta',
            style: typo.h3.copyWith(
              color: ext.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '14 dias grátis, sem cartão de crédito.',
            style: typo.body14.copyWith(color: ext.textMuted),
          ),
          const SizedBox(height: 20),
          _Steps(current: _step),
          const SizedBox(height: 24),
          if (_error != null) ...[
            FormaAlertBanner(
              message: _error!,
              variant: FormaAlertVariant.error,
            ),
            const SizedBox(height: 16),
          ],
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _step == 0 ? _account() : _company(),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Já tem conta?',
                style: typo.body14.copyWith(color: ext.textMuted),
              ),
              TextButton(
                onPressed: () => context.go(Routes.login),
                child: const Text('Entrar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(
    String key,
    String label, {
    String? hint,
    bool required = true,
    bool obscure = false,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    String? Function(String)? validate,
    bool autofocus = false,
    Iterable<String>? autofill,
    TextCapitalization caps = TextCapitalization.none,
  }) => FormaTextField(
    label: label,
    hint: hint,
    controller: _c[key],
    obscureText: obscure,
    autofocus: autofocus,
    keyboardType: keyboard ?? TextInputType.text,
    inputFormatters: formatters,
    autofillHints: autofill,
    textCapitalization: caps,
    textInputAction: TextInputAction.next,
    validator: (v) {
      final value = (v ?? '').trim();
      if (required && value.isEmpty) return 'Obrigatório';
      return validate?.call(value);
    },
  );

  Widget _account() => Form(
    key: _accountForm,
    child: Column(
      key: const ValueKey('account'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(
          'name',
          'Seu nome',
          autofocus: true,
          autofill: const [AutofillHints.name],
          caps: TextCapitalization.words,
        ),
        const SizedBox(height: 14),
        _field(
          'email',
          'E-mail',
          keyboard: TextInputType.emailAddress,
          autofill: const [AutofillHints.email],
          validate: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)
              ? null
              : 'E-mail inválido',
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _field(
                'password',
                'Senha',
                obscure: true,
                autofill: const [AutofillHints.newPassword],
                validate: (v) => v.length < 8 ? 'Mínimo de 8 caracteres' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _field(
                'confirm',
                'Confirmar senha',
                obscure: true,
                validate: (v) =>
                    v != _c['password']!.text ? 'As senhas não conferem' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        FormaButton.primary(
          label: 'Continuar',
          width: double.infinity,
          onPressed: _next,
        ),
      ],
    ),
  );

  Widget _company() {
    return Form(
      key: _companyForm,
      child: Column(
        key: const ValueKey('company'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field(
            'companyName',
            'Razão social',
            autofocus: true,
            caps: TextCapitalization.words,
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _field(
                  'tradeName',
                  'Nome fantasia',
                  required: false,
                  caps: TextCapitalization.words,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  'document',
                  'CNPJ',
                  hint: '00.000.000/0000-00',
                  formatters: [Masks.cnpj],
                  validate: (v) => Masks.digits(v).length != 14
                      ? 'CNPJ deve ter 14 dígitos'
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _field(
                  'phone',
                  'Telefone',
                  hint: '(00) 00000-0000',
                  keyboard: TextInputType.phone,
                  formatters: [Masks.phone],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 150,
                child: _field(
                  'zip',
                  'CEP',
                  formatters: [Masks.cep],
                  validate: (v) =>
                      Masks.digits(v).length != 8 ? 'CEP inválido' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _field('address', 'Endereço')),
              const SizedBox(width: 12),
              SizedBox(width: 110, child: _field('number', 'Número')),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _field('complement', 'Complemento', required: false),
              ),
              const SizedBox(width: 12),
              Expanded(child: _field('neighborhood', 'Bairro')),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _field('city', 'Cidade', caps: TextCapitalization.words),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 90,
                child: _field(
                  'state',
                  'UF',
                  caps: TextCapitalization.characters,
                  formatters: [
                    FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
                    LengthLimitingTextInputFormatter(2),
                  ],
                  validate: (v) => v.length != 2 ? 'UF' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              FormaButton.secondary(
                label: 'Voltar',
                onPressed: _submitting ? null : () => setState(() => _step = 0),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FormaButton.primary(
                  label: 'Criar conta',
                  width: double.infinity,
                  isLoading: _submitting,
                  onPressed: () => unawaited(_submit()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    Widget step(int i, String label) {
      final done = i < current;
      final active = i == current;
      final color = active || done ? ext.primaryColor : ext.textHint;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active || done ? ext.primaryColor : Colors.transparent,
              border: Border.all(color: color, width: 1.5),
            ),
            child: done
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : Text(
                    '${i + 1}',
                    style: typo.caption12Med.copyWith(
                      color: active ? Colors.white : ext.textHint,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: typo.body14Medium.copyWith(
              color: active ? ext.textPrimary : ext.textMuted,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        step(0, 'Sua conta'),
        Expanded(
          child: Container(
            height: 1.5,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: current > 0 ? ext.primaryColor : ext.border,
          ),
        ),
        step(1, 'Sua empresa'),
      ],
    );
  }
}
