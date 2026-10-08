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
import 'package:spooliq_desktop/features/auth/presentation/session_cubit.dart';
import 'package:spooliq_desktop/features/presets/domain/preset.dart';
import 'package:spooliq_desktop/features/presets/domain/preset_repository.dart';

/// Presets de máquina, energia ou custos — tela guiada por [PresetSchema].
class PresetsPage extends StatelessWidget {
  const PresetsPage({required this.type, super.key});

  final PresetType type;

  @override
  Widget build(BuildContext context) {
    final repo = di<PresetRepository>();
    return BlocProvider(
      key: ValueKey(type),
      create: (_) {
        final cubit = PagedListCubit<Preset>(
          (_) async {
            final items = await repo.list(type);
            return Paginated(
              items: items,
              total: items.length,
              page: 1,
              pageSize: items.length,
              totalPages: 1,
            );
          },
          idOf: (p) => p.id,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: _PresetsView(type: type),
    );
  }
}

class _PresetsView extends StatelessWidget {
  const _PresetsView({required this.type});

  final PresetType type;

  String get _subtitle => switch (type) {
    PresetType.machine =>
      'Consumo e custo/hora de cada impressora entram no preço de cada peça.',
    PresetType.energy => r'Tarifa de energia (R$/kWh) usada no custo elétrico.',
    PresetType.cost =>
      'Mão de obra, overhead, margem, falhas, embalagem e frete.',
  };

  @override
  Widget build(BuildContext context) {
    final canManage = context.select<SessionCubit, bool>(
      (c) => c.state.user?.canManagePresets ?? false,
    );
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final fields = PresetSchema.of(type).where((f) => f.inTable).toList();

    return PageLayout(
      title: type.plural,
      subtitle: _subtitle,
      actions: [
        if (canManage) ...[
          FormaButton.secondary(
            label: 'Usar template',
            small: true,
            icon: const Icon(Icons.auto_awesome_outlined, size: 16),
            onPressed: () => unawaited(_fromTemplate(context)),
          ),
          FormaButton.primary(
            label: 'Novo preset',
            small: true,
            icon: const Icon(Icons.add, size: 18, color: Colors.white),
            onPressed: () => unawaited(_edit(context)),
          ),
        ],
      ],
      body: PagedTable<Preset>(
        itemLabel: 'presets',
        onRowTap: canManage ? (p) => unawaited(_edit(context, p)) : null,
        columns: [
          FormaColumn(
            id: 'name',
            label: 'Nome',
            flex: 2,
            cellBuilder: (_, p) => Row(
              children: [
                Flexible(
                  child: Text(
                    p.name,
                    overflow: TextOverflow.ellipsis,
                    style: typo.body14Medium.copyWith(color: ext.textPrimary),
                  ),
                ),
                if (p.isDefault) ...[
                  const SizedBox(width: 8),
                  const FormaBadge(
                    label: 'Padrão',
                    variant: FormaBadgeVariant.primary,
                  ),
                ],
              ],
            ),
          ),
          for (final f in fields)
            FormaColumn(
              id: f.key,
              label: f.label,
              cellBuilder: (_, p) => Text(
                _format(f, p),
                style: typo.body14.copyWith(color: ext.textMuted),
              ),
            ),
        ],
        trailingBuilder: canManage
            ? (context, p) => FormaMenuButton(
                items: [
                  FormaMenuItem(
                    label: 'Editar',
                    icon: Icons.edit_outlined,
                    onTap: () => unawaited(_edit(context, p)),
                  ),
                  FormaMenuItem(
                    label: 'Duplicar',
                    icon: Icons.copy_all_outlined,
                    onTap: () => unawaited(
                      _run(context, 'Preset duplicado', () async {
                        await di<PresetRepository>().duplicate(p.id, type);
                      }),
                    ),
                  ),
                  if (!p.isDefault)
                    FormaMenuItem(
                      label: 'Definir como padrão',
                      icon: Icons.star_outline_rounded,
                      onTap: () => unawaited(
                        _run(
                          context,
                          'Preset padrão atualizado',
                          () => di<PresetRepository>().setDefault(p.id),
                        ),
                      ),
                    ),
                  const FormaMenuItem.divider(),
                  FormaMenuItem(
                    label: 'Excluir',
                    icon: Icons.delete_outline,
                    destructive: true,
                    onTap: () async {
                      if (!await confirmDelete(context, what: '"${p.name}"')) {
                        return;
                      }
                      if (!context.mounted) return;
                      await _run(
                        context,
                        'Preset excluído',
                        () => di<PresetRepository>().delete(p.id),
                      );
                    },
                  ),
                ],
              )
            : null,
        empty: FormaEmptyState(
          icon: Icons.tune_outlined,
          title: 'Nenhum preset de ${type.label.toLowerCase()}',
          message: 'Comece por um template e ajuste os valores.',
          action: canManage
              ? FormaButton.primary(
                  label: 'Usar template',
                  small: true,
                  onPressed: () => unawaited(_fromTemplate(context)),
                )
              : null,
        ),
      ),
    );
  }

  static String _format(PresetField f, Preset p) {
    if (!f.isNumeric) return p.text(f.key) ?? '—';
    final n = p.number(f.key);
    if (n == null) return '—';
    return switch (f.kind) {
      PresetFieldKind.money =>
        '${Fmt.money(n)}${f.unit == null ? '' : f.unit!}',
      PresetFieldKind.percent => Fmt.percent(n),
      _ =>
        '${Fmt.number(n, decimals: n % 1 == 0 ? 0 : f.decimals)}'
            '${f.unit == null ? '' : ' ${f.unit}'}',
    };
  }

  Future<void> _run(
    BuildContext context,
    String success,
    Future<void> Function() action,
  ) async {
    final cubit = context.read<PagedListCubit<Preset>>();
    try {
      await action();
      await cubit.refresh();
      if (context.mounted) Toasts.success(context, success);
    } on ApiError catch (e) {
      if (context.mounted) Toasts.error(context, e);
    }
  }

  Future<void> _fromTemplate(BuildContext context) async {
    final cubit = context.read<PagedListCubit<Preset>>();
    final repo = di<PresetRepository>();
    List<PresetTemplate> templates;
    try {
      templates = await repo.templates(type);
    } on ApiError catch (e) {
      if (context.mounted) Toasts.error(context, e);
      return;
    }
    if (!context.mounted) return;
    final picked = await FormaDialog.show<PresetTemplate>(
      context,
      title: 'Templates de ${type.label.toLowerCase()}',
      description: 'Valores de referência para começar rápido.',
      width: 560,
      child: templates.isEmpty
          ? const FormaEmptyState(
              compact: true,
              icon: Icons.inbox_outlined,
              title: 'Nenhum template disponível',
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final t in templates)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    leading: const Icon(Icons.auto_awesome_outlined),
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
    if (picked == null || !context.mounted) return;
    try {
      await repo.fromTemplate(picked.key, type);
      await cubit.refresh();
      if (context.mounted) {
        Toasts.success(context, 'Preset criado', description: picked.name);
      }
    } on ApiError catch (e) {
      if (context.mounted) Toasts.error(context, e);
    }
  }

  Future<void> _edit(BuildContext context, [Preset? preset]) async {
    final cubit = context.read<PagedListCubit<Preset>>();
    final name = TextEditingController(text: preset?.name);
    final description = TextEditingController(text: preset?.description);
    final values = Map<String, dynamic>.of(preset?.values ?? const {});
    final texts = {
      for (final f in PresetSchema.of(type).where((f) => !f.isNumeric))
        f.key: TextEditingController(
          text:
              values[f.key]?.toString() ??
              (f.key == 'currency'
                  ? 'BRL'
                  : f.key == 'country'
                  ? 'BR'
                  : ''),
        ),
    };
    var isDefault = preset?.isDefault ?? false;

    final saved = await showFormDialog<Preset>(
      context,
      title: preset == null
          ? 'Novo preset de ${type.label.toLowerCase()}'
          : 'Editar preset',
      width: 680,
      fields: (setState) => [
        FormaTextField(
          label: 'Nome',
          controller: name,
          autofocus: true,
          validator: requiredValidator,
        ),
        Wrap(
          spacing: 12,
          runSpacing: 14,
          children: [
            for (final f in PresetSchema.of(type))
              SizedBox(
                width: 196,
                child: f.isNumeric
                    ? FormaNumberField(
                        label: f.required ? f.label : '${f.label} (opcional)',
                        value: values[f.key] is num
                            ? values[f.key] as num
                            : num.tryParse('${values[f.key] ?? ''}'),
                        decimals: f.kind == PresetFieldKind.integer
                            ? 0
                            : f.decimals,
                        min: f.min ?? 0,
                        max: f.max,
                        prefixText: f.kind == PresetFieldKind.money
                            ? r'R$'
                            : null,
                        suffixText: f.kind == PresetFieldKind.percent
                            ? '%'
                            : f.kind == PresetFieldKind.money
                            ? null
                            : f.unit,
                        helperText: f.help,
                        onChanged: (v) => values[f.key] = v,
                      )
                    : FormaTextField(
                        label: f.label,
                        controller: texts[f.key],
                        validator: f.required ? requiredValidator : null,
                      ),
              ),
          ],
        ),
        FormaTextField(
          label: 'Descrição',
          controller: description,
          maxLines: 2,
        ),
        FormaCheckbox(
          value: isDefault,
          label: 'Usar como padrão',
          description: 'Aplicado quando o orçamento não define outro',
          onChanged: (v) => setState(() => isDefault = v),
        ),
      ],
      onSubmit: () {
        final missing = PresetSchema.of(type)
            .where((f) => f.required && f.isNumeric && values[f.key] == null)
            .map((f) => f.label)
            .toList();
        if (missing.isNotEmpty) {
          throw ValidationError('Preencha: ${missing.join(', ')}.');
        }
        final merged = <String, dynamic>{
          for (final e in values.entries)
            if (e.value != null) e.key: e.value,
          for (final e in texts.entries)
            if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
        };
        final draft = Preset(
          id: preset?.id ?? '',
          type: type,
          name: name.text,
          description: description.text,
          isDefault: isDefault,
          isActive: preset?.isActive ?? true,
          values: merged,
        );
        return di<PresetRepository>().save(draft, create: preset == null);
      },
    );
    if (saved == null || !context.mounted) return;
    await cubit.refresh();
    if (context.mounted) {
      Toasts.success(
        context,
        preset == null ? 'Preset criado' : 'Preset atualizado',
      );
    }
  }
}
