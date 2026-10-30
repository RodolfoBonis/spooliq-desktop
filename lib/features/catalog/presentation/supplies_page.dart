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

/// "400 ml · R\$ 69,90" — conteúdo e preço da embalagem de um insumo.
String supplyPackageLabel(Supply s) =>
    '${Fmt.qty(s.packageSize)} ${s.unit.value} · '
    '${Fmt.cents(s.packagePriceCents)}';

/// "R\$ 0,1748/ml" — custo por unidade de um insumo.
String supplyPerUnitLabel(Supply s) =>
    '${Fmt.unitPrice(s.costPerUnit)}/${s.unit.value}';

/// Insumos não impressos (LED, hidratante, argola…) cobrados por embalagem.
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
            id: 'package',
            label: 'Embalagem',
            width: 170,
            cellBuilder: (_, s) => Text(supplyPackageLabel(s), style: muted),
          ),
          FormaColumn(
            id: 'unit_cost',
            label: 'Por unidade',
            width: 130,
            cellBuilder: (_, s) => Text(
              supplyPerUnitLabel(s),
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
/// O usuário informa o conteúdo da embalagem (na unidade escolhida) e o preço
/// pago por ela em R\$; o custo por unidade é derivado e exibido ao vivo.
/// Retorna o [Supply] salvo.
Future<Supply?> showSupplyDialog(
  BuildContext context, {
  Supply? supply,
}) {
  final name = TextEditingController(text: supply?.name);
  final description = TextEditingController(text: supply?.description);
  var unit = supply?.unit ?? SupplyUnit.un;
  num? packageSize = supply?.packageSize;
  num? packagePrice = supply == null ? null : supply.packagePriceCents / 100;
  var isActive = supply?.isActive ?? true;

  // Para avisar que recalcular orçamentos reinterpreta a quantidade por peça.
  final originalUnit = supply?.unit;
  final originalPackageSize = supply?.packageSize;

  return showFormDialog<Supply>(
    context,
    title: supply == null ? 'Novo insumo' : 'Editar insumo',
    fields: (setState) {
      final ext = Theme.of(context).extension<FormaThemeExtension>()!;
      final typo = context.formaTypography;
      final size = (packageSize ?? 0).toDouble();
      final priceCents = ((packagePrice ?? 0) * 100).round();
      final perUnit = size <= 0 ? 0.0 : priceCents / size;
      final changedUnitOrSize =
          supply != null &&
          (unit != originalUnit ||
              packageSize?.toDouble() != originalPackageSize);

      return [
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
                label: 'Conteúdo da embalagem',
                value: packageSize,
                min: 0,
                decimals: 3,
                suffixText: unit.value,
                onChanged: (v) => setState(() => packageSize = v),
              ),
            ),
          ],
        ),
        FormaNumberField(
          label: 'Preço da embalagem',
          value: packagePrice,
          min: 0,
          decimals: 2,
          prefixText: r'R$',
          onChanged: (v) => setState(() => packagePrice = v),
        ),
        if (size > 0 && priceCents > 0)
          Text(
            '= ${Fmt.unitPrice(perUnit)} por ${unit.value}',
            style: typo.body13.copyWith(color: ext.textMuted),
          ),
        if (changedUnitOrSize)
          Text(
            'Orçamentos que usam este insumo passam a interpretar a '
            'quantidade por peça na nova unidade ao recalcular.',
            style: typo.caption12.copyWith(color: ext.warningText),
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
      ];
    },
    onSubmit: () {
      // O custo por unidade divide pelo conteúdo: precisa ser maior que zero.
      final size = (packageSize ?? 0).toDouble();
      if (size <= 0) {
        throw const ValidationError(
          'Informe o conteúdo da embalagem (ex.: 400 ml ou 100 un).',
        );
      }
      return di<CatalogRepository>().saveSupply(
        id: supply?.id,
        name: name.text,
        unit: unit,
        packageSize: size,
        packagePriceCents: ((packagePrice ?? 0) * 100).round(),
        description: description.text,
        isActive: supply == null ? null : isActive,
      );
    },
  );
}
