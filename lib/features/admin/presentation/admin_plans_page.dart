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
  final Set<String> _selected = {};
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
      if (mounted) {
        setState(() {
          _plans = plans;
          _selected.retainWhere((id) => plans.any((p) => p.id == id));
        });
      }
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
        if (_selected.isNotEmpty) ...[
          Text(
            '${_selected.length} selecionado(s)',
            style: typo.caption12.copyWith(color: ext.textMuted),
          ),
          FormaButton.secondary(
            label: 'Ativar',
            small: true,
            icon: const Icon(Icons.play_circle_outline, size: 16),
            onPressed: () => unawaited(_bulk(active: true)),
          ),
          FormaButton.secondary(
            label: 'Desativar',
            small: true,
            icon: const Icon(Icons.pause_circle_outline, size: 16),
            onPressed: () => unawaited(_bulk(active: false)),
          ),
        ],
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
                  id: 'select',
                  label: '',
                  width: 44,
                  cellBuilder: (_, p) => FormaCheckbox(
                    value: _selected.contains(p.id),
                    onChanged: (v) => setState(
                      () => v ? _selected.add(p.id) : _selected.remove(p.id),
                    ),
                  ),
                ),
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
                  FormaMenuItem(
                    label: 'Migrar empresas…',
                    icon: Icons.swap_horiz_rounded,
                    onTap: () => unawaited(_migrate(p)),
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

  Future<void> _bulk({required bool active}) async {
    final ids = _selected.toList();
    await _run(
      active
          ? '${ids.length} plano(s) ativado(s)'
          : '${ids.length} plano(s) desativado(s)',
      () => _repo.setPlansActive(ids, active: active),
    );
    if (mounted) setState(_selected.clear);
  }

  /// Move todas as empresas de [from] para outro plano.
  Future<void> _migrate(Plan from) async {
    final targets = (_plans ?? const <Plan>[])
        .where((p) => p.id != from.id && p.isActive)
        .toList();
    if (targets.isEmpty) {
      Toasts.info(
        context,
        'Não há outro plano ativo para receber as empresas.',
      );
      return;
    }
    String? toId = targets.first.id;
    var notify = true;
    final reason = TextEditingController();
    final result = await showFormDialog<PlanMigration>(
      context,
      title: 'Migrar empresas',
      description: 'Todas as empresas do plano "${from.name}" serão movidas.',
      submitLabel: 'Criar migração',
      fields: (setState) => [
        FormaSelect<String>(
          label: 'Plano de destino',
          value: toId,
          options: [
            for (final p in targets)
              FormaSelectOption(
                value: p.id,
                label: p.name,
                subtitle: '${Fmt.money(p.price)}${p.cycleLabel}',
              ),
          ],
          onChanged: (v) => setState(() => toId = v),
        ),
        FormaTextField(
          label: 'Motivo',
          controller: reason,
          maxLines: 2,
          validator: requiredValidator,
        ),
        FormaCheckbox(
          value: notify,
          label: 'Avisar os usuários por e-mail',
          onChanged: (v) => setState(() => notify = v),
        ),
      ],
      onSubmit: () => _repo.createMigration(
        fromPlanId: from.id,
        toPlanId: toId!,
        reason: reason.text,
        notifyUsers: notify,
      ),
    );
    if (result == null || !mounted) return;
    final execute = await FormaConfirmDialog.show(
      context,
      title: 'Executar migração agora?',
      message:
          '${result.total} empresa(s) de "${result.fromPlan ?? from.name}" '
          'para "${result.toPlan ?? ''}". Status: ${result.statusLabel}.',
      confirmLabel: 'Executar',
      cancelLabel: 'Depois',
    );
    if (!execute || !mounted) return;
    try {
      final done = await _repo.executeMigration(result.id);
      await _load();
      if (mounted) {
        Toasts.success(
          context,
          'Migração ${done.statusLabel.toLowerCase()}',
          description: '${done.successful} ok · ${done.failed} com falha',
        );
      }
    } on ApiError catch (e) {
      if (mounted) Toasts.error(context, e);
    }
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
  ReportPeriod _period = ReportPeriod.monthly;
  PlanFinancialReport? _report;
  String? _reportError;

  Future<void> _loadReport() async {
    setState(() {
      _report = null;
      _reportError = null;
    });
    try {
      final r = await di<AdminRepository>().planFinancialReport(
        widget.plan.id,
        period: _period,
      );
      if (mounted) setState(() => _report = r);
    } on ApiError catch (e) {
      if (mounted) setState(() => _reportError = e.message);
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    unawaited(_loadReport());
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
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Financeiro',
                        style: typo.title15.copyWith(color: ext.textPrimary),
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: FormaSelect<ReportPeriod>(
                        value: _period,
                        options: [
                          for (final rp in ReportPeriod.values)
                            FormaSelectOption(value: rp, label: rp.label),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _period = v);
                          unawaited(_loadReport());
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _FinancialSection(report: _report, error: _reportError),
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

class _FinancialSection extends StatelessWidget {
  const _FinancialSection({required this.report, required this.error});

  final PlanFinancialReport? report;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    if (error != null) {
      return Text(error!, style: typo.body13.copyWith(color: ext.errorColor));
    }
    final r = report;
    if (r == null) return const FormaSkeleton.box(height: 180);

    final maxRevenue = r.trends.fold<double>(
      1,
      (m, t) => t.revenue > m ? t.revenue : m,
    );
    Widget metric(String label, String value, {Color? color}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: typo.caption12.copyWith(color: ext.textMuted)),
          const SizedBox(height: 2),
          Text(
            value,
            style: typo.title15.copyWith(color: color ?? ext.textPrimary),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            metric('Receita do período', Fmt.money(r.current)),
            metric('Período anterior', Fmt.money(r.previous)),
            metric(
              'Crescimento',
              '${r.growth >= 0 ? '+' : ''}${Fmt.percent(r.growth)}',
              color: r.growth >= 0 ? ext.successText : ext.errorText,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            metric('Por empresa', Fmt.money(r.averagePerUser)),
            metric('Total histórico', Fmt.money(r.lifetime)),
            metric('Retenção', Fmt.percent(r.retentionRate)),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            metric('Novas', '${r.newSubscriptions}'),
            metric('Canceladas', '${r.cancelled}'),
            metric('Conversão', Fmt.percent(r.conversionRate)),
          ],
        ),
        if (r.trends.isNotEmpty) ...[
          const SizedBox(height: 18),
          SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final t in r.trends)
                  Expanded(
                    child: Tooltip(
                      message:
                          '${t.period}: ${Fmt.money(t.revenue)} · '
                          '${t.subscriptions} assinaturas',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Flexible(
                              child: FractionallySizedBox(
                                heightFactor: (t.revenue / maxRevenue).clamp(
                                  0.03,
                                  1,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: ext.primaryColor.withValues(
                                      alpha: 0.8,
                                    ),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t.period,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: typo.caption12.copyWith(
                                color: ext.textHint,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ext.appBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Projeção',
                style: typo.caption12Med.copyWith(color: ext.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Próximo mês ${Fmt.money(r.nextMonth)} · '
                'trimestre ${Fmt.money(r.nextQuarter)} · '
                'ano ${Fmt.money(r.nextYear)}',
                style: typo.body13.copyWith(color: ext.textMuted),
              ),
              if (r.methodology != null) ...[
                const SizedBox(height: 4),
                Text(
                  r.methodology!,
                  style: typo.caption12.copyWith(color: ext.textHint),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
