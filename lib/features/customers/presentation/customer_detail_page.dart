import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:spooliq_desktop/core/auth/permissions.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/format/formatters.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/core/routing/routes.dart';
import 'package:spooliq_desktop/core/ui/feedback.dart';
import 'package:spooliq_desktop/core/ui/page_layout.dart';
import 'package:spooliq_desktop/features/auth/presentation/session_cubit.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_repository.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_status.dart';
import 'package:spooliq_desktop/features/budgets/presentation/widgets/budget_status_badge.dart';
import 'package:spooliq_desktop/features/customers/domain/customer.dart';
import 'package:spooliq_desktop/features/customers/domain/customer_repository.dart';
import 'package:spooliq_desktop/features/customers/presentation/customer_form.dart';

class CustomerDetailPage extends StatefulWidget {
  const CustomerDetailPage({required this.id, super.key});

  final String id;

  @override
  State<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends State<CustomerDetailPage> {
  Customer? _customer;
  List<Budget> _budgets = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final customer = await di<CustomerRepository>().get(widget.id);
      final budgets = await di<BudgetRepository>().list(
        filter: BudgetFilter(customerId: widget.id),
        page: const PageQuery(pageSize: 100, sortBy: 'created_at'),
      );
      if (!mounted) return;
      setState(() {
        _customer = customer;
        _budgets = budgets.items;
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _customer;
    if (c == null) {
      return _error != null
          ? ErrorView(message: _error!, onRetry: () => unawaited(_load()))
          : const LoadingView();
    }
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final canDelete = context.select<SessionCubit, bool>(
      (s) => s.state.user?.canDeleteCustomers ?? false,
    );
    final won = _budgets.where(
      (b) =>
          b.status == BudgetStatus.approved ||
          b.status == BudgetStatus.printing ||
          b.status == BudgetStatus.completed,
    );
    final wonTotal = won.fold<int>(0, (s, b) => s + b.totalCents);
    final decided = _budgets.where(
      (b) => b.status != BudgetStatus.draft && b.status != BudgetStatus.sent,
    );

    return PageLayout(
      leading: Tooltip(
        message: 'Voltar para clientes',
        child: FormaIconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          onPressed: () => context.go(Routes.customers),
        ),
      ),
      title: c.name,
      subtitle: [
        if (!c.isActive) 'Inativo',
        if (c.createdAt != null) 'cliente desde ${Fmt.date(c.createdAt)}',
      ].join(' · '),
      actions: [
        FormaButton.secondary(
          label: 'Editar',
          small: true,
          icon: const Icon(Icons.edit_outlined, size: 16),
          onPressed: () async {
            final saved = await showCustomerForm(context, customer: c);
            if (saved != null) unawaited(_load());
          },
        ),
        FormaButton.primary(
          label: 'Novo orçamento',
          small: true,
          icon: const Icon(Icons.add, size: 18, color: Colors.white),
          onPressed: () => context.go('${Routes.budgetNew}?customer=${c.id}'),
        ),
        if (canDelete)
          FormaMenuButton(
            items: [
              FormaMenuItem(
                label: 'Excluir cliente',
                icon: Icons.delete_outline,
                destructive: true,
                onTap: () async {
                  if (!await confirmDelete(context, what: 'o cliente')) return;
                  try {
                    await di<CustomerRepository>().delete(c.id);
                    if (context.mounted) context.go(Routes.customers);
                  } on ApiError catch (e) {
                    if (context.mounted) Toasts.error(context, e);
                  }
                },
              ),
            ],
          ),
      ],
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Kpi('Orçamentos', '${_budgets.length}'),
              _Kpi('Fechados', '${won.length}'),
              _Kpi('Faturado', Fmt.cents(wonTotal)),
              _Kpi(
                'Ticket médio',
                won.isEmpty ? '—' : Fmt.cents(wonTotal ~/ won.length),
              ),
              _Kpi(
                'Conversão',
                decided.isEmpty
                    ? '—'
                    : Fmt.percent(
                        won.length * 100 / decided.length,
                        decimals: 0,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 320,
                child: SectionCard(
                  title: 'Contato',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (icon, value) in [
                        (Icons.mail_outline, c.email),
                        (Icons.phone_outlined, c.phone),
                        (Icons.badge_outlined, c.document),
                        (
                          Icons.place_outlined,
                          [c.address, c.location, c.zipCode]
                              .whereType<String>()
                              .where((s) => s.isNotEmpty)
                              .join(' · '),
                        ),
                      ])
                        if (value != null && value.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(icon, size: 16, color: ext.textHint),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: SelectableText(
                                    value,
                                    style: typo.body14.copyWith(
                                      color: ext.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      if (c.notes != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          c.notes!,
                          style: typo.body13.copyWith(color: ext.textMuted),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: SectionCard(
                  title: 'Orçamentos',
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: _budgets.isEmpty
                      ? FormaEmptyState(
                          compact: true,
                          icon: Icons.request_quote_outlined,
                          title: 'Nenhum orçamento',
                          action: FormaButton.primary(
                            label: 'Criar orçamento',
                            small: true,
                            onPressed: () => context.go(
                              '${Routes.budgetNew}?customer=${c.id}',
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            for (final b in _budgets)
                              InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => context.go(Routes.budget(b.id)),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 6,
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 56,
                                        child: Text(
                                          Fmt.quote(b.quoteNumber),
                                          style: typo.caption12.copyWith(
                                            color: ext.textHint,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          b.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: typo.body14Medium.copyWith(
                                            color: ext.textPrimary,
                                          ),
                                        ),
                                      ),
                                      BudgetStatusBadge(b.status, dense: true),
                                      const SizedBox(width: 16),
                                      SizedBox(
                                        width: 110,
                                        child: Text(
                                          Fmt.cents(b.totalCents),
                                          textAlign: TextAlign.right,
                                          style: typo.body14.copyWith(
                                            color: ext.textPrimary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      SizedBox(
                                        width: 84,
                                        child: Text(
                                          Fmt.date(b.createdAt),
                                          style: typo.caption12.copyWith(
                                            color: ext.textMuted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: SectionCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: typo.caption12.copyWith(color: ext.textMuted)),
              const SizedBox(height: 6),
              Text(value, style: typo.h4.copyWith(color: ext.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}
