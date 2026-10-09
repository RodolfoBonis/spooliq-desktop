import 'package:flutter/material.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:spooliq_desktop/core/format/formatters.dart';
import 'package:spooliq_desktop/core/routing/routes.dart';
import 'package:spooliq_desktop/features/dashboard/domain/dashboard.dart';

/// Linha do log de atividades ("criou orçamento X · há 2 h").
/// Orçamentos e clientes abrem ao clicar.
class ActivityTile extends StatelessWidget {
  const ActivityTile(this.activity, {this.absoluteTime = false, super.key});

  final Activity activity;

  /// Data/hora completa em vez de "há 2 h" (útil na página do log).
  final bool absoluteTime;

  /// Rota da entidade, ou null quando não há tela (ou foi excluída).
  static String? routeFor(Activity a) {
    if (a.action == 'deleted') return null;
    return switch (a.entityType) {
      'budget' => Routes.budget(a.entityId),
      'customer' => Routes.customer(a.entityId),
      _ => null,
    };
  }

  static String verb(String action) => switch (action) {
    'created' => 'criou',
    'updated' => 'atualizou',
    'deleted' => 'excluiu',
    'status_changed' => 'mudou o status de',
    'approved' => 'aprovou',
    'rejected' => 'rejeitou',
    _ => action,
  };

  static String noun(String entity) => switch (entity) {
    'budget' => 'orçamento',
    'customer' => 'cliente',
    'filament' => 'filamento',
    'material' => 'material',
    'brand' => 'marca',
    'preset' => 'preset',
    'model3d' => 'modelo 3D',
    'stock_movement' => 'estoque',
    _ => entity,
  };

  static IconData icon(String entity) => switch (entity) {
    'budget' => Icons.request_quote_outlined,
    'customer' => Icons.person_outline,
    'filament' || 'stock_movement' => Icons.blur_circular_outlined,
    'model3d' => Icons.view_in_ar_outlined,
    _ => Icons.edit_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final a = activity;
    final route = routeFor(a);
    final onTap = route == null ? null : () => context.go(route);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: ext.appBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon(a.entityType), size: 16, color: ext.textMuted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: '${verb(a.action)} ${noun(a.entityType)} ',
                  style: typo.body13.copyWith(color: ext.textMuted),
                  children: [
                    TextSpan(
                      text: a.entityName,
                      style: typo.body13.copyWith(
                        color: ext.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (absoluteTime &&
                        a.description != null &&
                        a.description!.isNotEmpty)
                      TextSpan(text: ' · ${a.description}'),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              absoluteTime ? Fmt.dateTime(a.at) : Fmt.relative(a.at),
              style: typo.caption12.copyWith(color: ext.textHint),
            ),
          ],
        ),
      ),
    );
  }
}
