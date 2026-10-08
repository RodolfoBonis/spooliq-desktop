import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:spooliq_desktop/core/routing/routes.dart';
import 'package:spooliq_desktop/features/auth/presentation/session_cubit.dart';
import 'package:spooliq_desktop/features/company/domain/company.dart';
import 'package:spooliq_desktop/features/company/presentation/current_company_cubit.dart';

/// Faixa de aviso: bloqueio de assinatura (402/403) ou fim do trial.
class SubscriptionBanner extends StatelessWidget {
  const SubscriptionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionCubit>().state;
    final company = context.select<CurrentCompanyCubit, Company?>(
      (c) => c.state.company,
    );
    final block = session.subscriptionBlock;
    final isOwner = session.user?.isOwner ?? false;

    if (block != null) {
      return _Banner(
        tone: _Tone.error,
        icon: Icons.lock_clock_outlined,
        message: block.message,
        actionLabel: isOwner ? 'Regularizar assinatura' : null,
        onAction: isOwner ? () => context.go(Routes.subscription) : null,
        onClose: () => context.read<SessionCubit>().clearSubscriptionBlock(),
      );
    }

    final days = company?.trialDaysLeft;
    if (company?.subscriptionStatus == SubscriptionStatus.trial &&
        days != null &&
        days <= 7) {
      return _Banner(
        tone: _Tone.warning,
        icon: Icons.hourglass_bottom_rounded,
        message: days == 0
            ? 'Seu período de teste termina hoje.'
            : 'Seu período de teste termina em $days '
                  '${days == 1 ? 'dia' : 'dias'}.',
        actionLabel: isOwner ? 'Escolher um plano' : null,
        onAction: isOwner ? () => context.go(Routes.subscription) : null,
      );
    }
    return const SizedBox.shrink();
  }
}

enum _Tone { warning, error }

class _Banner extends StatelessWidget {
  const _Banner({
    required this.tone,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.onClose,
  });

  final _Tone tone;
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final (bg, fg) = switch (tone) {
      _Tone.warning => (ext.warningSurface, ext.warningText),
      _Tone.error => (ext.errorSurface, ext.errorText),
    };
    return Material(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: typo.body14Medium.copyWith(color: fg),
              ),
            ),
            if (actionLabel != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(foregroundColor: fg),
                child: Text(actionLabel!),
              ),
            if (onClose != null)
              IconButton(
                tooltip: 'Fechar',
                iconSize: 18,
                color: fg,
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
          ],
        ),
      ),
    );
  }
}
