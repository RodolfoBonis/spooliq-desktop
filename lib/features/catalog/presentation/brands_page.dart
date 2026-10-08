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
import 'package:spooliq_desktop/core/ui/page_layout.dart';
import 'package:spooliq_desktop/core/ui/paged_table.dart';
import 'package:spooliq_desktop/core/ui/search_field.dart';
import 'package:spooliq_desktop/features/auth/presentation/session_cubit.dart';
import 'package:spooliq_desktop/features/catalog/domain/catalog.dart';
import 'package:spooliq_desktop/features/catalog/domain/catalog_repository.dart';

/// Marcas de filamento — tela de referência do padrão de CRUD:
/// `PagedListCubit` + `PagedTable` + diálogo de formulário + menu de ações.
class BrandsPage extends StatelessWidget {
  const BrandsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = di<CatalogRepository>();
    return BlocProvider(
      create: (_) {
        final cubit = PagedListCubit<Brand>(
          (q) => repo.brands(page: q),
          idOf: (b) => b.id,
          initialQuery: const PageQuery(sortBy: 'name', sortAscending: true),
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: const _BrandsView(),
    );
  }
}

class _BrandsView extends StatelessWidget {
  const _BrandsView();

  @override
  Widget build(BuildContext context) {
    final canManage = context.select<SessionCubit, bool>(
      (c) => c.state.user?.canManageCatalog ?? false,
    );
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final cubit = context.read<PagedListCubit<Brand>>();

    return PageLayout(
      title: 'Marcas',
      subtitle: 'Fabricantes dos seus filamentos.',
      actions: [
        if (canManage)
          FormaButton.primary(
            label: 'Nova marca',
            small: true,
            icon: const Icon(Icons.add, size: 18, color: Colors.white),
            onPressed: () => _edit(context),
          ),
      ],
      toolbar: SearchField(hint: 'Buscar marcas…', onChanged: cubit.search),
      body: PagedTable<Brand>(
        itemLabel: 'marcas',
        onRowTap: canManage ? (b) => _edit(context, b) : null,
        columns: [
          FormaColumn(
            id: 'name',
            label: 'Nome',
            flex: 2,
            sortable: true,
            cellBuilder: (_, b) => Text(
              b.name,
              style: typo.body14Medium.copyWith(color: ext.textPrimary),
            ),
          ),
          FormaColumn(
            id: 'description',
            label: 'Descrição',
            flex: 3,
            cellBuilder: (_, b) => Text(
              b.description ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typo.body14.copyWith(color: ext.textMuted),
            ),
          ),
          FormaColumn(
            id: 'created_at',
            label: 'Criada em',
            width: 140,
            sortable: true,
            cellBuilder: (_, b) => Text(
              Fmt.date(b.createdAt),
              style: typo.body14.copyWith(color: ext.textMuted),
            ),
          ),
        ],
        trailingBuilder: canManage
            ? (context, b) => FormaMenuButton(
                items: [
                  FormaMenuItem(
                    label: 'Editar',
                    icon: Icons.edit_outlined,
                    onTap: () => _edit(context, b),
                  ),
                  const FormaMenuItem.divider(),
                  FormaMenuItem(
                    label: 'Excluir',
                    icon: Icons.delete_outline,
                    destructive: true,
                    onTap: () => _delete(context, b),
                  ),
                ],
              )
            : null,
        empty: FormaEmptyState(
          icon: Icons.sell_outlined,
          title: 'Nenhuma marca cadastrada',
          message: 'Cadastre as marcas para organizar seus filamentos.',
          action: canManage
              ? FormaButton.primary(
                  label: 'Cadastrar marca',
                  small: true,
                  onPressed: () => _edit(context),
                )
              : null,
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, [Brand? brand]) async {
    final cubit = context.read<PagedListCubit<Brand>>();
    final saved = await FormaDialog.show<Brand>(
      context,
      title: brand == null ? 'Nova marca' : 'Editar marca',
      child: _BrandForm(brand: brand),
    );
    if (saved == null || !context.mounted) return;
    cubit.upsert(saved);
    Toasts.success(
      context,
      brand == null ? 'Marca criada' : 'Marca atualizada',
    );
  }

  Future<void> _delete(BuildContext context, Brand brand) async {
    final cubit = context.read<PagedListCubit<Brand>>();
    final ok = await confirmDelete(
      context,
      what: 'a marca "${brand.name}"',
      detail: 'Filamentos dessa marca podem impedir a exclusão.',
    );
    if (!ok || !context.mounted) return;
    try {
      await di<CatalogRepository>().deleteBrand(brand.id);
      cubit.remove(brand.id);
      if (context.mounted) Toasts.success(context, 'Marca excluída');
    } on ApiError catch (e) {
      if (context.mounted) Toasts.error(context, e);
    }
  }
}

/// Formulário dentro do [FormaDialog]; fecha com o registro salvo.
class _BrandForm extends StatefulWidget {
  const _BrandForm({this.brand});

  final Brand? brand;

  @override
  State<_BrandForm> createState() => _BrandFormState();
}

class _BrandFormState extends State<_BrandForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.brand?.name);
  late final _description = TextEditingController(
    text: widget.brand?.description,
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await di<CatalogRepository>().saveBrand(
        id: widget.brand?.id,
        name: _name.text,
        description: _description.text,
      );
      if (mounted) Navigator.of(context).pop(saved);
    } on ApiError catch (e) {
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    return Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormaTextField(
            label: 'Nome',
            controller: _name,
            autofocus: true,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Informe o nome.' : null,
          ),
          const SizedBox(height: 16),
          FormaTextField(
            label: 'Descrição',
            controller: _description,
            maxLines: 3,
            minLines: 2,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: typo.caption12.copyWith(color: ext.errorColor),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FormaButton.secondary(
                label: 'Cancelar',
                small: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),
              FormaButton.primary(
                label: 'Salvar',
                small: true,
                isLoading: _saving,
                onPressed: () => unawaited(_submit()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
