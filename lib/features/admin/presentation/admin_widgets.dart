import 'package:flutter/material.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/core/ui/page_layout.dart';
import 'package:spooliq_desktop/features/company/domain/company.dart';

/// Badge do status de assinatura de uma empresa.
class SubscriptionStatusBadge extends StatelessWidget {
  const SubscriptionStatusBadge(this.status, {super.key});

  final SubscriptionStatus status;

  @override
  Widget build(BuildContext context) => FormaBadge(
    label: status.label,
    variant: switch (status) {
      SubscriptionStatus.active ||
      SubscriptionStatus.permanent => FormaBadgeVariant.success,
      SubscriptionStatus.trial => FormaBadgeVariant.info,
      SubscriptionStatus.overdue ||
      SubscriptionStatus.paymentPending => FormaBadgeVariant.warning,
      SubscriptionStatus.suspended ||
      SubscriptionStatus.cancelled => FormaBadgeVariant.error,
      SubscriptionStatus.unknown => FormaBadgeVariant.neutral,
    },
  );
}

/// Card de KPI simples.
class StatCard extends StatelessWidget {
  const StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.tone,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    return SectionCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (tone ?? ext.primaryColor).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: tone ?? ext.primaryColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: typo.caption12.copyWith(color: ext.textMuted),
                ),
                const SizedBox(height: 2),
                Text(value, style: typo.h4.copyWith(color: ext.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
