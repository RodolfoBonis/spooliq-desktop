import 'package:flutter/material.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/format/formatters.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_draft.dart';
import 'package:spooliq_desktop/features/budgets/presentation/editor/draft_text_field.dart';
import 'package:spooliq_desktop/features/catalog/domain/catalog.dart';
import 'package:spooliq_desktop/features/catalog/domain/catalog_repository.dart';
import 'package:spooliq_desktop/features/catalog/presentation/widgets/filament_swatch.dart';
import 'package:spooliq_desktop/features/presets/domain/preset.dart';

/// Card de edição de um item (produto) do orçamento.
class ItemEditor extends StatelessWidget {
  const ItemEditor({
    required this.index,
    required this.item,
    required this.costPresets,
    required this.onChanged,
    required this.onRemove,
    required this.onDuplicate,
    this.preview,
    this.errors = const {},
    this.onImportSlicer,
    super.key,
  });

  final int index;
  final BudgetItemDraft item;
  final List<Preset> costPresets;
  final void Function(BudgetItemDraft Function(BudgetItemDraft)) onChanged;
  final VoidCallback? onRemove;
  final VoidCallback onDuplicate;

  /// Valores calculados deste item no último preview.
  final BudgetItem? preview;

  /// Erros do rascunho (`item.<index>.<campo>`).
  final Map<String, String> errors;
  final VoidCallback? onImportSlicer;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    String? err(String f) => errors['item.$index.$f'];

    return Container(
      decoration: BoxDecoration(
        color: ext.cardBackground,
        borderRadius: BorderRadius.circular(context.formaShape.cardRadius),
        border: Border.all(color: ext.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabeçalho do item.
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: ext.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ext.primarySurface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: typo.caption12Med.copyWith(color: ext.primaryColor),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.productName.isEmpty ? 'Novo item' : item.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typo.title15.copyWith(color: ext.textPrimary),
                  ),
                ),
                if (preview != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      Fmt.cents(preview!.saleTotalCents),
                      style: typo.body14Medium.copyWith(
                        color: ext.textPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                if (onImportSlicer != null)
                  Tooltip(
                    message:
                        'Importar tempo e filamentos de um arquivo do fatiador',
                    child: TextButton.icon(
                      onPressed: onImportSlicer,
                      icon: const Icon(Icons.upload_file_rounded, size: 16),
                      label: const Text('Importar do fatiador'),
                    ),
                  ),
                FormaMenuButton(
                  tooltip: 'Ações do item',
                  items: [
                    FormaMenuItem(
                      label: 'Duplicar item',
                      icon: Icons.copy_all_outlined,
                      onTap: onDuplicate,
                    ),
                    if (onRemove != null)
                      FormaMenuItem(
                        label: 'Remover item',
                        icon: Icons.delete_outline,
                        destructive: true,
                        onTap: onRemove!,
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: DraftTextField(
                        label: 'Produto',
                        hint: 'Ex.: Suporte de headset',
                        value: item.productName,
                        errorText: err('name'),
                        onChanged: (v) =>
                            onChanged((i) => i.copyWith(productName: v)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
                      child: FormaNumberField(
                        label: 'Quantidade',
                        value: item.quantity,
                        min: 1,
                        step: 1,
                        suffixText: 'un.',
                        errorText: err('quantity'),
                        onChanged: (v) => onChanged(
                          (i) => i.copyWith(quantity: (v ?? 1).toInt()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DraftTextField(
                        label: 'Dimensões',
                        hint: '120 × 80 × 40 mm',
                        value: item.dimensions,
                        onChanged: (v) =>
                            onChanged((i) => i.copyWith(dimensions: v)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DraftTextField(
                  label: 'Descrição para o cliente',
                  hint: 'Aparece no PDF do orçamento',
                  value: item.description,
                  onChanged: (v) =>
                      onChanged((i) => i.copyWith(description: v)),
                ),
                const SizedBox(height: 20),
                const _Subheader('Filamentos', trailing: 'na ordem do AMS'),
                const SizedBox(height: 8),
                _FilamentList(
                  filaments: item.filaments,
                  error: err('filaments'),
                  onChanged: (list) =>
                      onChanged((i) => i.copyWith(filaments: list)),
                ),
                const SizedBox(height: 20),
                const _Subheader('Tempo e mão de obra'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _num(
                      'Impressão',
                      item.printHours,
                      'h',
                      (v) => onChanged((i) => i.copyWith(printHours: v)),
                    ),
                    _num(
                      '',
                      item.printMinutes,
                      'min',
                      (v) => onChanged(
                        (i) => i.copyWith(printMinutes: v.clamp(0, 59)),
                      ),
                      max: 59,
                    ),
                    _num(
                      'Setup',
                      item.setupMinutes,
                      'min',
                      (v) => onChanged((i) => i.copyWith(setupMinutes: v)),
                    ),
                    _num(
                      'Mão de obra (total)',
                      item.laborMinutes,
                      'min',
                      (v) => onChanged((i) => i.copyWith(laborMinutes: v)),
                    ),
                    _num(
                      'Pós-processamento',
                      item.postProcessingMinutes,
                      'min',
                      (v) => onChanged(
                        (i) => i.copyWith(postProcessingMinutes: v),
                      ),
                    ),
                    _num(
                      'Remoção de suporte',
                      item.supportRemovalMinutes,
                      'min',
                      (v) => onChanged(
                        (i) => i.copyWith(supportRemovalMinutes: v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 260,
                      child: FormaSelect<String>(
                        label: 'Preset de custos do item',
                        hint: 'Usar o do orçamento',
                        clearable: true,
                        value: item.costPresetId,
                        options: [
                          for (final p in costPresets)
                            FormaSelectOption(value: p.id, label: p.name),
                        ],
                        onChanged: (v) =>
                            onChanged((i) => i.copyWith(costPresetId: () => v)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DraftTextField(
                        label: 'Notas internas',
                        value: item.notes,
                        onChanged: (v) =>
                            onChanged((i) => i.copyWith(notes: v)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _num(
    String label,
    int value,
    String suffix,
    ValueChanged<int> onChanged, {
    int? max,
  }) => SizedBox(
    width: 150,
    child: FormaNumberField(
      label: label.isEmpty ? ' ' : label,
      value: value,
      min: 0,
      max: max,
      suffixText: suffix,
      onChanged: (v) => onChanged((v ?? 0).toInt()),
    ),
  );
}

class _Subheader extends StatelessWidget {
  const _Subheader(this.title, {this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    return Row(
      children: [
        Text(title, style: typo.caption12Med.copyWith(color: ext.textPrimary)),
        if (trailing != null) ...[
          const SizedBox(width: 6),
          Text(trailing!, style: typo.caption12.copyWith(color: ext.textHint)),
        ],
      ],
    );
  }
}

/// Lista ordenável de filamentos com busca no catálogo.
class _FilamentList extends StatelessWidget {
  const _FilamentList({
    required this.filaments,
    required this.onChanged,
    this.error,
  });

  final List<FilamentUsageDraft> filaments;
  final ValueChanged<List<FilamentUsageDraft>> onChanged;
  final String? error;

  static Future<List<FormaSelectOption<Filament>>> _search(String q) async {
    final page = await di<CatalogRepository>().filaments(
      page: PageQuery(pageSize: 12, search: q.isEmpty ? null : q),
    );
    return [
      for (final f in page.items.where((f) => f.isActive))
        FormaSelectOption(
          value: f,
          label: f.displayName,
          subtitle: [
            f.subtitle,
            '${Fmt.cents(f.pricePerKgCents)}/kg',
            if (f.trackStock) 'estoque ${Fmt.grams(f.stockGrams)}',
          ].join(' · '),
          leading: FilamentSwatch.of(f, size: 18),
        ),
    ];
  }

  void _set(int index, FilamentUsageDraft value) =>
      onChanged([...filaments]..[index] = value);

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final total = filaments.fold<double>(0, (s, f) => s + f.grams);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, f) in filaments.indexed)
          Padding(
            key: ValueKey('${f.filamentId}-$i'),
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: Text(
                    '${i + 1}',
                    style: typo.caption12Med.copyWith(color: ext.textHint),
                  ),
                ),
                Expanded(
                  child: FormaCombobox<Filament>(
                    hint: 'Buscar filamento…',
                    value: f.filamentId.isEmpty
                        ? null
                        : FormaSelectOption(
                            value: _placeholder(f),
                            label: f.label,
                            leading: FilamentSwatch(
                              colorHex: f.colorHex,
                            ),
                          ),
                    search: _search,
                    onChanged: (opt) {
                      final picked = opt?.value;
                      _set(
                        i,
                        picked == null
                            ? FilamentUsageDraft(filamentId: '', grams: f.grams)
                            : FilamentUsageDraft(
                                filamentId: picked.id,
                                grams: f.grams,
                                label: picked.displayName,
                                colorHex: picked.colorHex,
                              ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 130,
                  child: FormaNumberField(
                    value: f.grams,
                    decimals: 1,
                    min: 0,
                    suffixText: 'g',
                    onChanged: (v) =>
                        _set(i, f.copyWith(grams: (v ?? 0).toDouble())),
                  ),
                ),
                const SizedBox(width: 4),
                _IconAction(
                  icon: Icons.arrow_upward_rounded,
                  tooltip: 'Mover para cima',
                  onPressed: i == 0
                      ? null
                      : () => onChanged(
                          [...filaments]
                            ..removeAt(i)
                            ..insert(i - 1, f),
                        ),
                ),
                _IconAction(
                  icon: Icons.arrow_downward_rounded,
                  tooltip: 'Mover para baixo',
                  onPressed: i == filaments.length - 1
                      ? null
                      : () => onChanged(
                          [...filaments]
                            ..removeAt(i)
                            ..insert(i + 1, f),
                        ),
                ),
                _IconAction(
                  icon: Icons.close_rounded,
                  tooltip: 'Remover filamento',
                  onPressed: () => onChanged([...filaments]..removeAt(i)),
                ),
              ],
            ),
          ),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => onChanged([
                ...filaments,
                const FilamentUsageDraft(filamentId: '', grams: 0),
              ]),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Adicionar filamento'),
            ),
            const Spacer(),
            if (filaments.length > 1)
              Text(
                'Total ${Fmt.grams(total)} · ${filaments.length - 1} '
                '${filaments.length == 2 ? 'troca' : 'trocas'} de cor',
                style: typo.caption12.copyWith(color: ext.textMuted),
              ),
          ],
        ),
        if (error != null)
          Text(error!, style: typo.caption12.copyWith(color: ext.errorColor)),
      ],
    );
  }

  /// O combobox exige um `Filament` como valor; para o item já escolhido
  /// usamos um objeto mínimo com o mesmo id.
  static Filament _placeholder(FilamentUsageDraft f) => Filament(
    id: f.filamentId,
    name: f.label,
    brandId: '',
    materialId: '',
    color: '',
    colorType: ColorType.solid,
    colorHex: f.colorHex,
    diameter: 1.75,
    pricePerKgCents: 0,
  );
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    return IconButton(
      tooltip: tooltip,
      iconSize: 16,
      visualDensity: VisualDensity.compact,
      color: ext.textMuted,
      disabledColor: ext.border,
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}
