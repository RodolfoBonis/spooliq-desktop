import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/format/formatters.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/state/paged_list_cubit.dart';
import 'package:spooliq_desktop/core/ui/feedback.dart';
import 'package:spooliq_desktop/core/ui/form_dialog.dart';
import 'package:spooliq_desktop/core/ui/page_layout.dart';
import 'package:spooliq_desktop/core/ui/paged_table.dart';
import 'package:spooliq_desktop/features/admin/domain/admin.dart';
import 'package:spooliq_desktop/features/admin/presentation/admin_widgets.dart';
import 'package:spooliq_desktop/features/company/domain/company.dart';
import 'package:spooliq_desktop/features/subscription/domain/billing.dart';
import 'package:url_launcher/url_launcher.dart';

/// Lista de empresas (ou de assinaturas) da plataforma.
class AdminCompaniesPage extends StatelessWidget {
  const AdminCompaniesPage({super.key, this.subscriptions = false});

  /// `true` usa `/admin/subscriptions` (mesma tela, foco em cobrança).
  final bool subscriptions;

  @override
  Widget build(BuildContext context) {
    return _AdminCompaniesView(
      key: ValueKey(subscriptions),
      subscriptions: subscriptions,
    );
  }
}

class _AdminCompaniesView extends StatefulWidget {
  const _AdminCompaniesView({required this.subscriptions, super.key});

  final bool subscriptions;

  @override
  State<_AdminCompaniesView> createState() => _AdminCompaniesViewState();
}

class _AdminCompaniesViewState extends State<_AdminCompaniesView> {
  final AdminRepository _repo = di<AdminRepository>();
  SubscriptionStatus? _status;
  late final _cubit = PagedListCubit<AdminCompany>(
    (q) => widget.subscriptions
        ? _repo.subscriptions(page: q, status: _status?.value)
        : _repo.companies(page: q, status: _status?.value),
    idOf: (c) => c.organizationId,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_cubit.load());
  }

  @override
  void dispose() {
    unawaited(_cubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final muted = typo.body14.copyWith(color: ext.textMuted);

    return BlocProvider.value(
      value: _cubit,
      child: PageLayout(
        title: widget.subscriptions ? 'Assinaturas' : 'Empresas',
        subtitle: widget.subscriptions
            ? 'Situação de cobrança de cada empresa.'
            : 'Todas as organizações da plataforma.',
        toolbar: Row(
          children: [
            SizedBox(
              width: 220,
              child: FormaSelect<SubscriptionStatus>(
                hint: 'Todos os status',
                clearable: true,
                value: _status,
                options: [
                  for (final s in SubscriptionStatus.values.where(
                    (s) => s != SubscriptionStatus.unknown,
                  ))
                    FormaSelectOption(value: s, label: s.label),
                ],
                onChanged: (v) {
                  setState(() => _status = v);
                  unawaited(_cubit.load(_cubit.state.query.copyWith(page: 1)));
                },
              ),
            ),
          ],
        ),
        body: PagedTable<AdminCompany>(
          itemLabel: 'empresas',
          onRowTap: (c) => unawaited(_open(context, c)),
          columns: [
            FormaColumn(
              id: 'name',
              label: 'Empresa',
              flex: 3,
              cellBuilder: (_, c) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typo.body14Medium.copyWith(color: ext.textPrimary),
                  ),
                  if (c.email != null)
                    Text(
                      c.email!,
                      style: typo.caption12.copyWith(color: ext.textMuted),
                    ),
                ],
              ),
            ),
            FormaColumn(
              id: 'status',
              label: 'Status',
              width: 170,
              cellBuilder: (_, c) => Align(
                alignment: Alignment.centerLeft,
                child: SubscriptionStatusBadge(c.status),
              ),
            ),
            FormaColumn(
              id: 'plan',
              label: 'Plano',
              cellBuilder: (_, c) => Text(c.plan ?? '—', style: muted),
            ),
            FormaColumn(
              id: 'trial',
              label: 'Fim do teste',
              width: 130,
              cellBuilder: (_, c) =>
                  Text(Fmt.date(c.trialEndsAt), style: muted),
            ),
            FormaColumn(
              id: 'created_at',
              label: 'Cadastro',
              width: 130,
              cellBuilder: (_, c) => Text(Fmt.date(c.createdAt), style: muted),
            ),
          ],
          empty: const FormaEmptyState(
            icon: Icons.domain_outlined,
            title: 'Nenhuma empresa encontrada',
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, AdminCompany c) =>
      FormaSideSheet.show<void>(
        context,
        builder: (_) => _CompanySheet(
          organizationId: c.organizationId,
          onChanged: () => unawaited(_cubit.refresh()),
        ),
      );
}

class _CompanySheet extends StatefulWidget {
  const _CompanySheet({required this.organizationId, required this.onChanged});

  final String organizationId;
  final VoidCallback onChanged;

  @override
  State<_CompanySheet> createState() => _CompanySheetState();
}

class _CompanySheetState extends State<_CompanySheet> {
  final AdminRepository _repo = di<AdminRepository>();
  AdminCompany? _company;
  List<Payment> _payments = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final c = await _repo.company(widget.organizationId);
      List<Payment> payments;
      try {
        payments = await _repo.companyPayments(widget.organizationId);
      } on ApiError {
        payments = const [];
      }
      if (mounted) {
        setState(() {
          _company = c;
          _payments = payments;
        });
      }
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _changeStatus() async {
    final c = _company!;
    var status = c.status == SubscriptionStatus.unknown
        ? SubscriptionStatus.active
        : c.status;
    final reason = TextEditingController();
    final ok = await showFormDialog<bool>(
      context,
      title: 'Alterar status',
      description: c.name,
      fields: (setState) => [
        FormaSelect<SubscriptionStatus>(
          label: 'Novo status',
          value: status,
          options: [
            for (final s in const [
              SubscriptionStatus.trial,
              SubscriptionStatus.active,
              SubscriptionStatus.suspended,
              SubscriptionStatus.cancelled,
              SubscriptionStatus.permanent,
            ])
              FormaSelectOption(value: s, label: s.label),
          ],
          onChanged: (v) => setState(() => status = v ?? status),
        ),
        FormaTextField(
          label: 'Motivo',
          controller: reason,
          maxLines: 2,
          validator: requiredValidator,
        ),
      ],
      onSubmit: () async {
        await _repo.setCompanyStatus(
          c.organizationId,
          status,
          reason: reason.text.trim(),
        );
        return true;
      },
    );
    if (ok != true || !mounted) return;
    widget.onChanged();
    Toasts.success(context, 'Status atualizado');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = _company;
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    return FormaSideSheetScaffold(
      title: c?.name ?? 'Empresa',
      subtitle: c?.email,
      headerActions: [
        if (c != null && !c.isPlatform)
          FormaButton.secondary(
            label: 'Alterar status',
            small: true,
            onPressed: () => unawaited(_changeStatus()),
          ),
      ],
      body: c == null
          ? (_error != null ? ErrorView(message: _error!) : const LoadingView())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SubscriptionStatusBadge(c.status),
                    if (c.isPlatform) ...[
                      const SizedBox(width: 8),
                      const FormaBadge(
                        label: 'Plataforma',
                        variant: FormaBadgeVariant.primary,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                for (final (label, value) in [
                  ('Plano', c.plan ?? '—'),
                  ('Telefone', c.phone ?? '—'),
                  ('Fim do teste', Fmt.date(c.trialEndsAt)),
                  ('Assinante desde', Fmt.date(c.startedAt)),
                  ('Cadastro', Fmt.date(c.createdAt)),
                  ('Organization ID', c.organizationId),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 140,
                          child: Text(
                            label,
                            style: typo.body13.copyWith(color: ext.textMuted),
                          ),
                        ),
                        Expanded(
                          child: SelectableText(
                            value,
                            style: typo.body13.copyWith(color: ext.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                Text(
                  'Pagamentos',
                  style: typo.title15.copyWith(color: ext.textPrimary),
                ),
                const SizedBox(height: 8),
                if (_payments.isEmpty)
                  Text(
                    'Nenhum pagamento.',
                    style: typo.body13.copyWith(color: ext.textMuted),
                  )
                else
                  for (final p in _payments)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(Fmt.money(p.amount)),
                      subtitle: Text('vence ${Fmt.date(p.dueDate)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FormaBadge(
                            label: p.statusLabel,
                            variant: p.isPaid
                                ? FormaBadgeVariant.success
                                : FormaBadgeVariant.warning,
                          ),
                          if (p.invoiceUrl != null)
                            IconButton(
                              tooltip: 'Fatura',
                              icon: const Icon(
                                Icons.open_in_new_rounded,
                                size: 18,
                              ),
                              onPressed: () => unawaited(
                                launchUrl(Uri.parse(p.invoiceUrl!)),
                              ),
                            ),
                        ],
                      ),
                    ),
              ],
            ),
    );
  }
}
