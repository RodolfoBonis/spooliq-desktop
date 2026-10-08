import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/format/formatters.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/core/routing/routes.dart';
import 'package:spooliq_desktop/core/ui/feedback.dart';
import 'package:spooliq_desktop/core/ui/page_layout.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget.dart';
import 'package:spooliq_desktop/features/budgets/presentation/editor/budget_editor_cubit.dart';
import 'package:spooliq_desktop/features/budgets/presentation/editor/draft_text_field.dart';
import 'package:spooliq_desktop/features/budgets/presentation/editor/item_editor.dart';
import 'package:spooliq_desktop/features/budgets/presentation/editor/preview_panel.dart';
import 'package:spooliq_desktop/features/budgets/presentation/editor/slicer_import.dart';
import 'package:spooliq_desktop/features/customers/domain/customer_repository.dart';
import 'package:spooliq_desktop/features/models3d/domain/model3d.dart';
import 'package:spooliq_desktop/features/presets/domain/preset.dart';

class SaveIntent extends Intent {
  const SaveIntent();
}

/// Criação (`budgetId == null`) e edição de rascunhos.
class BudgetEditorPage extends StatelessWidget {
  const BudgetEditorPage({this.budgetId, this.customerId, super.key});

  final String? budgetId;
  final String? customerId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      key: ValueKey(budgetId ?? 'new-$customerId'),
      create: (_) {
        final cubit = BudgetEditorCubit(
          budgets: di(),
          presets: di(),
          company: di(),
          customers: di(),
          budgetId: budgetId,
          initialCustomerId: customerId,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: const _EditorView(),
    );
  }
}

class _EditorView extends StatelessWidget {
  const _EditorView();

  Future<void> _save(BuildContext context) async {
    final cubit = context.read<BudgetEditorCubit>();
    final saved = await cubit.save();
    if (!context.mounted) return;
    if (saved == null) {
      if (cubit.state.errors.isNotEmpty) {
        FormaToast.show(
          context,
          message: 'Revise os campos destacados',
          description: cubit.state.errors.values.first,
          variant: FormaToastVariant.warning,
        );
      }
      return;
    }
    Toasts.success(
      context,
      cubit.isEditing ? 'Orçamento atualizado' : 'Orçamento criado',
      description: saved.name,
    );
    context.go(Routes.budget(saved.id));
  }

  Future<void> _leave(BuildContext context) async {
    final cubit = context.read<BudgetEditorCubit>();
    if (cubit.state.dirty) {
      final ok = await FormaConfirmDialog.show(
        context,
        title: 'Descartar alterações?',
        message: 'As alterações que você fez neste orçamento serão perdidas.',
        confirmLabel: 'Descartar',
        destructive: true,
      );
      if (!ok || !context.mounted) return;
    }
    if (cubit.budgetId != null) {
      context.go(Routes.budget(cubit.budgetId!));
    } else {
      context.go(Routes.budgets);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMac = Theme.of(context).platform == TargetPlatform.macOS;
    return BlocBuilder<BudgetEditorCubit, BudgetEditorState>(
      builder: (context, state) {
        final cubit = context.read<BudgetEditorCubit>();
        if (state.status == EditorStatus.loading) return const LoadingView();
        if (state.status == EditorStatus.failure) {
          return ErrorView(
            message: state.loadError ?? 'Erro ao carregar.',
            onRetry: () => unawaited(cubit.load()),
          );
        }

        return CallbackShortcuts(
          bindings: {
            SingleActivator(
              LogicalKeyboardKey.keyS,
              meta: isMac,
              control: !isMac,
            ): () =>
                unawaited(_save(context)),
          },
          child: PageLayout(
            leading: Tooltip(
              message: 'Voltar',
              child: FormaIconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                onPressed: () => unawaited(_leave(context)),
              ),
            ),
            title: cubit.isEditing ? 'Editar orçamento' : 'Novo orçamento',
            subtitle: state.dirty
                ? 'Alterações não salvas · '
                      '${isMac ? '⌘' : 'Ctrl+'}S para salvar'
                : 'O preço é recalculado automaticamente enquanto você edita.',
            actions: [
              FormaButton.secondary(
                label: 'Cancelar',
                small: true,
                onPressed: () => unawaited(_leave(context)),
              ),
              FormaButton.primary(
                label: cubit.isEditing
                    ? 'Salvar alterações'
                    : 'Criar orçamento',
                small: true,
                isLoading: state.status == EditorStatus.saving,
                icon: const Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                onPressed: () => unawaited(_save(context)),
              ),
            ],
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(right: 4, bottom: 48),
                    child: _Form(state: state),
                  ),
                ),
                const SizedBox(width: 20),
                SizedBox(
                  width: 360,
                  child: SingleChildScrollView(
                    child: PreviewPanel(state: state),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({required this.state});

  final BudgetEditorState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BudgetEditorCubit>();
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final d = state.draft;
    final e = state.errors;
    final lookups = state.lookups;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.saveError != null) ...[
          FormaAlertBanner(
            message: state.saveError!,
            variant: FormaAlertVariant.error,
          ),
          const SizedBox(height: 16),
        ],
        SectionCard(
          title: 'Informações básicas',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: DraftTextField(
                      label: 'Nome do projeto',
                      hint: 'Ex.: Kit organizadores de mesa',
                      value: d.name,
                      autofocus: !cubit.isEditing,
                      errorText: e['name'],
                      onChanged: (v) =>
                          cubit.update((d) => d.copyWith(name: v)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FormaCombobox<String>(
                      label: 'Cliente',
                      hint: 'Buscar cliente…',
                      errorText: e['customer'],
                      value: d.customerId == null
                          ? null
                          : FormaSelectOption(
                              value: d.customerId!,
                              label: d.customerName ?? '',
                            ),
                      search: (q) async {
                        final page = await di<CustomerRepository>().list(
                          page: PageQuery(
                            pageSize: 10,
                            search: q.isEmpty ? null : q,
                          ),
                        );
                        return [
                          for (final c in page.items)
                            FormaSelectOption(
                              value: c.id,
                              label: c.name,
                              subtitle: c.email ?? c.phone,
                            ),
                        ];
                      },
                      onChanged: (opt) => cubit.update(
                        (d) => d.copyWith(
                          customerId: () => opt?.value,
                          customerName: () => opt?.label,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DraftTextField(
                label: 'Descrição',
                hint: 'Contexto do pedido (aparece no PDF)',
                value: d.description,
                maxLines: 3,
                minLines: 2,
                onChanged: (v) =>
                    cubit.update((d) => d.copyWith(description: v)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Parâmetros de cálculo',
          subtitle:
              'O perfil define máquina, energia e custos. Sobrescreva só o que '
              'for diferente neste orçamento.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormaSelect<String>(
                label: 'Perfil de impressão',
                hint: 'Padrão da empresa',
                clearable: true,
                value: d.profileId,
                options: [
                  for (final p in lookups.profiles)
                    FormaSelectOption(
                      value: p.id,
                      label: p.isDefault ? '${p.name} (padrão)' : p.name,
                      subtitle: [
                        p.machinePreset?.name,
                        p.energyPreset?.name,
                        p.costPreset?.name,
                      ].whereType<String>().join(' · '),
                    ),
                ],
                onChanged: cubit.selectProfile,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _presetSelect(
                      'Máquina',
                      d.machinePresetId,
                      lookups.machines,
                      (v) => cubit.update(
                        (d) => d.copyWith(machinePresetId: () => v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _presetSelect(
                      'Energia',
                      d.energyPresetId,
                      lookups.energy,
                      (v) => cubit.update(
                        (d) => d.copyWith(energyPresetId: () => v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _presetSelect(
                      'Custos e margem',
                      d.costPresetId,
                      lookups.costs,
                      (v) => cubit.update(
                        (d) => d.copyWith(costPresetId: () => v),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  FormaCheckbox(
                    value: d.includeEnergyCost,
                    label: 'Custo de energia',
                    onChanged: (v) =>
                        cubit.update((d) => d.copyWith(includeEnergyCost: v)),
                  ),
                  FormaCheckbox(
                    value: d.includeWasteCost,
                    label: 'Desperdício nas trocas de cor (AMS)',
                    onChanged: (v) =>
                        cubit.update((d) => d.copyWith(includeWasteCost: v)),
                  ),
                  FormaCheckbox(
                    value: d.includeMachineCost,
                    label: 'Desgaste da máquina',
                    onChanged: (v) =>
                        cubit.update((d) => d.copyWith(includeMachineCost: v)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Text(
              'Itens',
              style: typo.title16.copyWith(color: ext.textPrimary),
            ),
            const SizedBox(width: 8),
            Text(
              '${d.items.length}',
              style: typo.body14.copyWith(color: ext.textHint),
            ),
            const Spacer(),
            FormaButton.secondary(
              label: 'Adicionar item',
              small: true,
              icon: const Icon(Icons.add_rounded, size: 18),
              onPressed: cubit.addItem,
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final (i, item) in d.items.indexed) ...[
          ItemEditor(
            key: ValueKey(item.key),
            index: i,
            item: item,
            costPresets: lookups.costs,
            errors: e,
            preview: _previewItem(state.preview, i),
            onChanged: (change) => cubit.updateItem(item.key, change),
            onDuplicate: () => cubit.duplicateItem(item.key),
            onRemove: d.items.length > 1
                ? () => cubit.removeItem(item.key)
                : null,
            onImportSlicer: () => unawaited(_importSlicer(context, item.key)),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 12),
        SectionCard(
          title: 'Preço final',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 220,
                    child: FormaSelect<DiscountType?>(
                      label: 'Desconto',
                      value: d.discountType,
                      options: const [
                        FormaSelectOption(value: null, label: 'Sem desconto'),
                        FormaSelectOption(
                          value: DiscountType.percent,
                          label: 'Percentual (%)',
                        ),
                        FormaSelectOption(
                          value: DiscountType.fixed,
                          label: r'Valor fixo (R$)',
                        ),
                      ],
                      onChanged: (v) => cubit.update(
                        (d) => d.copyWith(
                          discountType: () => v,
                          discountValue: () =>
                              v == null ? null : d.discountValue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (d.discountType != null)
                    SizedBox(
                      width: 160,
                      child: FormaNumberField(
                        label: 'Valor do desconto',
                        value: d.discountValue,
                        decimals: 2,
                        min: 0,
                        max: d.discountType == DiscountType.percent
                            ? 100
                            : null,
                        prefixText: d.discountType == DiscountType.fixed
                            ? r'R$'
                            : null,
                        suffixText: d.discountType == DiscountType.percent
                            ? '%'
                            : null,
                        errorText: e['discount'],
                        onChanged: (v) => cubit.update(
                          (d) => d.copyWith(discountValue: () => v?.toDouble()),
                        ),
                      ),
                    ),
                  const Spacer(),
                  SizedBox(
                    width: 200,
                    child: FormaNumberField(
                      label: 'Alíquota de imposto',
                      value: d.taxRate,
                      decimals: 2,
                      min: 0,
                      max: 99.99,
                      suffixText: '%',
                      errorText: e['tax'],
                      helperText: d.taxRate == null
                          ? _taxHelper(lookups.company?.defaultTaxRate)
                          : null,
                      onChanged: (v) => cubit.update(
                        (d) => d.copyWith(taxRate: () => v?.toDouble()),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FormaCheckbox(
                    value: d.includeShipping,
                    label: 'Incluir frete',
                    description: 'Calculado pelo preset de custos',
                    onChanged: (v) =>
                        cubit.update((d) => d.copyWith(includeShipping: v)),
                  ),
                  const SizedBox(width: 24),
                  if (d.includeShipping)
                    SizedBox(
                      width: 200,
                      child: FormaNumberField(
                        label: 'Frete manual',
                        value: d.shippingOverrideReais,
                        decimals: 2,
                        min: 0,
                        prefixText: r'R$',
                        helperText: 'Opcional: substitui o cálculo',
                        onChanged: (v) => cubit.update(
                          (d) => d.copyWith(
                            shippingOverrideReais: () => v?.toDouble(),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Condições comerciais',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 180,
                    child: FormaNumberField(
                      label: 'Prazo de entrega',
                      value: d.deliveryDays,
                      min: 0,
                      suffixText: 'dias',
                      onChanged: (v) => cubit.update(
                        (d) => d.copyWith(deliveryDays: () => v?.toInt()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 200,
                    child: FormaDateField(
                      label: 'Válido até',
                      value: d.validUntil,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      onChanged: (v) =>
                          cubit.update((d) => d.copyWith(validUntil: () => v)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DraftTextField(
                      label: 'Condições de pagamento',
                      hint: 'Ex.: 50% na aprovação, 50% na entrega',
                      value: d.paymentTerms,
                      onChanged: (v) =>
                          cubit.update((d) => d.copyWith(paymentTerms: v)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DraftTextField(
                label: 'Observações',
                value: d.notes,
                maxLines: 3,
                minLines: 2,
                onChanged: (v) => cubit.update((d) => d.copyWith(notes: v)),
              ),
              if (d.validUntil == null) ...[
                const SizedBox(height: 8),
                Text(
                  'Sem data de validade, ela será definida ao enviar '
                  '(${lookups.company?.defaultQuoteValidityDays ?? 15} dias).',
                  style: typo.caption12.copyWith(color: ext.textHint),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static Future<void> _importSlicer(BuildContext context, int itemKey) async {
    final cubit = context.read<BudgetEditorCubit>();
    final result = await pickSlicerFile(context);
    if (result == null || !context.mounted) return;
    cubit.applySlice(itemKey, result.plates, productName: result.productName);
    final unmatched = cubit.state.draft.items
        .firstWhere((i) => i.key == itemKey)
        .filaments
        .where((f) => f.filamentId.isEmpty)
        .length;
    FormaToast.show(
      context,
      message: 'Fatiamento importado',
      description: unmatched == 0
          ? 'Tempo e filamentos preenchidos.'
          : '$unmatched filamento(s) sem correspondência no catálogo — '
                'selecione manualmente.',
      variant: unmatched == 0
          ? FormaToastVariant.success
          : FormaToastVariant.warning,
      duration: const Duration(seconds: 8),
      actionLabel: result.canSaveToLibrary ? 'Salvar na biblioteca' : null,
      onAction: result.canSaveToLibrary
          ? () => unawaited(_saveToLibrary(context, cubit, itemKey, result))
          : null,
    );
  }

  /// Envia o arquivo do fatiador para a biblioteca e vincula ao item.
  static Future<void> _saveToLibrary(
    BuildContext context,
    BudgetEditorCubit cubit,
    int itemKey,
    SlicerImport result,
  ) async {
    Toasts.info(context, 'Enviando para a biblioteca…');
    try {
      final model = await di<Model3DRepository>().upload(
        filePath: result.filePath,
        name: result.productName,
        customerId: cubit.state.draft.customerId,
      );
      cubit.updateItem(
        itemKey,
        (i) => i.copyWith(
          model3dId: () => model.id,
          model3dName: () => model.name,
        ),
      );
      if (context.mounted) {
        Toasts.success(
          context,
          'Modelo salvo e vinculado',
          description: model.name,
        );
      }
    } on ApiError catch (e) {
      if (context.mounted) Toasts.error(context, e);
    }
  }

  static String _taxHelper(double? companyDefault) => companyDefault == null
      ? 'Vazio = padrão da empresa'
      : 'Vazio = padrão da empresa (${Fmt.percent(companyDefault)})';

  static BudgetItem? _previewItem(Budget? preview, int index) {
    if (preview == null || index >= preview.items.length) return null;
    return preview.items[index];
  }

  Widget _presetSelect(
    String label,
    String? value,
    List<Preset> presets,
    ValueChanged<String?> onChanged,
  ) => FormaSelect<String>(
    label: label,
    hint: 'Automático (perfil)',
    clearable: true,
    value: value,
    options: [
      for (final p in presets)
        FormaSelectOption(
          value: p.id,
          label: p.isDefault ? '${p.name} (padrão)' : p.name,
        ),
    ],
    onChanged: onChanged,
  );
}
