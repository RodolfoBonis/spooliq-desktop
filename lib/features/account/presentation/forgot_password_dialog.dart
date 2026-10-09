import 'package:flutter/material.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/ui/form_dialog.dart';
import 'package:spooliq_desktop/features/account/domain/account.dart';

/// Pede o e-mail e solicita o link de redefinição de senha.
Future<void> showForgotPasswordDialog(
  BuildContext context, {
  String? email,
}) async {
  final controller = TextEditingController(text: email);
  final sent = await showFormDialog<bool>(
    context,
    title: 'Redefinir senha',
    description:
        'Enviaremos um link para você criar uma nova senha. '
        'Ele vale por 1 hora.',
    submitLabel: 'Enviar link',
    fields: (_) => [
      FormaTextField(
        label: 'E-mail',
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.emailAddress,
        validator: (v) {
          final value = v?.trim() ?? '';
          if (value.isEmpty) return 'Informe o e-mail';
          if (!value.contains('@')) return 'E-mail inválido';
          return null;
        },
      ),
    ],
    onSubmit: () async {
      await di<AccountRepository>().forgotPassword(controller.text);
      return true;
    },
  );
  if (sent != true || !context.mounted) return;
  // A API não revela se o e-mail existe, então a mensagem também não.
  FormaToast.show(
    context,
    message: 'Verifique seu e-mail',
    description:
        'Se houver uma conta com ${controller.text.trim()}, '
        'o link chegará em instantes.',
    variant: FormaToastVariant.success,
  );
}
