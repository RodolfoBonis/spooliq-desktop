import 'package:flutter/material.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/core/format/formatters.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_draft.dart';
import 'package:spooliq_desktop/features/budgets/domain/print_batch.dart';

/// Resumo do lote: "25 peças = 2,5 impressões · setup cobrado 3×".
String printBatchSummary(PrintBatch b) {
  final factor = b.factor;
  final whole = factor == factor.roundToDouble();
  final runs = Fmt.number(factor, decimals: whole ? 0 : 1);
  return '${b.quantity} ${b.quantity == 1 ? 'peça' : 'peças'} = $runs '
      '${factor == 1 ? 'impressão' : 'impressões'} · '
      'setup cobrado ${b.runs}×';
}

/// Controle de "peças por impressão" do item: com ele, tempo, filamento e
/// trabalho valem para UMA impressão do arquivo e escalam para a quantidade.
class PrintBatchBar extends StatelessWidget {
  const PrintBatchBar({required this.item, required this.onChanged, super.key});

  final BudgetItemDraft item;
  final ValueChanged<BudgetItemDraft Function(BudgetItemDraft)> onChanged;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final batch = item.batch;
    if (batch == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          // Os valores atuais passam a ser de uma impressão de `quantity`
          // peças: o total não muda até a quantidade mudar.
          onPressed: item.quantity < 1
              ? null
              : () => onChanged(
                  (i) => i.copyWith(unitsPerPrint: () => i.quantity),
                ),
          icon: const Icon(Icons.layers_outlined, size: 16),
          label: const Text(
            'O arquivo produz várias peças? Definir peças por impressão',
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: ext.infoSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.layers_outlined, size: 18, color: ext.infoText),
          const SizedBox(width: 10),
          SizedBox(
            width: 150,
            child: FormaNumberField(
              label: 'Peças por impressão',
              value: item.unitsPerPrint,
              min: 1,
              step: 1,
              suffixText: 'un.',
              onChanged: (v) {
                // Campo vazio (no meio da digitação) mantém o valor anterior.
                final units = v?.toInt();
                if (units == null || units < 1) return;
                onChanged(
                  (i) => i.copyWith(
                    unitsPerPrint: () => units.clamp(1, 1000000),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  printBatchSummary(batch),
                  style: typo.body13.copyWith(
                    color: ext.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tempo, filamento e mão de obra abaixo são de uma impressão; '
                  'o orçamento escala para a quantidade.',
                  style: typo.caption12.copyWith(color: ext.textMuted),
                ),
              ],
            ),
          ),
          TextButton(
            // Converte para os totais atuais: o orçamento não muda.
            onPressed: () => onChanged((i) => i.toTotals()),
            child: const Text('Usar valores totais'),
          ),
        ],
      ),
    );
  }
}
