import 'package:flutter/material.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/core/format/formatters.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget.dart';

/// Uma fatia da composição do preço.
class CostSlice {
  const CostSlice(this.label, this.cents, this.color);

  final String label;
  final int cents;
  final Color color;
}

/// Fatias de custo do orçamento (cores como na web).
List<CostSlice> costSlices(Budget b) => [
  CostSlice('Filamentos', b.costs.filament, const Color(0xFF3B82F6)),
  CostSlice('Desperdício (AMS)', b.costs.waste, const Color(0xFFEF4444)),
  CostSlice('Energia', b.costs.energy, const Color(0xFFEAB308)),
  CostSlice('Máquina', b.costs.machine, const Color(0xFF06B6D4)),
  CostSlice('Setup', b.costs.setup, const Color(0xFFF97316)),
  CostSlice('Mão de obra', b.costs.labor, const Color(0xFF8B5CF6)),
  CostSlice(
    'Pós-processamento',
    b.costs.postProcessing + b.costs.supportRemoval,
    const Color(0xFFEC4899),
  ),
  CostSlice(
    'Embalagem e qualidade',
    b.costs.packaging + b.costs.qualityControl,
    const Color(0xFF84CC16),
  ),
  CostSlice('Falhas', b.costs.failure, const Color(0xFF64748B)),
  CostSlice('Overhead', b.overheadCents, const Color(0xFFA78BFA)),
  CostSlice('Margem de lucro', b.profitCents, const Color(0xFF00A699)),
].where((s) => s.cents > 0).toList();

/// Barra empilhada + legenda com percentuais.
class CostBreakdown extends StatelessWidget {
  const CostBreakdown({required this.budget, super.key});

  final Budget budget;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final slices = costSlices(budget);
    final total = slices.fold<int>(0, (s, c) => s + c.cents);
    if (total == 0) {
      return Text(
        'Sem custos calculados.',
        style: typo.body14.copyWith(color: ext.textMuted),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                for (final s in slices)
                  Expanded(
                    flex: (s.cents * 1000 / total).round().clamp(1, 1000),
                    child: Tooltip(
                      message: '${s.label}: ${Fmt.cents(s.cents)}',
                      child: Container(
                        margin: const EdgeInsets.only(right: 1.5),
                        color: s.color,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        for (final s in slices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: s.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.label,
                    style: typo.body13.copyWith(color: ext.textMuted),
                  ),
                ),
                Text(
                  Fmt.percent(s.cents * 100 / total, decimals: 0),
                  style: typo.caption12.copyWith(color: ext.textHint),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 92,
                  child: Text(
                    Fmt.cents(s.cents),
                    textAlign: TextAlign.right,
                    style: typo.body13.copyWith(
                      color: ext.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Resumo financeiro: subtotal → ajustes → total.
class PriceSummary extends StatelessWidget {
  const PriceSummary({required this.budget, this.dense = false, super.key});

  final Budget budget;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final b = budget;

    Widget line(
      String label,
      int cents, {
      String? hint,
      bool negative = false,
    }) => Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 3 : 5),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: label,
                children: [
                  if (hint != null)
                    TextSpan(
                      text: '  $hint',
                      style: typo.caption12.copyWith(color: ext.textHint),
                    ),
                ],
              ),
              style: typo.body14.copyWith(color: ext.textMuted),
            ),
          ),
          Text(
            '${negative ? '− ' : ''}${Fmt.cents(cents)}',
            style: typo.body14.copyWith(
              color: negative ? ext.successText : ext.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        line('Custos diretos', b.costs.direct),
        if (b.overheadCents > 0) line('Overhead', b.overheadCents),
        if (b.profitCents > 0) line('Margem de lucro', b.profitCents),
        if (b.discountCents > 0)
          line(
            'Desconto',
            b.discountCents,
            negative: true,
            hint:
                b.discountType == DiscountType.percent &&
                    b.discountValue != null
                ? Fmt.percent(b.discountValue, decimals: 0)
                : null,
          ),
        if (b.shippingCents > 0) line('Frete', b.shippingCents),
        if (b.taxCents > 0)
          line(
            'Impostos',
            b.taxCents,
            hint: 'inclusos · ${Fmt.percent(b.taxRateApplied)}',
          ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: dense ? 6 : 10),
          child: Divider(color: ext.border, height: 1),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                'Total',
                style: typo.title15.copyWith(color: ext.textPrimary),
              ),
            ),
            Text(
              Fmt.cents(b.totalCents),
              style: (dense ? typo.h4 : typo.h3).copyWith(
                color: ext.primaryColor,
                letterSpacing: -0.5,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
