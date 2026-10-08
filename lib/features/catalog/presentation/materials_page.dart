import 'dart:async';

import 'package:flutter/material.dart' hide Material;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/core/auth/permissions.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
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

class MaterialsPage extends StatelessWidget {
  const MaterialsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = di<CatalogRepository>();
    return BlocProvider(
      create: (_) {
        final cubit = PagedListCubit<Material>(
          (q) => repo.materials(page: q),
          idOf: (m) => m.id,
          initialQuery: const PageQuery(sortBy: 'name', sortAscending: true),
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: const _MaterialsView(),
    );
  }
}

class _MaterialsView extends StatelessWidget {
  const _MaterialsView();

  @override
  Widget build(BuildContext context) {
    final canManage = context.select<SessionCubit, bool>(
      (c) => c.state.user?.canManageCatalog ?? false,
    );
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final cubit = context.read<PagedListCubit<Material>>();
    final muted = typo.body14.copyWith(color: ext.textMuted);

    return PageLayout(
      title: 'Materiais',
      subtitle: 'Tipos de filamento e temperaturas de referência.',
      actions: [
        if (canManage)
          FormaButton.primary(
            label: 'Novo material',
            small: true,
            icon: const Icon(Icons.add, size: 18, color: Colors.white),
            onPressed: () => _edit(context),
          ),
      ],
      toolbar: SearchField(hint: 'Buscar materiais…', onChanged: cubit.search),
      body: PagedTable<Material>(
        itemLabel: 'materiais',
        onRowTap: canManage ? (m) => _edit(context, m) : null,
        columns: [
          FormaColumn(
            id: 'name',
            label: 'Nome',
            flex: 2,
            sortable: true,
            cellBuilder: (_, m) => Text(
              m.name,
              style: typo.body14Medium.copyWith(color: ext.textPrimary),
            ),
          ),
          FormaColumn(
            id: 'description',
            label: 'Descrição',
            flex: 3,
            cellBuilder: (_, m) => Text(
              m.description ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: muted,
            ),
          ),
          FormaColumn(
            id: 'temp_extruder',
            label: 'Bico',
            width: 110,
            cellBuilder: (_, m) => Text(
              m.tempExtruder == null ? '—' : '${m.tempExtruder} °C',
              style: muted,
            ),
          ),
          FormaColumn(
            id: 'temp_table',
            label: 'Mesa',
            width: 110,
            cellBuilder: (_, m) => Text(
              m.tempTable == null ? '—' : '${m.tempTable} °C',
              style: muted,
            ),
          ),
        ],
        trailingBuilder: canManage
            ? (context, m) => FormaMenuButton(
                items: [
                  FormaMenuItem(
                    label: 'Editar',
                    icon: Icons.edit_outlined,
                    onTap: () => _edit(context, m),
                  ),
                  const FormaMenuItem.divider(),
                  FormaMenuItem(
                    label: 'Excluir',
                    icon: Icons.delete_outline,
                    destructive: true,
                    onTap: () => _delete(context, m),
                  ),
                ],
              )
            : null,
        empty: FormaEmptyState(
          icon: Icons.science_outlined,
          title: 'Nenhum material cadastrado',
          message: 'PLA, PETG, ABS… cadastre os materiais que você usa.',
          action: canManage
              ? FormaButton.primary(
                  label: 'Cadastrar material',
                  small: true,
                  onPressed: () => _edit(context),
                )
              : null,
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, [Material? m]) async {
    final cubit = context.read<PagedListCubit<Material>>();
    final name = TextEditingController(text: m?.name);
    final description = TextEditingController(text: m?.description);
    num? extruder = m?.tempExtruder;
    num? table = m?.tempTable;

    final saved = await showFormDialog<Material>(
      context,
      title: m == null ? 'Novo material' : 'Editar material',
      fields: (setState) => [
        FormaTextField(
          label: 'Nome',
          controller: name,
          autofocus: true,
          validator: requiredValidator,
        ),
        FormaTextField(
          label: 'Descrição',
          controller: description,
          maxLines: 2,
        ),
        Row(
          children: [
            Expanded(
              child: FormaNumberField(
                label: 'Temperatura do bico',
                value: extruder,
                min: 0,
                max: 500,
                suffixText: '°C',
                onChanged: (v) => extruder = v,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FormaNumberField(
                label: 'Temperatura da mesa',
                value: table,
                min: 0,
                max: 300,
                suffixText: '°C',
                onChanged: (v) => table = v,
              ),
            ),
          ],
        ),
      ],
      onSubmit: () => di<CatalogRepository>().saveMaterial(
        id: m?.id,
        name: name.text,
        description: description.text,
        tempExtruder: extruder?.toInt(),
        tempTable: table?.toInt(),
      ),
    );
    if (saved == null || !context.mounted) return;
    cubit.upsert(saved);
    Toasts.success(
      context,
      m == null ? 'Material criado' : 'Material atualizado',
    );
  }

  Future<void> _delete(BuildContext context, Material m) async {
    final cubit = context.read<PagedListCubit<Material>>();
    if (!await confirmDelete(context, what: 'o material "${m.name}"')) return;
    try {
      await di<CatalogRepository>().deleteMaterial(m.id);
      cubit.remove(m.id);
      if (context.mounted) Toasts.success(context, 'Material excluído');
    } on ApiError catch (e) {
      if (context.mounted) Toasts.error(context, e);
    }
  }
}
