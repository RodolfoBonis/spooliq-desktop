import 'package:flutter/material.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:spooliq_desktop/core/format/formatters.dart';
import 'package:spooliq_desktop/core/routing/routes.dart';
import 'package:spooliq_desktop/features/dashboard/domain/dashboard.dart';
import 'package:spooliq_desktop/features/dashboard/presentation/dashboard_cubit.dart';
import 'package:spooliq_desktop/features/dashboard/presentation/widgets/dashboard_section.dart';

/// Horas em texto curto: "5 h", "1,5 dia", "12 dias".
String formatHours(double hours) {
  if (hours <= 0) return '—';
  if (hours < 24) return '${Fmt.number(hours.clamp(1, 23))} h';
  final days = hours / 24;
  final whole = (days - days.roundToDouble()).abs() < 0.05;
  final text = days < 10 && !whole
      ? Fmt.number(days, decimals: 1)
      : Fmt.number(days);
  return '$text ${days < 1.05 ? 'dia' : 'dias'}';
}

/// Quanto os clientes demoram para decidir, expirações e motivos de recusa.
class ResponseTimesCard extends StatelessWidget {
  const ResponseTimesCard({required this.section, super.key});

  final Section<ResponseTimes> section;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    return DashCard(
      title: 'Tempo de resposta do cliente',
      child: dashSection(context, section, height: 220, (r) {
        if (r.decided == 0) {
          return dashEmpty(context, 'Nenhuma decisão de cliente no período.');
        }
        final maxBucket = r.buckets.fold<int>(
          1,
          (m, b) => b.count > m ? b.count : m,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _Stat('Para aprovar', formatHours(r.approvalMedianHours)),
                _Stat('75% aprovam em', formatHours(r.approvalP75Hours)),
                _Stat('Para recusar', formatHours(r.rejectionMedianHours)),
                _Stat(
                  'Expiram',
                  Fmt.percent(r.expirationRate, decimals: 0),
                  warn: r.expirationRate > 20,
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (final b in r.buckets)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 104,
                      child: Text(
                        b.label,
                        style: typo.caption12.copyWith(color: ext.textMuted),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: b.count / maxBucket,
                          minHeight: 8,
                          backgroundColor: ext.appBackground,
                          color: ext.primaryColor.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      child: Text(
                        '${b.count}',
                        textAlign: TextAlign.right,
                        style: typo.caption12Med.copyWith(
                          color: ext.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (r.recentRejections.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Últimas recusas',
                style: typo.caption12Med.copyWith(color: ext.textMuted),
              ),
              const SizedBox(height: 4),
              for (final x in r.recentRejections)
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => context.go(Routes.budget(x.budgetId)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text.rich(
                      TextSpan(
                        text: x.customer.isEmpty ? x.budgetName : x.customer,
                        style: typo.caption12Med.copyWith(
                          color: ext.textPrimary,
                        ),
                        children: [
                          TextSpan(
                            text: x.reason.isEmpty
                                ? ' · sem motivo informado'
                                : ' · “${x.reason}”',
                            style: typo.caption12.copyWith(
                              color: ext.textMuted,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ],
        );
      }),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.warn = false});

  final String label;
  final String value;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typo.caption12.copyWith(color: ext.textHint),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: typo.body14Medium.copyWith(
              color: warn ? ext.warningText : ext.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
