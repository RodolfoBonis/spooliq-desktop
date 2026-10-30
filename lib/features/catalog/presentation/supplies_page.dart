import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/core/auth/permissions.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/format/formatters.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/core/state/paged_list_cubit.dart';
import 'package:spooliq_desktop/core/ui/feedback.dart';
import 'package:spooliq_desktop/core/ui/form_dialog.dart';
import 'package:spooliq_desktop/core/ui/page_layout.dart';
import 'package:spooliq_desktop/core/ui/paged_table.dart';
import 'package:spooliq_desktop/core/ui/search_field.dart';
import 'package:spooliq_desktop/features/auth/presentation/session_cubit.dart';
import 'package:spooliq_desktop/features/catalog/domain/catalog.dart';
import 'package:spooliq_desktop/features/catalog/domain/catalog_repository.dart';

/// Insumos não impressos (LED, hidratante, argola…) cobrados por unidade.
class SuppliesPage extends StatelessWidget {
  const SuppliesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = di<CatalogRepository>();
    return BlocProvider(
      create: (_) {
        final cubit = PagedListCubit<Supply>(
          (q) => repo.supplies(page: q),
          idOf: (s) => s.id,
          initialQuery: const PageQuery(sortBy: 'name', sortAscending: true),
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: const _SuppliesView(),
    );
  }
}

class _SuppliesView extends StatelessWidget {
  const _SuppliesView();

  @override
  Widget build(BuildContext context) {
    final canManage = context.select<SessionCubit, bool>(
      (c) => c.state.user?.canManageCatalog ?? false,
    );
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final cubit = context.read<PagedListCubit<Supply>>();
    final muted = typo.body14.copyWith(color: ext.textMuted);

    return PageLayout(
      title: 'Insumos',
      subtitle: 'Itens não impressos cobrados por unidade (LED, argola…).',
      actions: [
        if (canManage)
          FormaButton.primary(
            label: 'Novo insumo',
            small: true,
            icon: const Icon(Icons.add, size: 18, color: Colors.white),
            onPressed: () => _edit(context),
          ),
      ],
      toolbar: SearchField(hint: 'Buscar insumos…', onChanged: cubit.search),
      body: PagedTable<Supply>(
        itemLabel: 'insumos',
        onRowTap: canManage ? (s) => _edit(context, s) : null,
        columns: [
          FormaColumn(
            id: 'name',
            label: 'Nome',
            flex: 2,
            sortable: true,
            cellBuilder: (_, s) => Text(
              s.name,
              style: typo.body14Medium.copyWith(
                color: s.isActive ? ext.textPrimary : ext.textHint,
              ),
            ),
          ),
          FormaColumn(
            id: 'description',
            label: 'Descrição',
            flex: 3,
            cellBuilder: (_, s) => Text(
              s.description ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: muted,
            ),
          ),
          FormaColumn(
            id: 'unit',
            label: 'Unidade',
            width: 110,
            cellBuilder: (_, s) => Text(s.unit.label, style: muted),
          ),
          FormaColumn(
            id: 'unit_cost',
            label: 'Custo unit.',
            width: 120,
            cellBuilder: (_, s) => Text(
              Fmt.cents(s.unitCostCents),
              style: typo.body14.copyWith(
                color: ext.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
        trailingBuilder: canManage
            ? (context, s) => FormaMenuButton(
                items: [
                  FormaMenuItem(
                    label: 'Editar',
                    icon: Icons.edit_outlined,
                    onTap: () => _edit(context, s),
                  ),
                  const FormaMenuItem.divider(),
                  FormaMenuItem(
                    label: 'Excluir',
                    icon: Icons.delete_outline,
                    destructive: true,
                    onTap: () => _delete(context, s),
                  ),
                ],
              )
            : null,
        empty: FormaEmptyState(
          icon: Icons.category_outlined,
          title: 'Nenhum insumo cadastrado',
          message: 'LED, hidratante, argola… cadastre o que acompanha a peça.',
          action: canManage
              ? FormaButton.primary(
                  label: 'Cadastrar insumo',
                  small: true,
                  onPressed: () => _edit(context),
                )
              : null,
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, [Supply? supply]) async {
    final cubit = context.read<PagedListCubit<Supply>>();
    final saved = await showSupplyDialog(context, supply: supply);
    if (saved == null || !context.mounted) return;
    cubit.upsert(saved);
    Toasts.success(
      context,
      supply == null ? 'Insumo criado' : 'Insumo atualizado',
    );
  }

  Future<void> _delete(BuildContext context, Supply supply) async {
    final cubit = context.read<PagedListCubit<Supply>>();
    if (!await confirmDelete(context, what: 'o insumo "${supply.name}"')) {
      return;
    }
    try {
      await di<CatalogRepository>().deleteSupply(supply.id);
      cubit.remove(supply.id);
      if (context.mounted) Toasts.success(context, 'Insumo excluído');
    } on ApiError catch (e) {
      if (context.mounted) Toasts.error(context, e);
    }
  }
}

/// Diálogo de criação/edição de insumo, reutilizado pelo editor de orçamento.
/// Converte o custo unitário de R\$ para centavos. Retorna o [Supply] salvo.
Future<Supply?> showSupplyDialog(
  BuildContext context, {
  Supply? supply,
}) {
  final name = TextEditingController(text: supply?.name);
  final description = TextEditingController(text: supply?.description);
  var unit = supply?.unit ?? SupplyUnit.un;
  num? unitCost = supply == null ? null : supply.unitCostCents / 100;
  var isActive = supply?.isActive ?? true;

  return showFormDialog<Supply>(
    context,
    title: supply == null ? 'Novo insumo' : 'Editar insumo',
    fields: (setState) => [
      FormaTextField(
        label: 'Nome',
        controller: name,
        autofocus: true,
        validator: requiredValidator,
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: FormaSelect<SupplyUnit>(
              label: 'Unidade',
              value: unit,
              options: [
                for (final u in SupplyUnit.values)
                  FormaSelectOption(value: u, label: u.label),
              ],
              onChanged: (v) => setState(() => unit = v ?? unit),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FormaNumberField(
              label: 'Custo unitário',
              value: unitCost,
              min: 0,
              decimals: 2,
              prefixText: r'R$',
              onChanged: (v) => unitCost = v,
            ),
          ),
        ],
      ),
      FormaTextField(
        label: 'Descrição',
        controller: description,
        maxLines: 2,
      ),
      if (supply != null)
        FormaCheckbox(
          value: isActive,
          label: 'Ativo',
          description: 'Inativos não aparecem no editor de orçamentos',
          onChanged: (v) => setState(() => isActive = v),
        ),
    ],
    onSubmit: () => di<CatalogRepository>().saveSupply(
      id: supply?.id,
      name: name.text,
      unit: unit,
      unitCostCents: ((unitCost ?? 0) * 100).round(),
      description: description.text,
      isActive: supply == null ? null : isActive,
    ),
  );
}
