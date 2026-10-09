import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:spooliq_desktop/core/auth/session_user.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/format/formatters.dart';
import 'package:spooliq_desktop/core/routing/routes.dart';
import 'package:spooliq_desktop/core/ui/feedback.dart';
import 'package:spooliq_desktop/core/ui/page_layout.dart';
import 'package:spooliq_desktop/features/auth/presentation/session_cubit.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_status.dart';
import 'package:spooliq_desktop/features/budgets/presentation/budget_actions.dart';
import 'package:spooliq_desktop/features/budgets/presentation/detail/budget_detail_cubit.dart';
import 'package:spooliq_desktop/features/budgets/presentation/widgets/budget_status_badge.dart';
import 'package:spooliq_desktop/features/budgets/presentation/widgets/budget_status_style.dart';
import 'package:spooliq_desktop/features/budgets/presentation/widgets/cost_breakdown.dart';
import 'package:spooliq_desktop/features/catalog/domain/catalog.dart';
import 'package:spooliq_desktop/features/catalog/presentation/widgets/filament_swatch.dart';
import 'package:spooliq_desktop/features/models3d/domain/model3d.dart';
import 'package:spooliq_desktop/features/models3d/viewer/model_preview.dart';

class BudgetDetailPage extends StatelessWidget {
  const BudgetDetailPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      key: ValueKey(id),
      create: (_) {
        final cubit = BudgetDetailCubit(di(), id);
        unawaited(cubit.load());
        return cubit;
      },
      child: BlocConsumer<BudgetDetailCubit, BudgetDetailState>(
        listenWhen: (a, b) => !a.deleted && b.deleted,
        listener: (context, _) => context.go(Routes.budgets),
        builder: (context, state) {
          final budget = state.budget;
          if (budget == null) {
            return state.error != null
                ? ErrorView(
                    message: state.error!,
                    onRetry: () => unawaited(
                      context.read<BudgetDetailCubit>().load(),
                    ),
                  )
                : const LoadingView();
          }
          return _DetailView(budget: budget, history: state.history);
        },
      ),
    );
  }
}

class _DetailView extends StatelessWidget {
  const _DetailView({required this.budget, required this.history});

  final Budget budget;
  final List<StatusChange> history;

  @override
  Widget build(BuildContext context) {
    final user = context.select<SessionCubit, SessionUser?>(
      (c) => c.state.user,
    )!;
    final cubit = context.read<BudgetDetailCubit>();
    final actions = BudgetActions(
      context: context,
      user: user,
      onChanged: (b) {
        if (b.id == budget.id) {
          cubit.replace(b);
        }
      },
      onDeleted: (_) => cubit.markDeleted(),
    );
    final next = _primaryTransition(budget.status);
    final quote = Fmt.quote(budget.quoteNumber);

    return PageLayout(
      leading: Tooltip(
        message: 'Voltar para orçamentos',
        child: FormaIconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          onPressed: () => context.go(Routes.budgets),
        ),
      ),
      title: quote.isEmpty ? budget.name : '$quote  ${budget.name}',
      subtitle: [
        if (budget.customerName.isNotEmpty) budget.customerName,
        'criado ${Fmt.relative(budget.createdAt)}',
        if (budget.totalPrintTimeDisplay.isNotEmpty)
          '${budget.totalPrintTimeDisplay} de impressão',
      ].join(' · '),
      actions: [
        BudgetStatusBadge(budget.status),
        const SizedBox(width: 4),
        if (budget.status.isEditable)
          FormaButton.secondary(
            label: 'Editar',
            small: true,
            icon: const Icon(Icons.edit_outlined, size: 16),
            onPressed: () => context.go(Routes.budgetEdit(budget.id)),
          ),
        FormaButton.secondary(
          label: 'PDF',
          small: true,
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
          onPressed: () => unawaited(actions.openPdf(budget)),
        ),
        if (budget.status.isShareable)
          FormaButton.secondary(
            label: 'Compartilhar',
            small: true,
            icon: const Icon(Icons.ios_share_rounded, size: 16),
            onPressed: () => unawaited(actions.share(budget)),
          ),
        if (next != null)
          FormaButton.primary(
            label: next.actionLabel,
            small: true,
            icon: Icon(
              BudgetStatusStyle.of(next, Theme.of(context).brightness).icon,
              size: 16,
              color: Colors.white,
            ),
            onPressed: () => unawaited(actions.move(budget, next)),
          ),
        FormaMenuButton(
          tooltip: 'Mais ações',
          items: actions.menuFor(budget, includeOpen: false),
        ),
      ],
      scrollable: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1100;
          final main = _MainColumn(budget: budget, actions: actions);
          final side = _SideColumn(budget: budget, history: history);
          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [main, const SizedBox(height: 20), side],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: main),
              const SizedBox(width: 20),
              SizedBox(width: 380, child: side),
            ],
          );
        },
      ),
    );
  }

  /// "Próximo passo" natural do fluxo.
  static BudgetStatus? _primaryTransition(BudgetStatus s) => switch (s) {
    BudgetStatus.draft => BudgetStatus.sent,
    BudgetStatus.sent => BudgetStatus.approved,
    BudgetStatus.approved => BudgetStatus.printing,
    BudgetStatus.printing => BudgetStatus.completed,
    BudgetStatus.rejected ||
    BudgetStatus.expired ||
    BudgetStatus.cancelled => BudgetStatus.draft,
    BudgetStatus.completed => null,
  };
}

class _MainColumn extends StatelessWidget {
  const _MainColumn({required this.budget, required this.actions});

  final Budget budget;
  final BudgetActions actions;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final b = budget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (b.usesLegacyCalculation) ...[
          _LegacyCalculation(budget: b, actions: actions),
          const SizedBox(height: 16),
        ],
        if (b.stockWarnings.isNotEmpty) ...[
          _StockWarnings(warnings: b.stockWarnings),
          const SizedBox(height: 16),
        ],
        if (b.customerResponseAt != null) ...[
          _CustomerResponse(budget: b),
          const SizedBox(height: 16),
        ],
        if (b.description != null) ...[
          Text(
            b.description!,
            style: typo.body14.copyWith(color: ext.textMuted, height: 1.5),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          'Itens (${b.items.length})',
          style: typo.title15.copyWith(color: ext.textPrimary),
        ),
        const SizedBox(height: 10),
        for (final item in b.items) ...[
          _ItemCard(item: item),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        SectionCard(
          title: 'Informações comerciais',
          child: Wrap(
            spacing: 32,
            runSpacing: 16,
            children: [
              _Info(
                'Prazo de entrega',
                b.deliveryDays == null ? '—' : '${b.deliveryDays} dias',
              ),
              _Info('Validade', Fmt.date(b.validUntil)),
              _Info('Perfil', b.profile?.name ?? 'Padrão da empresa'),
              _Info('Máquina', b.machinePreset?.name ?? '—'),
              _Info('Energia', b.energyPreset?.name ?? '—'),
              _Info('Custos', b.costPreset?.name ?? '—'),
              if (b.paymentTerms != null)
                _Info('Pagamento', b.paymentTerms!, wide: true),
              if (b.notes != null) _Info('Observações', b.notes!, wide: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value, {this.wide = false});

  final String label;
  final String value;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    return SizedBox(
      width: wide ? double.infinity : 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: typo.caption12.copyWith(color: ext.textHint)),
          const SizedBox(height: 4),
          Text(
            value,
            style: typo.body14.copyWith(color: ext.textPrimary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item});

  final BudgetItem item;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final muted = typo.caption12.copyWith(color: ext.textMuted);
    final meta = [
      '${item.quantity} ${item.quantity == 1 ? 'unidade' : 'unidades'}',
      if (item.printTimeDisplay.isNotEmpty) item.printTimeDisplay,
      Fmt.grams(item.totalGrams),
      if (item.dimensions != null) item.dimensions!,
    ].join(' · ');

    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: typo.title15.copyWith(color: ext.textPrimary),
                    ),
                    const SizedBox(height: 3),
                    Text(meta, style: muted),
                    if (item.description != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.description!,
                        style: typo.body13.copyWith(color: ext.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Fmt.cents(item.saleTotalCents),
                    style: typo.title16.copyWith(
                      color: ext.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    '${Fmt.cents(item.saleUnitPriceCents)} / un.',
                    style: muted,
                  ),
                  if (item.model3dId != null) ...[
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: () => unawaited(
                        showModelViewerDialog(
                          context,
                          Model3D.ref(item.model3dId!, item.productName),
                        ),
                      ),
                      icon: const Icon(Icons.threed_rotation_rounded, size: 16),
                      label: const Text('Ver modelo 3D'),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in item.filaments)
                Container(
                  padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
                  decoration: BoxDecoration(
                    color: ext.appBackground,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: ext.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilamentSwatch(
                        colorHex: f.colorHex,
                        colorType: ColorType.fromValue(f.colorType),
                        colorData: f.colorData,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${f.name}${f.color.isEmpty ? '' : ' · ${f.color}'}',
                        style: typo.caption12Med.copyWith(
                          color: ext.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(Fmt.grams(f.grams), style: muted),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: ext.border, height: 1),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              for (final (label, cents) in [
                ('Filamento', item.costs.filament),
                ('Desperdício', item.costs.waste),
                ('Energia', item.costs.energy),
                ('Máquina', item.costs.machine),
                ('Setup', item.costs.setup),
                ('Mão de obra', item.costs.labor),
                (
                  'Pós-proc.',
                  item.costs.postProcessing + item.costs.supportRemoval,
                ),
              ])
                if (cents > 0)
                  Text.rich(
                    TextSpan(
                      text: '$label ',
                      style: muted,
                      children: [
                        TextSpan(
                          text: Fmt.cents(cents),
                          style: typo.caption12Med.copyWith(
                            color: ext.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
              Text.rich(
                TextSpan(
                  text: 'Custo do item ',
                  style: muted,
                  children: [
                    TextSpan(
                      text: Fmt.cents(item.totalCostCents),
                      style: typo.caption12Med.copyWith(color: ext.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SideColumn extends StatelessWidget {
  const _SideColumn({required this.budget, required this.history});

  final Budget budget;
  final List<StatusChange> history;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final customer = budget.customer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: 'Resumo',
          child: PriceSummary(budget: budget),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Composição do preço',
          child: CostBreakdown(budget: budget),
        ),
        if (customer != null) ...[
          const SizedBox(height: 16),
          SectionCard(
            title: 'Cliente',
            trailing: TextButton(
              onPressed: () => context.go(Routes.customer(customer.id)),
              child: const Text('Ver ficha'),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: typo.body14Medium.copyWith(color: ext.textPrimary),
                ),
                for (final (icon, value) in [
                  (Icons.mail_outline, customer.email),
                  (Icons.phone_outlined, customer.phone),
                  (Icons.badge_outlined, customer.document),
                ])
                  if (value != null && value.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(icon, size: 15, color: ext.textHint),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SelectableText(
                              value,
                              style: typo.body13.copyWith(color: ext.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        SectionCard(
          title: 'Histórico',
          child: history.isEmpty
              ? Text(
                  'Sem mudanças de status.',
                  style: typo.body13.copyWith(color: ext.textMuted),
                )
              : _Timeline(history: history),
        ),
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.history});

  final List<StatusChange> history;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final brightness = Theme.of(context).brightness;
    final entries = [...history]
      ..sort((a, b) => (b.at ?? DateTime(0)).compareTo(a.at ?? DateTime(0)));

    return Column(
      children: [
        for (final (i, e) in entries.indexed)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 20,
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: BudgetStatusStyle.of(e.to, brightness).color,
                          border: Border.all(
                            color: ext.cardBackground,
                            width: 2,
                          ),
                        ),
                      ),
                      if (i < entries.length - 1)
                        Expanded(
                          child: Container(width: 1.5, color: ext.border),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              if (e.from != null) ...[
                                TextSpan(text: e.from!.label),
                                TextSpan(
                                  text: '  →  ',
                                  style: TextStyle(color: ext.textHint),
                                ),
                              ],
                              TextSpan(
                                text: e.to.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          style: typo.body13.copyWith(color: ext.textPrimary),
                        ),
                        Text(
                          Fmt.dateTime(e.at),
                          style: typo.caption12.copyWith(color: ext.textHint),
                        ),
                        if (e.notes != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            e.notes!,
                            style: typo.caption12.copyWith(
                              color: ext.textMuted,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StockWarnings extends StatelessWidget {
  const _StockWarnings({required this.warnings});

  final List<StockWarning> warnings;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ext.warningSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.inventory_2_outlined, size: 18, color: ext.warningText),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estoque insuficiente para este orçamento',
                  style: typo.body14Medium.copyWith(color: ext.warningText),
                ),
                const SizedBox(height: 4),
                for (final w in warnings)
                  Text(
                    '${_filamentLabel(w)}: '
                    'precisa de ${Fmt.grams(w.requiredGrams)}, '
                    'disponível ${Fmt.grams(w.availableGrams)}',
                    style: typo.body13.copyWith(color: ext.warningText),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Orçamento criado antes do breakdown de mão de obra: os custos podem não
/// refletir o modelo atual.
class _LegacyCalculation extends StatelessWidget {
  const _LegacyCalculation({required this.budget, required this.actions});

  final Budget budget;
  final BudgetActions actions;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final draft = budget.status.isEditable;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ext.infoSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.history_toggle_off_rounded, size: 18, color: ext.infoText),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Este orçamento usa o cálculo antigo',
                  style: typo.body14Medium.copyWith(color: ext.infoText),
                ),
                const SizedBox(height: 2),
                Text(
                  draft
                      ? 'Recalcule para usar o modelo de custos atual, com '
                            'mão de obra detalhada.'
                      : 'Crie uma cópia recalculada para usar o modelo de '
                            'custos atual, com mão de obra detalhada.',
                  style: typo.body13.copyWith(color: ext.infoText),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FormaButton.secondary(
            label: draft ? 'Recalcular' : 'Duplicar e recalcular',
            small: true,
            icon: const Icon(Icons.calculate_outlined, size: 16),
            onPressed: () => unawaited(
              draft
                  ? actions.recalculate(budget)
                  : actions.duplicateAndRecalculate(budget),
            ),
          ),
        ],
      ),
    );
  }
}

String _filamentLabel(StockWarning w) =>
    w.color.isEmpty ? w.filamentName : '${w.filamentName} (${w.color})';

class _CustomerResponse extends StatelessWidget {
  const _CustomerResponse({required this.budget});

  final Budget budget;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final approved = budget.status != BudgetStatus.rejected;
    final (bg, fg) = approved
        ? (ext.successSurface, ext.successText)
        : (ext.errorSurface, ext.errorText);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            approved ? Icons.verified_rounded : Icons.thumb_down_alt_outlined,
            size: 18,
            color: fg,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    '${approved ? 'Aprovado' : 'Recusado'} pelo cliente',
                    ?budget.customerResponseName,
                  ].join(' — '),
                  style: typo.body14Medium.copyWith(color: fg),
                ),
                Text(
                  Fmt.dateTime(budget.customerResponseAt),
                  style: typo.caption12.copyWith(color: fg),
                ),
                if (budget.rejectionReason != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '“${budget.rejectionReason}”',
                    style: typo.body13.copyWith(color: fg),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
