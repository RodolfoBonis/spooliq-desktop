import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:spooliq_desktop/app/shell/about_dialog.dart';
import 'package:spooliq_desktop/app/theme_mode_cubit.dart';
import 'package:spooliq_desktop/core/auth/permissions.dart';
import 'package:spooliq_desktop/core/auth/session_user.dart';
import 'package:spooliq_desktop/core/routing/routes.dart';
import 'package:spooliq_desktop/features/auth/presentation/session_cubit.dart';

/// Rodapé da sidebar: avatar, nome, papel e menu da conta.
class UserMenu extends StatelessWidget {
  const UserMenu({required this.user, required this.collapsed, super.key});

  final SessionUser user;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final themeMode = context.watch<ThemeModeCubit>().state;

    final avatar = FormaAvatar(
      initial: user.initials,
      color: ext.primaryColor,
      size: FormaAvatarSize.small,
    );

    return FormaMenuButton(
      items: [
        FormaMenuItem(
          label: 'Meu perfil',
          icon: Icons.person_outline,
          onTap: () => context.go(Routes.account),
        ),
        if (user.canSeeCompanySettings)
          FormaMenuItem(
            label: 'Configurações da empresa',
            icon: Icons.storefront_outlined,
            onTap: () => context.go(Routes.company),
          ),
        FormaMenuItem(
          label: switch (themeMode) {
            ThemeMode.system => 'Tema: automático',
            ThemeMode.light => 'Tema: claro',
            ThemeMode.dark => 'Tema: escuro',
          },
          icon: Icons.contrast,
          onTap: () {
            final next = switch (themeMode) {
              ThemeMode.system => ThemeMode.light,
              ThemeMode.light => ThemeMode.dark,
              ThemeMode.dark => ThemeMode.system,
            };
            unawaited(context.read<ThemeModeCubit>().set(next));
          },
        ),
        FormaMenuItem(
          label: 'Sobre o SpoolIQ',
          icon: Icons.info_outline,
          onTap: () => unawaited(showAboutSpoolIQ(context)),
        ),
        const FormaMenuItem.divider(),
        FormaMenuItem(
          label: 'Sair',
          icon: Icons.logout,
          destructive: true,
          onTap: () => unawaited(context.read<SessionCubit>().logout()),
        ),
      ],
      builder: (context, open) => Padding(
        padding: EdgeInsets.all(collapsed ? 0 : 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: open,
            mouseCursor: SystemMouseCursors.click,
            child: Padding(
              padding: EdgeInsets.all(collapsed ? 4 : 6),
              child: collapsed
                  ? Center(child: avatar)
                  : Row(
                      children: [
                        avatar,
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                user.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: typo.body14Medium.copyWith(
                                  color: ext.textPrimary,
                                ),
                              ),
                              Text(
                                user.primaryRole?.label ?? user.email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: typo.caption12.copyWith(
                                  color: ext.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.unfold_more, size: 18, color: ext.textHint),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
