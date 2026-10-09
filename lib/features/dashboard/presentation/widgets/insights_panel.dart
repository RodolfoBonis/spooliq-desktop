import 'package:flutter/material.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:spooliq_desktop/core/routing/routes.dart';
import 'package:spooliq_desktop/features/dashboard/domain/dashboard.dart';
import 'package:spooliq_desktop/features/dashboard/presentation/dashboard_cubit.dart';
import 'package:spooliq_desktop/features/dashboard/presentation/widgets/dashboard_section.dart';

/// Rota da ação de um insight; null quando a ação não é navegação (metas).
String? insightRoute(InsightAction a) {
  final id = a.id;
  final hasId = id != null && id.isNotEmpty;
  return switch (a.target) {
    'budgets' =>
      a.filter == null
          ? Routes.budgets
          : '${Routes.budgets}?status=${a.filter}',
    'budget' when hasId => Routes.budget(id),
    'customer' when hasId => Routes.customer(id),
    'customer' || 'customers' => Routes.customers,
    'filament' || 'filaments' => Routes.filaments,
    'materials' => Routes.materials,
    'machines' => Routes.machines,
    'costs' => Routes.costs,
    _ => null,
  };
}

/// "O que fazer agora": recomendações ordenadas por severidade e impacto.
class InsightsPanel extends StatelessWidget {
  const InsightsPanel({
    required this.section,
    required this.onOpenGoals,
    super.key,
  });

  final Section<List<Insight>> section;
  final VoidCallback onOpenGoals;

  @override
  Widget build(BuildContext context) {
    return DashCard(
      title: 'O que fazer agora',
      child: dashSection(context, section, height: 120, (items) {
        if (items.isEmpty) {
          return dashEmpty(
            context,
            'Tudo em ordem: nenhum ponto de atenção no período. 🎉',
          );
        }
        return LayoutBuilder(
          builder: (context, c) {
            final columns = c.maxWidth > 1100
                ? 3
                : c.maxWidth > 700
                ? 2
                : 1;
            const gap = 12.0;
            final width = (c.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final i in items)
                  SizedBox(
                    width: width,
                    child: _InsightTile(insight: i, onOpenGoals: onOpenGoals),
                  ),
              ],
            );
          },
        );
      }),
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({required this.insight, required this.onOpenGoals});

  final Insight insight;
  final VoidCallback onOpenGoals;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final (icon, color, surface) = switch (insight.severity) {
      InsightSeverity.critical => (
        Icons.error_outline_rounded,
        ext.errorText,
        ext.errorSurface,
      ),
      InsightSeverity.warning => (
        Icons.warning_amber_rounded,
        ext.warningText,
        ext.warningSurface,
      ),
      InsightSeverity.positive => (
        Icons.trending_up_rounded,
        ext.successText,
        ext.successSurface,
      ),
      InsightSeverity.info => (
        Icons.lightbulb_outline_rounded,
        ext.infoText,
        ext.infoSurface,
      ),
    };
    final action = insight.action;
    final route = action == null ? null : insightRoute(action);
    final onAction = action == null
        ? null
        : action.target == 'goals'
        ? onOpenGoals
        : route == null
        ? null
        : () => context.go(route);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ext.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ext.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  insight.title,
                  style: typo.body14Medium.copyWith(color: ext.textPrimary),
                ),
              ),
              if (insight.metric != null) ...[
                const SizedBox(width: 8),
                Text(
                  insight.metric!,
                  style: typo.body14Medium.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            insight.detail,
            style: typo.caption12.copyWith(color: ext.textMuted, height: 1.4),
          ),
          if (onAction != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                label: Text(action!.label),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
