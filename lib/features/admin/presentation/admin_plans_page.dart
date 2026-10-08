import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/format/formatters.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/ui/feedback.dart';
import 'package:spooliq_desktop/core/ui/form_dialog.dart';
import 'package:spooliq_desktop/core/ui/page_layout.dart';
import 'package:spooliq_desktop/features/admin/domain/admin.dart';
import 'package:spooliq_desktop/features/admin/presentation/admin_widgets.dart';
import 'package:spooliq_desktop/features/subscription/domain/billing.dart';

class AdminPlansPage extends StatefulWidget {
  const AdminPlansPage({super.key});

  @override
  State<AdminPlansPage> createState() => _AdminPlansPageState();
}

class _AdminPlansPageState extends State<AdminPlansPage> {
  final AdminRepository _repo = di<AdminRepository>();
  List<Plan>? _plans;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final plans = await _repo.plans();
      if (mounted) setState(() => _plans = plans);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _run(String success, Future<void> Function() action) async {
    try {
      await action();
      await _load();
      if (mounted) Toasts.success(context, success);
    } on ApiError catch (e) {
      if (mounted) Toasts.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = _plans;
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final muted = typo.body14.copyWith(color: ext.textMuted);

    return PageLayout(
      title: 'Planos',
      subtitle: 'Preços e recursos oferecidos às empresas.',
      actions: [
        FormaButton.secondary(
          label: 'Usar template',
          small: true,
          icon: const Icon(Icons.auto_awesome_outlined, size: 16),
          onPressed: () => unawaited(_fromTemplate()),
        ),
        FormaButton.primary(
          label: 'Novo plano',
          small: true,
          icon: const Icon(Icons.add, size: 18, color: Colors.white),
          onPressed: () => unawaited(_edit()),
        ),
      ],
      body: _error != null
          ? ErrorView(message: _error!, onRetry: () => unawaited(_load()))
          : FormaDataTable<Plan>(
              loading: plans == null,
              rows: plans ?? const [],
              onRowTap: (p) => unawaited(_details(p)),
              columns: [
                FormaColumn(
                  id: 'name',
                  label: 'Plano',
                  flex: 2,
                  cellBuilder: (_, p) => Text(
                    p.name,
                    style: typo.body14Medium.copyWith(color: ext.textPrimary),
                  ),
                ),
                FormaColumn(
                  id: 'price',
                  label: 'Preço',
                  width: 150,
                  cellBuilder: (_, p) => Text(
                    '${Fmt.money(p.price)}${p.cycleLabel}',
                    style: muted,
                  ),
                ),
                FormaColumn(
                  id: 'features',
                  label: 'Recursos',
                  width: 110,
                  cellBuilder: (_, p) =>
                      Text('${p.features.length}', style: muted),
                ),
                FormaColumn(
                  id: 'active',
                  label: 'Status',
                  width: 120,
                  cellBuilder: (_, p) => Align(
                    alignment: Alignment.centerLeft,
                    child: FormaBadge(
                      label: p.isActive ? 'Ativo' : 'Inativo',
                      variant: p.isActive
                          ? FormaBadgeVariant.success
                          : FormaBadgeVariant.neutral,
                    ),
                  ),
                ),
              ],
              trailingBuilder: (context, p) => FormaMenuButton(
                items: [
                  FormaMenuItem(
                    label: 'Detalhes e métricas',
                    icon: Icons.insights_outlined,
                    onTap: () => unawaited(_details(p)),
                  ),
                  FormaMenuItem(
                    label: 'Editar',
                    icon: Icons.edit_outlined,
                    onTap: () => unawaited(_edit(p)),
                  ),
                  FormaMenuItem(
                    label: p.isActive ? 'Desativar' : 'Ativar',
                    icon: p.isActive
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                    onTap: () => unawaited(
                      _run(
                        p.isActive ? 'Plano desativado' : 'Plano ativado',
                        () => _repo.setPlansActive([p.id], active: !p.isActive),
                      ),
                    ),
                  ),
                  const FormaMenuItem.divider(),
                  FormaMenuItem(
                    label: 'Excluir',
                    icon: Icons.delete_outline,
                    destructive: true,
                    onTap: () => unawaited(_delete(p)),
                  ),
                ],
              ),
              empty: const FormaEmptyState(
                icon: Icons.layers_outlined,
                title: 'Nenhum plano cadastrado',
              ),
            ),
    );
  }

  Future<void> _delete(Plan p) async {
    try {
      final (can, reason) = await _repo.canDeletePlan(p.id);
      if (!mounted) return;
      if (!can) {
        await FormaDialog.show<void>(
          context,
          title: 'Não é possível excluir',
          child: Text(
            reason ??
                'Há empresas usando este plano. Migre-as ou desative o plano.',
          ),
        );
        return;
      }
    } on ApiError catch (e) {
      if (mounted) Toasts.error(context, e);
      return;
    }
    if (!mounted ||
        !await confirmDelete(context, what: 'o plano "${p.name}"')) {
      return;
    }
    await _run('Plano excluído', () => _repo.deletePlan(p.id));
  }

  Future<void> _fromTemplate() async {
    List<PlanTemplate> templates;
    try {
      templates = await _repo.planTemplates();
    } on ApiError catch (e) {
      if (mounted) Toasts.error(context, e);
      return;
    }
    if (!mounted) return;
    final picked = await FormaDialog.show<PlanTemplate>(
      context,
      title: 'Templates de plano',
      child: templates.isEmpty
          ? const FormaEmptyState(
              compact: true,
              icon: Icons.inbox_outlined,
              title: 'Nenhum template',
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final t in templates)
                  ListTile(
                    title: Text(t.name),
                    subtitle: t.description == null
                        ? null
                        : Text(t.description!),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).pop(t),
                  ),
              ],
            ),
    );
    if (picked != null) {
      await _run('Plano criado', () => _repo.planFromTemplate(picked.id));
    }
  }

  Future<void> _edit([Plan? p]) async {
    final name = TextEditingController(text: p?.name);
    final description = TextEditingController(text: p?.description);
    num? price = p?.price;
    var cycle = p?.cycle ?? 'MONTHLY';
    final features = TextEditingController(
      text: p?.features.map((f) => f.name).join('\n'),
    );
    final saved = await showFormDialog<Plan>(
      context,
      title: p == null ? 'Novo plano' : 'Editar plano',
      fields: (setState) => [
        FormaTextField(
          label: 'Nome',
          controller: name,
          autofocus: true,
          validator: requiredValidator,
        ),
        Row(
          children: [
            Expanded(
              child: FormaNumberField(
                label: 'Preço',
                value: price,
                decimals: 2,
                min: 0,
                prefixText: r'R$',
                onChanged: (v) => price = v,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 180,
              child: FormaSelect<String>(
                label: 'Ciclo',
                value: cycle,
                options: const [
                  FormaSelectOption(value: 'MONTHLY', label: 'Mensal'),
                  FormaSelectOption(value: 'QUARTERLY', label: 'Trimestral'),
                  FormaSelectOption(value: 'YEARLY', label: 'Anual'),
                ],
                onChanged: (v) => setState(() => cycle = v ?? 'MONTHLY'),
              ),
            ),
          ],
        ),
        FormaTextField(
          label: 'Descrição',
          controller: description,
          maxLines: 2,
        ),
        FormaTextField(
          label: 'Recursos (um por linha)',
          controller: features,
          maxLines: 6,
          minLines: 4,
        ),
      ],
      onSubmit: () {
        if (price == null) throw const ValidationError('Informe o preço.');
        return _repo.savePlan(
          Plan(
            id: p?.id ?? '',
            name: name.text,
            description: description.text,
            price: price!.toDouble(),
            cycle: cycle,
            isActive: p?.isActive ?? true,
            features: [
              for (final line in features.text.split('\n'))
                if (line.trim().isNotEmpty) PlanFeature(name: line.trim()),
            ],
          ),
          create: p == null,
        );
      },
    );
    if (saved == null) return;
    await _load();
    if (mounted) {
      Toasts.success(context, p == null ? 'Plano criado' : 'Plano atualizado');
    }
  }

  Future<void> _details(Plan p) => FormaSideSheet.show<void>(
    context,
    builder: (_) => _PlanSheet(plan: p),
  );
}

class _PlanSheet extends StatefulWidget {
  const _PlanSheet({required this.plan});

  final Plan plan;

  @override
  State<_PlanSheet> createState() => _PlanSheetState();
}

class _PlanSheetState extends State<_PlanSheet> {
  PlanStats? _stats;
  List<AdminCompany> _companies = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final repo = di<AdminRepository>();
    try {
      final stats = await repo.planStats(widget.plan.id);
      List<AdminCompany> companies;
      try {
        companies = await repo.planCompanies(widget.plan.id);
      } on ApiError {
        companies = const [];
      }
      if (mounted) {
        setState(() {
          _stats = stats;
          _companies = companies;
        });
      }
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final p = widget.plan;
    return FormaSideSheetScaffold(
      title: p.name,
      subtitle: '${Fmt.money(p.price)}${p.cycleLabel}',
      body: s == null
          ? (_error != null ? ErrorView(message: _error!) : const LoadingView())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.4,
                  children: [
                    StatCard(
                      label: 'Empresas',
                      value: '${s.companies}',
                      icon: Icons.domain_outlined,
                    ),
                    StatCard(
                      label: 'Ativas',
                      value: '${s.active}',
                      icon: Icons.verified_outlined,
                      tone: ext.successColor,
                    ),
                    StatCard(
                      label: 'Receita mensal',
                      value: Fmt.money(s.monthlyRevenue),
                      icon: Icons.payments_outlined,
                    ),
                    StatCard(
                      label: 'Churn',
                      value: Fmt.percent(s.churnRate),
                      icon: Icons.trending_down_rounded,
                      tone: ext.errorColor,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Recursos',
                  style: typo.title15.copyWith(color: ext.textPrimary),
                ),
                const SizedBox(height: 6),
                for (final f in p.features)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: ext.successColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            f.name,
                            style: typo.body13.copyWith(color: ext.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                Text(
                  'Empresas no plano',
                  style: typo.title15.copyWith(color: ext.textPrimary),
                ),
                const SizedBox(height: 6),
                if (_companies.isEmpty)
                  Text(
                    'Nenhuma.',
                    style: typo.body13.copyWith(color: ext.textMuted),
                  )
                else
                  for (final c in _companies)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(c.name),
                      subtitle: c.email == null ? null : Text(c.email!),
                      trailing: SubscriptionStatusBadge(c.status),
                    ),
              ],
            ),
    );
  }
}
