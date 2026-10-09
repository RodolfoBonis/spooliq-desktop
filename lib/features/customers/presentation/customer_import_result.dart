import 'package:flutter/material.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/features/customers/domain/customer_repository.dart';

/// Resumo da importação: contagens e as linhas que não viraram cliente.
Future<void> showCustomerImportResult(
  BuildContext context,
  CustomerImportResult result,
) => FormaDialog.show<void>(
  context,
  title: 'Importação concluída',
  width: 560,
  child: _ImportResultBody(result: result),
);

class _ImportResultBody extends StatelessWidget {
  const _ImportResultBody({required this.result});

  final CustomerImportResult result;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final problems = result.problems;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FormaBadge(
              label: '${result.created} criado(s)',
              variant: FormaBadgeVariant.success,
            ),
            if (result.skipped > 0)
              FormaBadge(
                label: '${result.skipped} ignorado(s)',
                variant: FormaBadgeVariant.warning,
              ),
            if (result.failed > 0)
              FormaBadge(
                label: '${result.failed} com erro',
                variant: FormaBadgeVariant.error,
              ),
          ],
        ),
        if (problems.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Linhas que não foram importadas',
            style: typo.body14Medium.copyWith(color: ext.textPrimary),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final r in problems)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      _describe(r),
                      style: typo.body13.copyWith(
                        color: r.status == 'error'
                            ? ext.errorText
                            : ext.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: FormaButton.primary(
            label: 'Fechar',
            small: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}

String _describe(CustomerImportRow r) {
  final name = r.name == null || r.name!.isEmpty ? '' : ' (${r.name})';
  return 'Linha ${r.line}$name: ${r.message ?? r.status}';
}
