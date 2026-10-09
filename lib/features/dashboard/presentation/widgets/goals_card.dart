import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:intl/intl.dart';
import 'package:spooliq_desktop/core/format/formatters.dart';
import 'package:spooliq_desktop/core/ui/form_dialog.dart';
import 'package:spooliq_desktop/features/dashboard/domain/dashboard.dart';
import 'package:spooliq_desktop/features/dashboard/presentation/dashboard_cubit.dart';
import 'package:spooliq_desktop/features/dashboard/presentation/widgets/dashboard_section.dart';

/// Valor de uma meta formatado pela unidade (centavos, contagem ou %).
String formatGoalValue(GoalMetric metric, num value) => switch (metric.unit) {
  GoalUnit.cents => Fmt.cents(value.round()),
  GoalUnit.percent => Fmt.percent(value),
  GoalUnit.count => Fmt.number(value),
};

/// Metas do mês: progresso, projeção para o fim do mês e ritmo necessário.
class GoalsCard extends StatelessWidget {
  const GoalsCard({
    required this.section,
    required this.canManage,
    required this.onEdit,
    super.key,
  });

  final Section<GoalsSummary> section;
  final bool canManage;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final month = section.data?.month;
    final title = month == null || month.isEmpty
        ? 'Metas do mês'
        : 'Metas de ${_monthLabel(month)}';
    return DashCard(
      title: title,
      trailing: canManage
          ? TextButton(onPressed: onEdit, child: const Text('Definir metas'))
          : null,
      child: dashSection(context, section, height: 240, (summary) {
        final configured = summary.goals.where((g) => g.configured).toList();
        if (configured.isEmpty) {
          return Column(
            children: [
              dashEmpty(
                context,
                canManage
                    ? 'Defina metas de receita, lucro, vendas ou aprovação '
                          'para acompanhar o ritmo do mês.'
                    : 'Nenhuma meta definida. Peça a um administrador.',
              ),
              if (canManage)
                FormaButton.primary(
                  label: 'Definir metas',
                  small: true,
                  onPressed: onEdit,
                ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final g in configured) _GoalRow(goal: g)],
        );
      }),
    );
  }

  static String _monthLabel(String month) {
    final date = DateTime.tryParse('$month-01');
    if (date == null) return month;
    return DateFormat('MMMM', 'pt_BR').format(date);
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final g = goal;
    final done = g.progress >= 100;
    final barColor = done
        ? ext.successColor
        : g.offPace
        ? ext.warningColor
        : ext.primaryColor;
    final cumulative = g.metric != GoalMetric.approvalRate;

    final String status;
    final Color statusColor;
    if (done) {
      status = 'Meta batida 🎉';
      statusColor = ext.successText;
    } else if (!cumulative) {
      status = 'Meta: ${formatGoalValue(g.metric, g.target)}';
      statusColor = ext.textMuted;
    } else if (g.daysLeft == 0) {
      status = 'Último dia do mês';
      statusColor = ext.textMuted;
    } else {
      status =
          'Projeção ${formatGoalValue(g.metric, g.projected)} '
          '(${Fmt.percent(g.projectedProgress, decimals: 0)}) · '
          '${formatGoalValue(g.metric, g.requiredPerDay)}/dia nos '
          '${g.daysLeft} dias restantes';
      statusColor = g.offPace ? ext.warningText : ext.successText;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  g.metric.label,
                  style: typo.body13.copyWith(color: ext.textPrimary),
                ),
              ),
              Text(
                '${formatGoalValue(g.metric, g.current)} de '
                '${formatGoalValue(g.metric, g.target)}',
                style: typo.caption12Med.copyWith(color: ext.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (g.progress / 100).clamp(0, 1),
              minHeight: 6,
              backgroundColor: ext.appBackground,
              color: barColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(status, style: typo.caption12.copyWith(color: statusColor)),
        ],
      ),
    );
  }
}

/// Diálogo para definir as metas mensais. Campo vazio ou zero remove a meta.
Future<void> showGoalsDialog(
  BuildContext context,
  GoalsSummary? current,
) async {
  final cubit = context.read<DashboardCubit>();
  final values = <GoalMetric, num?>{
    for (final m in GoalMetric.values)
      m: switch (current?.of(m)) {
        final g? when g.configured =>
          m.unit == GoalUnit.cents ? g.target / 100 : g.target,
        _ => null,
      },
  };
  final saved = await showFormDialog<bool>(
    context,
    title: 'Metas do mês',
    description:
        'Valem para todos os meses até você mudar. '
        'Deixe em branco para não acompanhar uma métrica.',
    fields: (_) => [
      for (final m in GoalMetric.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FormaNumberField(
            label: m.label,
            value: values[m],
            decimals: m.unit == GoalUnit.count ? 0 : 2,
            min: 0,
            max: m.unit == GoalUnit.percent ? 100 : null,
            prefixText: m.unit == GoalUnit.cents ? r'R$' : null,
            suffixText: m.unit == GoalUnit.percent ? '%' : null,
            helperText: switch (m) {
              GoalMetric.revenue =>
                'Vendas aprovadas no mês, sem imposto e frete',
              GoalMetric.profit =>
                'Lucro das vendas aprovadas, já com descontos',
              GoalMetric.budgets => 'Orçamentos aprovados no mês',
              GoalMetric.approvalRate => 'Aprovados ÷ decididos no mês',
            },
            onChanged: (v) => values[m] = v,
          ),
        ),
    ],
    onSubmit: () async {
      await cubit.saveGoals(goalTargetsFromInput(values));
      return true;
    },
  );
  if (saved == true && context.mounted) {
    FormaToast.show(
      context,
      message: 'Metas salvas',
      variant: FormaToastVariant.success,
    );
  }
}

/// Converte os valores do formulário (reais, contagem, %) para a API
/// (centavos, contagem, %). Vazio vira 0, que remove a meta.
Map<GoalMetric, double> goalTargetsFromInput(Map<GoalMetric, num?> values) => {
  for (final e in values.entries)
    e.key: switch (e.value) {
      null => 0,
      final v when e.key.unit == GoalUnit.cents => (v * 100).roundToDouble(),
      final v => v.toDouble(),
    },
};

/// Abre o diálogo de metas a partir de qualquer ponto do dashboard.
void openGoalsDialog(BuildContext context) => unawaited(
  showGoalsDialog(context, context.read<DashboardCubit>().state.goals.data),
);
