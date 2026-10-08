import 'package:flutter/material.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_status.dart';
import 'package:spooliq_desktop/features/budgets/presentation/widgets/budget_status_style.dart';

class BudgetStatusBadge extends StatelessWidget {
  const BudgetStatusBadge(this.status, {this.dense = false, super.key});

  final BudgetStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final style = BudgetStatusStyle.of(status, Theme.of(context).brightness);
    final typo = context.formaTypography;
    return Semantics(
      label: 'Status: ${status.label}',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 7 : 9,
          vertical: dense ? 2 : 3,
        ),
        decoration: BoxDecoration(
          color: style.surface,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(style.icon, size: dense ? 12 : 13, color: style.foreground),
            const SizedBox(width: 4),
            Text(
              status.label,
              style: (dense ? typo.caption12 : typo.caption12Med).copyWith(
                color: style.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
