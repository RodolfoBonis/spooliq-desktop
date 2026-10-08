import 'package:flutter/material.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_status.dart';

/// Cores e ícones por status (espelha `status-badge.tsx` da web), com
/// variações para tema escuro.
class BudgetStatusStyle {
  const BudgetStatusStyle({
    required this.color,
    required this.surface,
    required this.foreground,
    required this.icon,
  });

  final Color color;
  final Color surface;
  final Color foreground;
  final IconData icon;

  // Fábrica com lookup em tabela; um construtor não agrega clareza aqui.
  // ignore: prefer_constructors_over_static_methods
  static BudgetStatusStyle of(BudgetStatus status, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    BudgetStatusStyle s(
      int color,
      int light,
      int fgLight,
      int fgDark,
      IconData icon,
    ) => BudgetStatusStyle(
      color: Color(color),
      surface: dark ? Color(color).withValues(alpha: 0.16) : Color(light),
      foreground: Color(dark ? fgDark : fgLight),
      icon: icon,
    );

    return switch (status) {
      BudgetStatus.draft => s(
        0xFF9D9D9D,
        0xFFF1F1F1,
        0xFF555555,
        0xFFC4C4C4,
        Icons.edit_note_rounded,
      ),
      BudgetStatus.sent => s(
        0xFF0288D1,
        0xFFE1F1FB,
        0xFF01579B,
        0xFF7CC3EE,
        Icons.send_rounded,
      ),
      BudgetStatus.approved => s(
        0xFF00A699,
        0xFFDDF4F1,
        0xFF00756C,
        0xFF5FD4C8,
        Icons.check_circle_rounded,
      ),
      BudgetStatus.printing => s(
        0xFFF4A261,
        0xFFFDEEDF,
        0xFFB4532A,
        0xFFF6C08F,
        Icons.print_rounded,
      ),
      BudgetStatus.completed => s(
        0xFF5A6268,
        0xFFE8EAEB,
        0xFF3D4347,
        0xFFB5BCC1,
        Icons.done_all_rounded,
      ),
      BudgetStatus.rejected => s(
        0xFFD93025,
        0xFFFBE3E1,
        0xFFB71C1C,
        0xFFF4A3A1,
        Icons.cancel_rounded,
      ),
      BudgetStatus.expired => s(
        0xFFD97706,
        0xFFFDF0DC,
        0xFF92400E,
        0xFFF5C27A,
        Icons.schedule_rounded,
      ),
      BudgetStatus.cancelled => s(
        0xFF991B1B,
        0xFFF3E4E4,
        0xFF991B1B,
        0xFFE29A9A,
        Icons.block_rounded,
      ),
    };
  }
}
