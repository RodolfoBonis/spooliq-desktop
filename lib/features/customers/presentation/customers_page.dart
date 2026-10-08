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
import 'package:spooliq_desktop/core/state/paged_list_cubit.dart';
import 'package:spooliq_desktop/core/ui/feedback.dart';
import 'package:spooliq_desktop/core/ui/page_layout.dart';
import 'package:spooliq_desktop/core/ui/paged_table.dart';
import 'package:spooliq_desktop/core/ui/search_field.dart';
import 'package:spooliq_desktop/features/auth/presentation/session_cubit.dart';
import 'package:spooliq_desktop/features/customers/domain/customer.dart';
import 'package:spooliq_desktop/features/customers/domain/customer_repository.dart';
import 'package:spooliq_desktop/features/customers/presentation/customer_form.dart';

class CustomersPage extends StatelessWidget {
  const CustomersPage({this.openCreate = false, super.key});

  final bool openCreate;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = PagedListCubit<Customer>(
          (q) => di<CustomerRepository>().list(page: q),
          idOf: (c) => c.id,
          initialQuery: const PageQuery(sortBy: 'name', sortAscending: true),
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: _CustomersView(openCreate: openCreate),
    );
  }
}

class _CustomersView extends StatefulWidget {
  const _CustomersView({required this.openCreate});

  final bool openCreate;

  @override
  State<_CustomersView> createState() => _CustomersViewState();
}

class _CustomersViewState extends State<_CustomersView> {
  @override
  void initState() {
    super.initState();
    if (widget.openCreate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_create());
      });
    }
  }

  Future<void> _create() async {
    final cubit = context.read<PagedListCubit<Customer>>();
    final saved = await showCustomerForm(context);
    if (saved == null || !mounted) return;
    cubit.upsert(saved);
    FormaToast.show(
      context,
      message: 'Cliente cadastrado',
      description: saved.name,
      variant: FormaToastVariant.success,
      actionLabel: 'Novo orçamento',
      onAction: () => context.go('${Routes.budgetNew}?customer=${saved.id}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canDelete = context.select<SessionCubit, bool>(
      (c) => c.state.user?.canDeleteCustomers ?? false,
    );
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final cubit = context.read<PagedListCubit<Customer>>();
    final muted = typo.body14.copyWith(color: ext.textMuted);

    return PageLayout(
      title: 'Clientes',
      subtitle: 'Quem compra de você, e quanto.',
      actions: [
        FormaButton.primary(
          label: 'Novo cliente',
          small: true,
          icon: const Icon(Icons.add, size: 18, color: Colors.white),
          onPressed: () => unawaited(_create()),
        ),
      ],
      toolbar: SearchField(
        hint: 'Buscar por nome, e-mail, telefone ou documento…',
        width: 380,
        onChanged: cubit.search,
      ),
      body: PagedTable<Customer>(
        itemLabel: 'clientes',
        onRowTap: (c) => context.go(Routes.customer(c.id)),
        columns: [
          FormaColumn(
            id: 'name',
            label: 'Cliente',
            flex: 3,
            sortable: true,
            cellBuilder: (_, c) => Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: ext.primarySurface,
                  child: Text(
                    c.initials,
                    style: typo.caption12Med.copyWith(color: ext.primaryColor),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typo.body14Medium.copyWith(
                      color: c.isActive ? ext.textPrimary : ext.textHint,
                    ),
                  ),
                ),
              ],
            ),
          ),
          FormaColumn(
            id: 'email',
            label: 'Contato',
            flex: 3,
            sortable: true,
            cellBuilder: (_, c) => Text(
              [c.email, c.phone].whereType<String>().join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: muted,
            ),
          ),
          FormaColumn(
            id: 'city',
            label: 'Cidade',
            flex: 2,
            cellBuilder: (_, c) => Text(
              c.location.isEmpty ? '—' : c.location,
              style: muted,
            ),
          ),
          FormaColumn(
            id: 'budgets',
            label: 'Orçamentos',
            width: 110,
            alignment: Alignment.centerRight,
            cellBuilder: (_, c) => Text('${c.budgetCount}', style: muted),
          ),
          FormaColumn(
            id: 'total',
            label: 'Faturado',
            width: 130,
            alignment: Alignment.centerRight,
            cellBuilder: (_, c) => Text(
              Fmt.cents(c.totalSpentCents),
              style: typo.body14Medium.copyWith(color: ext.textPrimary),
            ),
          ),
        ],
        trailingBuilder: (context, c) => FormaMenuButton(
          items: [
            FormaMenuItem(
              label: 'Novo orçamento',
              icon: Icons.request_quote_outlined,
              onTap: () => context.go('${Routes.budgetNew}?customer=${c.id}'),
            ),
            FormaMenuItem(
              label: 'Editar',
              icon: Icons.edit_outlined,
              onTap: () async {
                final saved = await showCustomerForm(context, customer: c);
                if (saved != null) cubit.upsert(saved);
              },
            ),
            if (canDelete) ...[
              const FormaMenuItem.divider(),
              FormaMenuItem(
                label: 'Excluir',
                icon: Icons.delete_outline,
                destructive: true,
                onTap: () => unawaited(_delete(context, c)),
              ),
            ],
          ],
        ),
        empty: FormaEmptyState(
          icon: Icons.people_alt_outlined,
          title: 'Nenhum cliente ainda',
          message: 'Cadastre seus clientes para criar orçamentos.',
          action: FormaButton.primary(
            label: 'Cadastrar cliente',
            small: true,
            onPressed: () => unawaited(_create()),
          ),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, Customer c) async {
    final cubit = context.read<PagedListCubit<Customer>>();
    if (!await confirmDelete(context, what: 'o cliente "${c.name}"')) return;
    try {
      await di<CustomerRepository>().delete(c.id);
      cubit.remove(c.id);
      if (context.mounted) Toasts.success(context, 'Cliente excluído');
    } on ApiError catch (e) {
      if (context.mounted) Toasts.error(context, e);
    }
  }
}
