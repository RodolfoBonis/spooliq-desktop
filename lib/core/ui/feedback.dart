import 'package:flutter/material.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';

/// Toasts padronizados.
abstract final class Toasts {
  static void success(
    BuildContext context,
    String message, {
    String? description,
  }) => FormaToast.show(
    context,
    message: message,
    description: description,
    variant: FormaToastVariant.success,
  );

  static void info(
    BuildContext context,
    String message, {
    String? description,
  }) => FormaToast.show(context, message: message, description: description);

  static void error(BuildContext context, Object error) {
    final message = error is ApiError
        ? error.message
        : 'Algo deu errado. Tente novamente.';
    final description = error is ValidationError && error.fields.isNotEmpty
        ? error.fields.values.join('\n')
        : null;
    FormaToast.show(
      context,
      message: message,
      description: description,
      variant: FormaToastVariant.error,
    );
  }
}

/// Confirmação de exclusão padronizada.
Future<bool> confirmDelete(
  BuildContext context, {
  required String what,
  String? detail,
}) => FormaConfirmDialog.show(
  context,
  title: 'Excluir $what?',
  message: detail ?? 'Esta ação não pode ser desfeita.',
  confirmLabel: 'Excluir',
  destructive: true,
);

/// Estado de erro com "tentar novamente".
class ErrorView extends StatelessWidget {
  const ErrorView({required this.message, this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FormaEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Não foi possível carregar',
        message: message,
        action: onRetry == null
            ? null
            : FormaButton.secondary(
                label: 'Tentar novamente',
                small: true,
                icon: const Icon(Icons.refresh, size: 16),
                onPressed: onRetry,
              ),
      ),
    );
  }
}

/// Indicador centralizado.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(strokeWidth: 2.5),
    ),
  );
}
