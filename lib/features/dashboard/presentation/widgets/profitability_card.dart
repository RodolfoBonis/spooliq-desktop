import 'package:flutter/material.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:spooliq_desktop/core/format/formatters.dart';
import 'package:spooliq_desktop/core/routing/routes.dart';
import 'package:spooliq_desktop/features/catalog/presentation/widgets/filament_swatch.dart';
import 'package:spooliq_desktop/features/dashboard/domain/dashboard.dart';
import 'package:spooliq_desktop/features/dashboard/presentation/dashboard_cubit.dart';
import 'package:spooliq_desktop/features/dashboard/presentation/widgets/dashboard_section.dart';

enum ProfitTab {
  materials('Materiais'),
  filaments('Filamentos'),
  customers('Clientes'),
  machines('Máquinas');

  const ProfitTab(this.label);

  final String label;
}

enum ProfitSort { revenue, profit, margin }

/// Ordena as linhas pela coluna escolhida (decrescente).
List<ProfitRow> sortProfitRows(List<ProfitRow> rows, ProfitSort sort) =>
    [...rows]..sort(
      (a, b) => switch (sort) {
        ProfitSort.revenue => b.revenueCents.compareTo(a.revenueCents),
        ProfitSort.profit => b.profitCents.compareTo(a.profitCents),
        ProfitSort.margin => b.margin.compareTo(a.margin),
      },
    );

/// Rentabilidade por material, filamento, cliente e máquina.
class ProfitabilityCard extends StatefulWidget {
  const ProfitabilityCard({required this.section, super.key});

  final Section<Profitability> section;

  @override
  State<ProfitabilityCard> createState() => _ProfitabilityCardState();
}

class _ProfitabilityCardState extends State<ProfitabilityCard> {
  ProfitTab _tab = ProfitTab.materials;
  ProfitSort _sort = ProfitSort.profit;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    return DashCard(
      title: 'Rentabilidade',
      trailing: widget.section.data == null
          ? null
          : Text(
              'Margem média ${Fmt.percent(widget.section.data!.averageMargin)}',
              style: typo.caption12Med.copyWith(color: ext.textMuted),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormaTabs(
            tabs: [for (final t in ProfitTab.values) FormaTab(label: t.label)],
            index: _tab.index,
            onChanged: (i) => setState(() => _tab = ProfitTab.values[i]),
          ),
          const SizedBox(height: 12),
          dashSection(context, widget.section, height: 260, (p) {
            final rows = switch (_tab) {
              ProfitTab.materials => p.byMaterial,
              ProfitTab.filaments => p.byFilament,
              ProfitTab.customers => p.byCustomer,
              ProfitTab.machines => p.byMachine,
            };
            if (rows.isEmpty) {
              return dashEmpty(context, 'Sem vendas aprovadas no período.');
            }
            return _Table(
              tab: _tab,
              rows: sortProfitRows(rows, _sort),
              sort: _sort,
              average: p.averageMargin,
              onSort: (s) => setState(() => _sort = s),
            );
          }),
        ],
      ),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({
    required this.tab,
    required this.rows,
    required this.sort,
    required this.average,
    required this.onSort,
  });

  final ProfitTab tab;
  final List<ProfitRow> rows;
  final ProfitSort sort;
  final double average;
  final ValueChanged<ProfitSort> onSort;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final extraLabel = switch (tab) {
      ProfitTab.materials || ProfitTab.filaments => 'Consumo',
      ProfitTab.customers => 'Desconto',
      ProfitTab.machines => 'Lucro/hora',
    };

    Widget header(String label, ProfitSort? s, {TextAlign? align}) {
      final active = s == sort;
      final text = Text(
        active ? '$label ↓' : label,
        textAlign: align,
        style: typo.caption12Med.copyWith(
          color: active ? ext.textPrimary : ext.textHint,
        ),
      );
      return s == null
          ? text
          : InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => onSort(s),
              child: text,
            );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Expanded(flex: 4, child: header('Nome', null)),
              Expanded(
                flex: 2,
                child: header(
                  'Receita',
                  ProfitSort.revenue,
                  align: TextAlign.right,
                ),
              ),
              Expanded(
                flex: 2,
                child: header(
                  'Lucro',
                  ProfitSort.profit,
                  align: TextAlign.right,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(flex: 3, child: header('Margem', ProfitSort.margin)),
              Expanded(
                flex: 2,
                child: header(extraLabel, null, align: TextAlign.right),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: ext.border),
        for (final r in rows)
          InkWell(
            onTap: tab == ProfitTab.customers
                ? () => context.go(Routes.customer(r.id))
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(flex: 4, child: _name(context, r)),
                  Expanded(
                    flex: 2,
                    child: Text(
                      Fmt.cents(r.revenueCents),
                      textAlign: TextAlign.right,
                      style: typo.body13.copyWith(color: ext.textMuted),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      Fmt.cents(r.profitCents),
                      textAlign: TextAlign.right,
                      style: typo.body13.copyWith(
                        color: r.profitCents < 0
                            ? ext.errorText
                            : ext.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(flex: 3, child: _marginBar(context, r.margin)),
                  Expanded(
                    flex: 2,
                    child: Text(
                      switch (tab) {
                        ProfitTab.materials ||
                        ProfitTab.filaments => Fmt.grams(r.grams),
                        ProfitTab.customers =>
                          r.discountRate > 0
                              ? Fmt.percent(r.discountRate)
                              : '—',
                        ProfitTab.machines =>
                          r.hours > 0
                              ? '${Fmt.cents(r.profitPerHourCents)}/h'
                              : '—',
                      },
                      textAlign: TextAlign.right,
                      style: typo.body13.copyWith(color: ext.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _name(BuildContext context, ProfitRow r) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final subtitle = switch (tab) {
      ProfitTab.customers =>
        '${r.count} ${r.count == 1 ? 'venda' : 'vendas'}'
            '${r.repeat ? ' · recorrente' : ''}',
      ProfitTab.machines =>
        r.hours > 0 ? '${Fmt.number(r.hours, decimals: 1)} h' : null,
      _ => r.subtitle,
    };
    return Row(
      children: [
        if (tab == ProfitTab.filaments)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilamentSwatch(colorHex: r.colorHex),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typo.body13.copyWith(color: ext.textPrimary),
              ),
              if (subtitle != null && subtitle.isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typo.caption12.copyWith(color: ext.textHint),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _marginBar(BuildContext context, double margin) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final color = marginColor(ext, margin, average);
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (margin / 60).clamp(0, 1),
              minHeight: 6,
              backgroundColor: ext.appBackground,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 48,
          child: Text(
            Fmt.percent(margin, decimals: 0),
            textAlign: TextAlign.right,
            style: typo.caption12Med.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
