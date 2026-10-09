import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:spooliq_desktop/app/shell/app_menu_bar.dart';
import 'package:spooliq_desktop/app/shell/command_palette.dart';
import 'package:spooliq_desktop/app/shell/offline_banner.dart';
import 'package:spooliq_desktop/app/shell/subscription_banner.dart';
import 'package:spooliq_desktop/app/shell/update_banner.dart';
import 'package:spooliq_desktop/app/shell/user_menu.dart';
import 'package:spooliq_desktop/app/theme_mode_cubit.dart';
import 'package:spooliq_desktop/core/auth/session_user.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/network/api_client.dart';
import 'package:spooliq_desktop/core/routing/routes.dart';
import 'package:spooliq_desktop/features/auth/presentation/session_cubit.dart';
import 'package:spooliq_desktop/features/company/domain/company.dart';
import 'package:spooliq_desktop/features/company/presentation/current_company_cubit.dart';

/// Intents globais de teclado.
class OpenCommandPaletteIntent extends Intent {
  const OpenCommandPaletteIntent();
}

class NewBudgetIntent extends Intent {
  const NewBudgetIntent();
}

/// Moldura da área logada: sidebar + topbar + conteúdo.
class AppShell extends StatefulWidget {
  const AppShell({required this.child, required this.location, super.key});

  final Widget child;
  final String location;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    unawaited(context.read<CurrentCompanyCubit>().load());
  }

  void _openPalette() {
    final user = context.read<SessionCubit>().state.user;
    if (user == null) return;
    unawaited(showAppCommandPalette(context, user));
  }

  void _newBudget() {
    final user = context.read<SessionCubit>().state.user;
    if (user?.canSeeOrganizationArea ?? false) context.go(Routes.budgetNew);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select<SessionCubit, SessionUser?>(
      (c) => c.state.user,
    );
    if (user == null) return const SizedBox.shrink();
    final isMac = Theme.of(context).platform == TargetPlatform.macOS;
    final meta = isMac ? LogicalKeyboardKey.meta : LogicalKeyboardKey.control;

    return AppMenuBar(
      user: user,
      onSearch: _openPalette,
      child: _shortcuts(meta),
    );
  }

  Widget _shortcuts(LogicalKeyboardKey meta) {
    final user = context.read<SessionCubit>().state.user!;
    final isMac = Theme.of(context).platform == TargetPlatform.macOS;
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(meta, LogicalKeyboardKey.keyK):
            const OpenCommandPaletteIntent(),
        LogicalKeySet(meta, LogicalKeyboardKey.keyN): const NewBudgetIntent(),
      },
      child: Actions(
        actions: {
          OpenCommandPaletteIntent: CallbackAction<OpenCommandPaletteIntent>(
            onInvoke: (_) {
              _openPalette();
              return null;
            },
          ),
          NewBudgetIntent: CallbackAction<NewBudgetIntent>(
            onInvoke: (_) {
              _newBudget();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Row(
              children: [
                _Sidebar(
                  user: user,
                  location: widget.location,
                  collapsed: _collapsed,
                  onToggle: () => setState(() => _collapsed = !_collapsed),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _TopBar(
                        location: widget.location,
                        isMac: isMac,
                        onSearch: _openPalette,
                        onNewBudget: user.canSeeOrganizationArea
                            ? _newBudget
                            : null,
                      ),
                      const UpdateBanner(),
                      OfflineBanner(
                        status: di(),
                        ping: () => di<ApiClient>().ping(),
                      ),
                      const SubscriptionBanner(),
                      Expanded(child: widget.child),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension on SessionUser {
  bool get canSeeOrganizationArea => hasOrganizationAccess;
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.user,
    required this.location,
    required this.collapsed,
    required this.onToggle,
  });

  final SessionUser user;
  final String location;
  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final current = navEntryFor(location)?.path;
    final sections = <FormaSidebarSection>[
      for (final group in navigation)
        if (group.entries.any((e) => e.visible(user)))
          FormaSidebarSection(
            title: group.title,
            items: [
              for (final e in group.entries)
                if (e.visible(user))
                  FormaSidebarItem(
                    icon: e.icon,
                    label: e.label,
                    selected: e.path == current,
                    onTap: () => context.go(e.path),
                  ),
            ],
          ),
    ];

    return FormaSidebar(
      collapsed: collapsed,
      onToggleCollapsed: onToggle,
      header: _Brand(collapsed: collapsed),
      sections: sections,
      footer: UserMenu(user: user, collapsed: collapsed),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final company = context.select<CurrentCompanyCubit, Company?>(
      (c) => c.state.company,
    );
    final logo = company?.logoUrl;

    final mark = Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ext.primaryColor,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        'S',
        style: typo.title16.copyWith(color: ext.onPrimary ?? Colors.white),
      ),
    );

    // O FormaSidebar já aplica padding no header; recolhido, só centraliza.
    if (collapsed) {
      return SizedBox(
        height: 48,
        child: Center(
          child: logo == null
              ? mark
              : ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    logo,
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => mark,
                  ),
                ),
        ),
      );
    }

    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            if (logo != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  logo,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => mark,
                ),
              )
            else
              mark,
            if (!collapsed) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Spool'),
                          TextSpan(
                            text: 'IQ',
                            style: TextStyle(color: ext.primaryColor),
                          ),
                        ],
                      ),
                      style: typo.title16.copyWith(color: ext.textPrimary),
                    ),
                    if (company != null)
                      Text(
                        company.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typo.caption12.copyWith(color: ext.textMuted),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.location,
    required this.isMac,
    required this.onSearch,
    required this.onNewBudget,
  });

  final String location;
  final bool isMac;
  final VoidCallback onSearch;
  final VoidCallback? onNewBudget;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return FormaTopBar(
      title: navEntryFor(location)?.label,
      center: _SearchTrigger(
        onTap: onSearch,
        shortcut: isMac ? '⌘K' : 'Ctrl K',
      ),
      actions: [
        Tooltip(
          message: brightness == Brightness.dark ? 'Tema claro' : 'Tema escuro',
          child: FormaIconButton(
            icon: Icon(
              brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              size: 20,
            ),
            onPressed: () =>
                unawaited(context.read<ThemeModeCubit>().toggle(brightness)),
          ),
        ),
        if (onNewBudget != null) ...[
          const SizedBox(width: 8),
          FormaButton.primary(
            label: 'Novo orçamento',
            small: true,
            icon: const Icon(Icons.add, size: 18, color: Colors.white),
            onPressed: onNewBudget,
          ),
        ],
      ],
    );
  }
}

class _SearchTrigger extends StatelessWidget {
  const _SearchTrigger({required this.onTap, required this.shortcut});

  final VoidCallback onTap;
  final String shortcut;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Material(
        color: ext.appBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: ext.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          mouseCursor: SystemMouseCursors.click,
          child: SizedBox(
            height: 36,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.search, size: 18, color: ext.textHint),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Buscar orçamentos, clientes, páginas…',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typo.body14.copyWith(color: ext.textHint),
                    ),
                  ),
                  FormaKbd(shortcut),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
