import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:spooliq_desktop/app/shell/about_dialog.dart';
import 'package:spooliq_desktop/app/theme_mode_cubit.dart';
import 'package:spooliq_desktop/core/auth/permissions.dart';
import 'package:spooliq_desktop/core/auth/session_user.dart';
import 'package:spooliq_desktop/core/routing/routes.dart';

/// Menu nativo do macOS (barra no topo da tela). Em outras plataformas
/// devolve só o [child]: lá os atalhos vêm do `Shortcuts` do shell.
class AppMenuBar extends StatelessWidget {
  const AppMenuBar({
    required this.user,
    required this.onSearch,
    required this.child,
    super.key,
  });

  final SessionUser user;
  final VoidCallback onSearch;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Os itens do sistema (Serviços, Ocultar…) checam defaultTargetPlatform.
    if (defaultTargetPlatform != TargetPlatform.macOS) return child;
    final org = user.canSeeOrganization;

    PlatformMenuItem go(String label, String path, LogicalKeyboardKey? key) =>
        PlatformMenuItem(
          label: label,
          shortcut: key == null ? null : SingleActivator(key, meta: true),
          onSelected: () => context.go(path),
        );

    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: 'SpoolIQ',
          menus: [
            PlatformMenuItem(
              label: 'Sobre o SpoolIQ',
              onSelected: () => unawaited(showAboutSpoolIQ(context)),
            ),
            const PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.servicesSubmenu,
                ),
              ],
            ),
            const PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.hide,
                ),
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.hideOtherApplications,
                ),
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.showAllApplications,
                ),
              ],
            ),
            const PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.quit,
            ),
          ],
        ),
        PlatformMenu(
          label: 'Arquivo',
          menus: [
            if (org) ...[
              PlatformMenuItem(
                label: 'Novo orçamento',
                shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyN,
                  meta: true,
                ),
                onSelected: () => context.go(Routes.budgetNew),
              ),
              PlatformMenuItem(
                label: 'Novo cliente',
                shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyN,
                  meta: true,
                  shift: true,
                ),
                onSelected: () => context.go('${Routes.customers}?new=1'),
              ),
            ],
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'Buscar…',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyK,
                    meta: true,
                  ),
                  onSelected: onSearch,
                ),
              ],
            ),
          ],
        ),
        PlatformMenu(
          label: 'Ir',
          menus: [
            go('Visão geral', Routes.dashboard, LogicalKeyboardKey.digit1),
            if (org) ...[
              go('Orçamentos', Routes.budgets, LogicalKeyboardKey.digit2),
              go('Clientes', Routes.customers, LogicalKeyboardKey.digit3),
              go('Filamentos', Routes.filaments, LogicalKeyboardKey.digit4),
              go('Modelos 3D', Routes.models, LogicalKeyboardKey.digit5),
              go('Atividades', Routes.activities, null),
            ],
          ],
        ),
        PlatformMenu(
          label: 'Visualizar',
          menus: [
            PlatformMenuItem(
              label: 'Alternar tema claro/escuro',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyL,
                meta: true,
                shift: true,
              ),
              onSelected: () => unawaited(
                context.read<ThemeModeCubit>().toggle(
                  Theme.of(context).brightness,
                ),
              ),
            ),
            const PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.toggleFullScreen,
            ),
          ],
        ),
        const PlatformMenu(
          label: 'Janela',
          menus: [
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.minimizeWindow,
            ),
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.zoomWindow,
            ),
          ],
        ),
      ],
      child: child,
    );
  }
}
