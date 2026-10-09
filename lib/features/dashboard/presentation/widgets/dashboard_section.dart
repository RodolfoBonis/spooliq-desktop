import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/core/ui/page_layout.dart';
import 'package:spooliq_desktop/features/dashboard/presentation/dashboard_cubit.dart';

/// Card padrão do dashboard.
class DashCard extends StatelessWidget {
  const DashCard({
    required this.title,
    required this.child,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) =>
      SectionCard(title: title, trailing: trailing, child: child);
}

/// Conteúdo padrão de uma seção: skeleton, erro (com "tentar de novo")
/// ou dados.
Widget dashSection<T>(
  BuildContext context,
  Section<T> s,
  Widget Function(T data) builder, {
  double height = 180,
}) {
  final ext = Theme.of(context).extension<FormaThemeExtension>()!;
  final typo = context.formaTypography;
  if (s.loading) return FormaSkeleton.box(height: height);
  if (s.error != null) {
    return SizedBox(
      height: height,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 16, color: ext.textHint),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                s.error!,
                style: typo.caption12.copyWith(color: ext.textMuted),
              ),
            ),
            TextButton(
              onPressed: () => unawaited(context.read<DashboardCubit>().load()),
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
  return builder(s.data as T);
}

Widget dashEmpty(BuildContext context, String text) {
  final ext = Theme.of(context).extension<FormaThemeExtension>()!;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: context.formaTypography.body13.copyWith(color: ext.textHint),
      ),
    ),
  );
}

/// Cor da margem: verde acima da média, âmbar perto dela, vermelho bem abaixo.
Color marginColor(FormaThemeExtension ext, double margin, double average) {
  if (margin < 0 || (average > 0 && margin < average * 0.7)) {
    return ext.errorColor;
  }
  if (average > 0 && margin < average) return ext.warningColor;
  return ext.successColor;
}
