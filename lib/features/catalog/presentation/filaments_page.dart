import 'dart:async';

import 'package:flutter/material.dart' hide Material;
import 'package:flutter/services.dart';
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
import 'package:spooliq_desktop/features/catalog/presentation/filament_stock_sheet.dart';
import 'package:spooliq_desktop/features/catalog/presentation/widgets/filament_swatch.dart';

class FilamentsPage extends StatefulWidget {
  const FilamentsPage({this.lowStockOnly = false, super.key});

  final bool lowStockOnly;

  @override
  State<FilamentsPage> createState() => _FilamentsPageState();
}

class _FilamentsPageState extends State<FilamentsPage> {
  final CatalogRepository _repo = di<CatalogRepository>();
  late FilamentFilter _filter = FilamentFilter(lowStock: widget.lowStockOnly);
  late final PagedListCubit<Filament> _cubit = PagedListCubit<Filament>(
    (q) => _repo.filaments(page: q, filter: _filter),
    idOf: (f) => f.id,
    initialQuery: const PageQuery(sortBy: 'name', sortAscending: true),
  );
  List<Brand> _brands = const [];
  List<Material> _materials = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_cubit.load());
    unawaited(_loadLookups());
  }

  Future<void> _loadLookups() async {
    try {
      final brands = await _repo.brands();
      final materials = await _repo.materials();
      if (mounted) {
        setState(() {
          _brands = brands.items;
          _materials = materials.items;
        });
      }
    } on ApiError {
      // Filtros ficam vazios; a listagem continua funcionando.
    }
  }

  @override
  void dispose() {
    unawaited(_cubit.close());
    super.dispose();
  }

  void _setFilter(FilamentFilter f) {
    setState(() => _filter = f);
    unawaited(_cubit.load(_cubit.state.query.copyWith(page: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final canManage = context.select<SessionCubit, bool>(
      (c) => c.state.user?.canManageCatalog ?? false,
    );
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final muted = typo.body14.copyWith(color: ext.textMuted);

    return BlocProvider.value(
      value: _cubit,
      child: PageLayout(
        title: 'Filamentos',
        subtitle: 'Seu catálogo de carretéis, preços e estoque.',
        actions: [
          if (canManage)
            FormaButton.primary(
              label: 'Novo filamento',
              small: true,
              icon: const Icon(Icons.add, size: 18, color: Colors.white),
              onPressed: () => _edit(context),
            ),
        ],
        toolbar: Row(
          children: [
            SearchField(hint: 'Buscar filamentos…', onChanged: _cubit.search),
            const SizedBox(width: 10),
            SizedBox(
              width: 190,
              child: FormaSelect<String>(
                hint: 'Todas as marcas',
                clearable: true,
                value: _filter.brandId,
                options: [
                  for (final b in _brands)
                    FormaSelectOption(value: b.id, label: b.name),
                ],
                onChanged: (v) =>
                    _setFilter(_filter.copyWith(brandId: () => v)),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 190,
              child: FormaSelect<String>(
                hint: 'Todos os materiais',
                clearable: true,
                value: _filter.materialId,
                options: [
                  for (final m in _materials)
                    FormaSelectOption(value: m.id, label: m.name),
                ],
                onChanged: (v) =>
                    _setFilter(_filter.copyWith(materialId: () => v)),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 150,
              child: FormaSelect<double>(
                hint: 'Todos os diâmetros',
                clearable: true,
                value: _filter.diameter,
                options: const [
                  FormaSelectOption(value: 1.75, label: '1,75 mm'),
                  FormaSelectOption(value: 2.85, label: '2,85 mm'),
                ],
                onChanged: (v) =>
                    _setFilter(_filter.copyWith(diameter: () => v)),
              ),
            ),
            const Spacer(),
            FormaCheckbox(
              value: _filter.lowStock,
              label: 'Só estoque baixo',
              onChanged: (v) => _setFilter(_filter.copyWith(lowStock: v)),
            ),
          ],
        ),
        body: PagedTable<Filament>(
          itemLabel: 'filamentos',
          onRowTap: (f) => _stock(context, f),
          columns: [
            FormaColumn(
              id: 'name',
              label: 'Filamento',
              flex: 3,
              sortable: true,
              cellBuilder: (_, f) => Row(
                children: [
                  FilamentSwatch.of(f, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typo.body14Medium.copyWith(
                            color: f.isActive ? ext.textPrimary : ext.textHint,
                          ),
                        ),
                        Text(
                          [f.color, f.colorType.label].join(' · '),
                          style: typo.caption12.copyWith(color: ext.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            FormaColumn(
              id: 'brand',
              label: 'Marca',
              flex: 2,
              cellBuilder: (_, f) => Text(f.brandName, style: muted),
            ),
            FormaColumn(
              id: 'material',
              label: 'Material',
              width: 110,
              cellBuilder: (_, f) => Text(f.materialName, style: muted),
            ),
            FormaColumn(
              id: 'diameter',
              label: 'Ø',
              width: 80,
              cellBuilder: (_, f) => Text('${f.diameter} mm', style: muted),
            ),
            FormaColumn(
              id: 'price_per_kg',
              label: 'Preço/kg',
              width: 120,
              sortable: true,
              alignment: Alignment.centerRight,
              cellBuilder: (_, f) => Text(
                Fmt.cents(f.pricePerKgCents),
                style: typo.body14.copyWith(color: ext.textPrimary),
              ),
            ),
            FormaColumn(
              id: 'stock',
              label: 'Estoque',
              width: 150,
              alignment: Alignment.centerRight,
              cellBuilder: (_, f) => !f.trackStock
                  ? Text('—', style: muted)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (f.isLowStock) ...[
                          Tooltip(
                            message: 'Estoque baixo',
                            child: Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: ext.warningColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          Fmt.grams(f.stockGrams),
                          style: typo.body14Medium.copyWith(
                            color: f.isLowStock
                                ? ext.warningText
                                : ext.textPrimary,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
          trailingBuilder: (context, f) => FormaMenuButton(
            items: [
              FormaMenuItem(
                label: 'Estoque',
                icon: Icons.inventory_2_outlined,
                onTap: () => _stock(context, f),
              ),
              if (canManage) ...[
                FormaMenuItem(
                  label: 'Editar',
                  icon: Icons.edit_outlined,
                  onTap: () => _edit(context, f),
                ),
                const FormaMenuItem.divider(),
                FormaMenuItem(
                  label: 'Excluir',
                  icon: Icons.delete_outline,
                  destructive: true,
                  onTap: () => _delete(context, f),
                ),
              ],
            ],
          ),
          empty: FormaEmptyState(
            icon: Icons.blur_circular_outlined,
            title: 'Nenhum filamento',
            message: _filter.lowStock
                ? 'Nenhum filamento com estoque baixo. 🎉'
                : 'Cadastre seus filamentos para montar orçamentos.',
            action: canManage && !_filter.lowStock
                ? FormaButton.primary(
                    label: 'Cadastrar filamento',
                    small: true,
                    onPressed: () => _edit(context),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, [Filament? f]) async {
    if (_brands.isEmpty || _materials.isEmpty) {
      Toasts.info(
        context,
        'Cadastre ao menos uma marca e um material antes.',
      );
      return;
    }
    final name = TextEditingController(text: f?.name);
    final color = TextEditingController(text: f?.color);
    final hex = TextEditingController(text: f?.colorHex ?? '#FF6B6B');
    final hex2 = TextEditingController(
      text: f?.colorData?['secondary']?.toString() ?? '#FFFFFF',
    );
    final description = TextEditingController(text: f?.description);
    var brandId = f?.brandId;
    var materialId = f?.materialId;
    var type = f?.colorType ?? ColorType.solid;
    num diameter = f?.diameter ?? 1.75;
    num? price = f == null ? null : f.pricePerKgCents / 100;
    num? weight = f?.weight;
    num? printTemp = f?.printTemperature;
    num? bedTemp = f?.bedTemperature;
    var active = f?.isActive ?? true;
    var track = f?.trackStock ?? false;
    num? threshold = f?.lowStockThresholdGrams;
    String? selectError;

    final saved = await showFormDialog<Filament>(
      context,
      title: f == null ? 'Novo filamento' : 'Editar filamento',
      width: 620,
      fields: (setState) => [
        FormaTextField(
          label: 'Nome',
          hint: 'Ex.: PLA Basic',
          controller: name,
          autofocus: true,
          validator: requiredValidator,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormaSelect<String>(
                label: 'Marca',
                value: brandId,
                searchable: true,
                errorText: selectError != null && brandId == null
                    ? 'Obrigatório'
                    : null,
                options: [
                  for (final b in _brands)
                    FormaSelectOption(value: b.id, label: b.name),
                ],
                onChanged: (v) => setState(() => brandId = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FormaSelect<String>(
                label: 'Material',
                value: materialId,
                errorText: selectError != null && materialId == null
                    ? 'Obrigatório'
                    : null,
                options: [
                  for (final m in _materials)
                    FormaSelectOption(value: m.id, label: m.name),
                ],
                onChanged: (v) => setState(() => materialId = v),
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormaTextField(
                label: 'Nome da cor',
                hint: 'Ex.: Vermelho',
                controller: color,
                validator: requiredValidator,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 180,
              child: FormaSelect<ColorType>(
                label: 'Tipo de cor',
                value: type,
                options: [
                  for (final t in ColorType.values)
                    FormaSelectOption(value: t, label: t.label),
                ],
                onChanged: (v) => setState(() => type = v ?? ColorType.solid),
              ),
            ),
          ],
        ),
        _ColorRow(
          label: type == ColorType.duo || type == ColorType.gradient
              ? 'Cor principal'
              : 'Cor',
          controller: hex,
          onChanged: () => setState(() {}),
        ),
        if (type == ColorType.duo || type == ColorType.gradient)
          _ColorRow(
            label: 'Cor secundária',
            controller: hex2,
            onChanged: () => setState(() {}),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormaNumberField(
                label: 'Preço por kg',
                value: price,
                decimals: 2,
                min: 0,
                prefixText: r'R$',
                onChanged: (v) => price = v,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 140,
              child: FormaSelect<num>(
                label: 'Diâmetro',
                value: diameter,
                options: const [
                  FormaSelectOption(value: 1.75, label: '1,75 mm'),
                  FormaSelectOption(value: 2.85, label: '2,85 mm'),
                ],
                onChanged: (v) => diameter = v ?? 1.75,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FormaNumberField(
                label: 'Peso do carretel',
                value: weight,
                min: 0,
                suffixText: 'g',
                onChanged: (v) => weight = v,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: FormaNumberField(
                label: 'Temp. de impressão',
                value: printTemp,
                min: 0,
                max: 500,
                suffixText: '°C',
                onChanged: (v) => printTemp = v,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FormaNumberField(
                label: 'Temp. da mesa',
                value: bedTemp,
                min: 0,
                max: 300,
                suffixText: '°C',
                onChanged: (v) => bedTemp = v,
              ),
            ),
          ],
        ),
        FormaTextField(
          label: 'Descrição',
          controller: description,
          maxLines: 2,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FormaCheckbox(
                value: track,
                label: 'Controlar estoque',
                description: 'Baixa automática ao concluir orçamentos',
                onChanged: (v) => setState(() => track = v),
              ),
            ),
            if (track)
              SizedBox(
                width: 200,
                child: FormaNumberField(
                  label: 'Alerta de estoque baixo',
                  value: threshold,
                  min: 0,
                  suffixText: 'g',
                  onChanged: (v) => threshold = v,
                ),
              ),
          ],
        ),
        if (f != null)
          FormaCheckbox(
            value: active,
            label: 'Ativo',
            description: 'Inativos não aparecem no editor de orçamentos',
            onChanged: (v) => setState(() => active = v),
          ),
      ],
      onSubmit: () {
        if (brandId == null || materialId == null || price == null) {
          selectError = 'required';
          throw const ValidationError(
            'Informe marca, material e preço por kg.',
          );
        }
        final primary = _normalizeHex(hex.text);
        final secondary = _normalizeHex(hex2.text);
        return _repo.saveFilament(
          FilamentInput(
            name: name.text,
            brandId: brandId!,
            materialId: materialId!,
            color: color.text,
            colorType: type,
            colorHex: primary,
            colorData: switch (type) {
              ColorType.duo => {
                'primary': primary,
                'secondary': secondary,
                'pattern': 'stripes',
                'ratio': 0.5,
              },
              ColorType.gradient => {
                'direction': 'to right',
                'colors': [
                  {'color': primary, 'position': 0},
                  {'color': secondary, 'position': 100},
                ],
              },
              ColorType.metallic => {
                'base_color': primary,
                'shine': 0.6,
                'metallic_type': 'silver',
              },
              ColorType.transparent => {
                'base_color': primary,
                'opacity': 0.5,
                'clarity': 'tinted',
              },
              _ => {'color': primary},
            },
            diameter: diameter.toDouble(),
            pricePerKgCents: (price! * 100).round(),
            description: description.text.trim().isEmpty
                ? null
                : description.text.trim(),
            weight: weight?.toDouble(),
            printTemperature: printTemp?.toInt(),
            bedTemperature: bedTemp?.toInt(),
            isActive: f == null ? null : active,
            trackStock: track,
            lowStockThresholdGrams: track ? threshold?.toDouble() : null,
          ),
          id: f?.id,
        );
      },
    );
    if (saved == null || !context.mounted) return;
    _cubit.upsert(saved);
    Toasts.success(
      context,
      f == null ? 'Filamento criado' : 'Filamento atualizado',
    );
  }

  Future<void> _delete(BuildContext context, Filament f) async {
    if (!await confirmDelete(context, what: 'o filamento "${f.displayName}"')) {
      return;
    }
    try {
      await _repo.deleteFilament(f.id);
      _cubit.remove(f.id);
      if (context.mounted) Toasts.success(context, 'Filamento excluído');
    } on ApiError catch (e) {
      if (context.mounted) Toasts.error(context, e);
    }
  }

  Future<void> _stock(BuildContext context, Filament f) async {
    await FormaSideSheet.show<void>(
      context,
      width: 520,
      builder: (_) => FilamentStockSheet(
        filament: f,
        onChanged: () => unawaited(_cubit.refresh()),
      ),
    );
  }
}

String _normalizeHex(String raw) {
  final h = raw.replaceAll('#', '').trim().toUpperCase();
  return '#${h.padRight(6, '0').substring(0, 6)}';
}

/// Linha de cor: amostra + hex + paleta rápida.
class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;

  static const _palette = [
    '#FFFFFF',
    '#000000',
    '#9D9D9D',
    '#FF6B6B',
    '#D93025',
    '#F97316',
    '#EAB308',
    '#22C55E',
    '#00A699',
    '#26C5C5',
    '#3B82F6',
    '#1E3A8A',
    '#8B5CF6',
    '#EC4899',
    '#8B5A2B',
    '#C0C0C0',
  ];

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: 150,
          child: FormaTextField(
            label: label,
            controller: controller,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[#0-9a-fA-F]')),
              LengthLimitingTextInputFormatter(7),
            ],
            onChanged: (_) => onChanged(),
            prefix: Padding(
              padding: const EdgeInsets.all(10),
              child: FilamentSwatch(colorHex: controller.text),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in _palette)
                Tooltip(
                  message: c,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      controller.text = c;
                      onChanged();
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: parseHex(c),
                        border: Border.all(
                          color: controller.text.toUpperCase() == c
                              ? ext.primaryColor
                              : ext.border,
                          width: controller.text.toUpperCase() == c ? 2 : 1,
                        ),
                      ),
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
