import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:spooliq_desktop/app/theme_mode_cubit.dart';
import 'package:spooliq_desktop/core/auth/session_user.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/format/formatters.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/core/routing/routes.dart';
import 'package:spooliq_desktop/features/auth/presentation/session_cubit.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_repository.dart';
import 'package:spooliq_desktop/features/customers/domain/customer_repository.dart';

/// Abre a paleta de comandos (⌘K / Ctrl+K).
Future<void> showAppCommandPalette(BuildContext context, SessionUser user) {
  final router = GoRouter.of(context);
  final theme = context.read<ThemeModeCubit>();
  final session = context.read<SessionCubit>();
  final brightness = Theme.of(context).brightness;
  final isMac = Theme.of(context).platform == TargetPlatform.macOS;
  final mod = isMac ? '⌘' : 'Ctrl ';

  final items = <FormaCommandItem>[
    if (user.hasOrganizationAccess) ...[
      FormaCommandItem(
        id: 'action.new-budget',
        label: 'Novo orçamento',
        icon: Icons.add_circle_outline,
        group: 'Ações',
        shortcut: '${mod}N',
        onSelected: () => router.go(Routes.budgetNew),
      ),
      FormaCommandItem(
        id: 'action.new-customer',
        label: 'Novo cliente',
        icon: Icons.person_add_alt_outlined,
        group: 'Ações',
        onSelected: () => router.go('${Routes.customers}?new=1'),
      ),
    ],
    FormaCommandItem(
      id: 'action.theme',
      label: brightness == Brightness.dark
          ? 'Mudar para tema claro'
          : 'Mudar para tema escuro',
      icon: Icons.contrast,
      group: 'Ações',
      keywords: const ['tema', 'dark', 'light', 'escuro', 'claro'],
      onSelected: () => unawaited(theme.toggle(brightness)),
    ),
    FormaCommandItem(
      id: 'action.logout',
      label: 'Sair da conta',
      icon: Icons.logout,
      group: 'Ações',
      onSelected: () => unawaited(session.logout()),
    ),
    for (final group in navigation)
      for (final e in group.entries)
        if (e.visible(user))
          FormaCommandItem(
            id: 'nav.${e.path}',
            label: e.label,
            subtitle: group.title,
            icon: e.icon,
            group: 'Ir para',
            keywords: e.keywords,
            onSelected: () => router.go(e.path),
          ),
  ];

  return FormaCommandPalette.show(
    context,
    items: items,
    onSearch: user.hasOrganizationAccess
        ? (q) => _searchRecords(q, router)
        : null,
  );
}

Future<List<FormaCommandItem>> _searchRecords(
  String query,
  GoRouter router,
) async {
  final q = query.trim();
  if (q.length < 2) return const [];
  try {
    final budgetsFuture = di<BudgetRepository>().list(
      filter: BudgetFilter(search: q),
      page: const PageQuery(pageSize: 5),
    );
    final customersFuture = di<CustomerRepository>().list(
      page: PageQuery(pageSize: 5, search: q),
    );
    final budgets = await budgetsFuture;
    final customers = await customersFuture;
    return [
      for (final b in budgets.items)
        FormaCommandItem(
          id: 'budget.${b.id}',
          label: b.name,
          subtitle: [
            Fmt.quote(b.quoteNumber),
            b.customerName,
            b.status.label,
            Fmt.cents(b.totalCents),
          ].where((s) => s.isNotEmpty).join(' · '),
          icon: Icons.request_quote_outlined,
          group: 'Orçamentos',
          keywords: [q],
          onSelected: () => router.go(Routes.budget(b.id)),
        ),
      for (final c in customers.items)
        FormaCommandItem(
          id: 'customer.${c.id}',
          label: c.name,
          subtitle: c.email ?? c.phone,
          icon: Icons.person_outline,
          group: 'Clientes',
          keywords: [q],
          onSelected: () => router.go(Routes.customer(c.id)),
        ),
    ];
  } on ApiError {
    return const [];
  }
}
