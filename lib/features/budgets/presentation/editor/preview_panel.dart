import 'package:flutter/material.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/core/format/formatters.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget.dart';
import 'package:spooliq_desktop/features/budgets/presentation/editor/budget_editor_cubit.dart';
import 'package:spooliq_desktop/features/budgets/presentation/widgets/cost_breakdown.dart';

/// Painel lateral com o cálculo ao vivo do servidor.
class PreviewPanel extends StatelessWidget {
  const PreviewPanel({required this.state, super.key});

  final BudgetEditorState state;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final preview = state.preview;
    final previewable = state.draft.isPreviewable;

    return Container(
      decoration: BoxDecoration(
        color: ext.cardBackground,
        borderRadius: BorderRadius.circular(context.formaShape.cardRadius),
        border: Border.all(color: ext.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Preço calculado',
                    style: typo.title15.copyWith(color: ext.textPrimary),
                  ),
                ),
                // Só monta o spinner enquanto calcula: um indicador invisível
                // continuaria animando (e consumindo CPU) para sempre.
                if (state.previewing)
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.8),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'calculando',
                            overflow: TextOverflow.ellipsis,
                            style: typo.caption12.copyWith(color: ext.textHint),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          if (!previewable)
            const _Hint(
              icon: Icons.auto_graph_rounded,
              text:
                  'Preencha o nome do produto e ao menos um filamento com '
                  'quantidade para ver o preço em tempo real.',
            )
          else if (state.previewError != null && preview == null)
            _Hint(
              icon: Icons.error_outline_rounded,
              text: state.previewError!,
              error: true,
            )
          else if (preview == null)
            const Padding(
              padding: EdgeInsets.all(20),
              child: FormaSkeleton.box(height: 160),
            )
          else
            AnimatedOpacity(
              opacity: state.previewing ? 0.55 : 1,
              duration: const Duration(milliseconds: 150),
              child: _PreviewBody(preview: preview, error: state.previewError),
            ),
        ],
      ),
    );
  }
}

class _PreviewBody extends StatelessWidget {
  const _PreviewBody({required this.preview, this.error});

  final Budget preview;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final muted = typo.caption12.copyWith(color: ext.textMuted);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            Fmt.cents(preview.totalCents),
            style: typo.h2.copyWith(
              color: ext.primaryColor,
              letterSpacing: -0.8,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            [
              if (preview.totalPrintTimeDisplay.isNotEmpty)
                '${preview.totalPrintTimeDisplay} de impressão',
              _itemsLabel(preview.items.length),
            ].join(' · '),
            style: muted,
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: typo.caption12.copyWith(color: ext.errorColor)),
          ],
          const SizedBox(height: 16),
          for (final item in preview.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typo.body13.copyWith(color: ext.textPrimary),
                        ),
                        Text(
                          '${item.quantity} × '
                          '${Fmt.cents(item.saleUnitPriceCents)}',
                          style: muted,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    Fmt.cents(item.saleTotalCents),
                    style: typo.body13.copyWith(
                      color: ext.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: ext.border, height: 1),
          ),
          PriceSummary(budget: preview, dense: true),
          const SizedBox(height: 20),
          Text(
            'Composição',
            style: typo.caption12Med.copyWith(color: ext.textPrimary),
          ),
          const SizedBox(height: 10),
          CostBreakdown(budget: preview),
          if (preview.stockWarnings.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ext.warningSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 16,
                    color: ext.warningText,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Estoque insuficiente: ${_names(preview.stockWarnings)}',
                      style: typo.caption12.copyWith(color: ext.warningText),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _itemsLabel(int n) => '$n ${n == 1 ? 'item' : 'itens'}';

String _names(List<StockWarning> w) => w.map((e) => e.filamentName).join(', ');

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text, this.error = false});

  final IconData icon;
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: error ? ext.errorColor : ext.textHint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: typo.body13.copyWith(
                color: error ? ext.errorColor : ext.textMuted,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
