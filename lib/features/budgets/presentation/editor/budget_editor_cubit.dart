import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/observability/app_logger.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_draft.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_repository.dart';
import 'package:spooliq_desktop/features/company/domain/company.dart';
import 'package:spooliq_desktop/features/company/domain/company_repository.dart';
import 'package:spooliq_desktop/features/customers/domain/customer_repository.dart';
import 'package:spooliq_desktop/features/models3d/domain/model3d.dart';
import 'package:spooliq_desktop/features/presets/domain/preset.dart';
import 'package:spooliq_desktop/features/presets/domain/preset_repository.dart';

enum EditorStatus { loading, ready, saving, saved, failure }

/// Opções para os seletores de preset/perfil.
class EditorLookups extends Equatable {
  const EditorLookups({
    this.profiles = const [],
    this.machines = const [],
    this.energy = const [],
    this.costs = const [],
    this.company,
  });

  final List<PrintProfile> profiles;
  final List<Preset> machines;
  final List<Preset> energy;
  final List<Preset> costs;
  final Company? company;

  @override
  List<Object?> get props => [profiles, machines, energy, costs, company];
}

class BudgetEditorState extends Equatable {
  const BudgetEditorState({
    this.status = EditorStatus.loading,
    this.draft = const BudgetDraft(),
    this.lookups = const EditorLookups(),
    this.preview,
    this.previewing = false,
    this.previewError,
    this.errors = const {},
    this.dirty = false,
    this.loadError,
    this.saveError,
    this.saved,
  });

  final EditorStatus status;
  final BudgetDraft draft;
  final EditorLookups lookups;

  /// Último cálculo do servidor (`POST /budgets/preview`).
  final Budget? preview;
  final bool previewing;
  final String? previewError;

  /// Erros de validação (só exibidos após a 1ª tentativa de salvar).
  final Map<String, String> errors;
  final bool dirty;
  final String? loadError;
  final String? saveError;
  final Budget? saved;

  BudgetEditorState copyWith({
    EditorStatus? status,
    BudgetDraft? draft,
    EditorLookups? lookups,
    Budget? Function()? preview,
    bool? previewing,
    String? Function()? previewError,
    Map<String, String>? errors,
    bool? dirty,
    String? Function()? loadError,
    String? Function()? saveError,
    Budget? saved,
  }) => BudgetEditorState(
    status: status ?? this.status,
    draft: draft ?? this.draft,
    lookups: lookups ?? this.lookups,
    preview: preview == null ? this.preview : preview(),
    previewing: previewing ?? this.previewing,
    previewError: previewError == null ? this.previewError : previewError(),
    errors: errors ?? this.errors,
    dirty: dirty ?? this.dirty,
    loadError: loadError == null ? this.loadError : loadError(),
    saveError: saveError == null ? this.saveError : saveError(),
    saved: saved ?? this.saved,
  );

  @override
  List<Object?> get props => [
    status,
    draft,
    lookups,
    preview,
    previewing,
    previewError,
    errors,
    dirty,
    loadError,
    saveError,
    saved,
  ];
}

/// Editor de orçamento (criação e edição de rascunhos).
class BudgetEditorCubit extends Cubit<BudgetEditorState> {
  BudgetEditorCubit({
    required BudgetRepository budgets,
    required PresetRepository presets,
    required CompanyRepository company,
    required CustomerRepository customers,
    this.budgetId,
    this.initialCustomerId,
    this.previewDebounce = const Duration(milliseconds: 400),
  }) : _budgets = budgets,
       _presets = presets,
       _company = company,
       _customers = customers,
       super(const BudgetEditorState());

  final BudgetRepository _budgets;
  final PresetRepository _presets;
  final CompanyRepository _company;
  final CustomerRepository _customers;
  final String? budgetId;
  final String? initialCustomerId;
  final Duration previewDebounce;

  Timer? _debounce;
  int _previewRequest = 0;
  bool _submitted = false;

  bool get isEditing => budgetId != null;

  Future<void> load() async {
    emit(state.copyWith(status: EditorStatus.loading, loadError: () => null));
    try {
      final lookups = await _loadLookups();
      var draft = const BudgetDraft();
      if (budgetId != null) {
        final budget = await _budgets.get(budgetId!);
        if (!budget.status.isEditable) {
          emit(
            state.copyWith(
              status: EditorStatus.failure,
              loadError: () =>
                  'Somente rascunhos podem ser editados. Volte o orçamento '
                  'para rascunho para alterá-lo.',
            ),
          );
          return;
        }
        draft = BudgetDraft.fromBudget(budget);
      } else {
        final defaultProfile = lookups.profiles
            .where((p) => p.isDefault)
            .firstOrNull;
        draft = draft.copyWith(
          profileId: () => defaultProfile?.id,
          paymentTerms: lookups.company?.defaultPaymentTerms ?? '',
        );
        if (initialCustomerId != null) {
          final customer = await _customers.get(initialCustomerId!);
          draft = draft.copyWith(
            customerId: () => customer.id,
            customerName: () => customer.name,
          );
        }
      }
      if (isClosed) return;
      emit(
        state.copyWith(
          status: EditorStatus.ready,
          draft: draft,
          lookups: lookups,
        ),
      );
      _schedulePreview(immediate: true);
    } on ApiError catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: EditorStatus.failure,
          loadError: () => e.message,
        ),
      );
    }
  }

  Future<EditorLookups> _loadLookups() async {
    final profiles = _presets.profiles();
    final machines = _presets.list(PresetType.machine);
    final energy = _presets.list(PresetType.energy);
    final costs = _presets.list(PresetType.cost);
    Company? company;
    try {
      company = await _company.get();
    } on ApiError catch (e) {
      AppLogger.warning('Empresa indisponível no editor', error: e);
    }
    return EditorLookups(
      profiles: (await profiles).items,
      machines: await machines,
      energy: await energy,
      costs: await costs,
      company: company,
    );
  }

  /// Aplica uma alteração ao rascunho e agenda o recálculo.
  void update(BudgetDraft Function(BudgetDraft draft) change) {
    final draft = change(state.draft);
    if (draft == state.draft) return;
    emit(
      state.copyWith(
        draft: draft,
        dirty: true,
        errors: _submitted ? draft.validate() : const {},
        saveError: () => null,
      ),
    );
    _schedulePreview();
  }

  /// Seleciona um perfil: os presets explícitos passam a "automático".
  void selectProfile(String? profileId) => update(
    (d) => d.copyWith(
      profileId: () => profileId,
      machinePresetId: () => null,
      energyPresetId: () => null,
      costPresetId: () => null,
    ),
  );

  void addItem() => update(
    (d) => d.copyWith(
      items: [
        ...d.items,
        BudgetItemDraft(key: d.nextItemKey),
      ],
    ),
  );

  void duplicateItem(int key) => update((d) {
    final index = d.items.indexWhere((i) => i.key == key);
    if (index < 0) return d;
    final source = d.items[index];
    final copy = BudgetItemDraft(
      key: d.nextItemKey,
      productName: '${source.productName} (cópia)',
      description: source.description,
      quantity: source.quantity,
      dimensions: source.dimensions,
      printHours: source.printHours,
      printMinutes: source.printMinutes,
      setupMinutes: source.setupMinutes,
      laborMinutes: source.laborMinutes,
      postProcessingMinutes: source.postProcessingMinutes,
      supportRemovalMinutes: source.supportRemovalMinutes,
      notes: source.notes,
      costPresetId: source.costPresetId,
      filaments: source.filaments,
    );
    return d.copyWith(items: [...d.items]..insert(index + 1, copy));
  });

  void removeItem(int key) => update((d) {
    if (d.items.length == 1) return d;
    return d.copyWith(items: d.items.where((i) => i.key != key).toList());
  });

  void updateItem(int key, BudgetItemDraft Function(BudgetItemDraft) change) =>
      update(
        (d) => d.copyWith(
          items: [
            for (final i in d.items)
              if (i.key == key) change(i) else i,
          ],
        ),
      );

  /// Aplica placas do fatiador a um item: soma tempos e agrega gramas por
  /// slot do AMS (mesmo filamento em placas diferentes vira uma linha só).
  void applySlice(
    int itemKey,
    List<SlicePlate> plates, {
    String? productName,
  }) {
    if (plates.isEmpty) return;
    final seconds = plates.fold<int>(0, (s, p) => s + p.printSeconds);
    final bySlot = <int, SliceFilament>{};
    final grams = <int, double>{};
    for (final p in plates) {
      for (final f in p.filaments) {
        bySlot.putIfAbsent(f.slot, () => f);
        grams[f.slot] = (grams[f.slot] ?? 0) + f.grams;
      }
    }
    final slots = bySlot.keys.toList()..sort();
    updateItem(
      itemKey,
      (i) => i.copyWith(
        productName: i.productName.trim().isEmpty ? productName : null,
        printHours: seconds ~/ 3600,
        printMinutes: (seconds % 3600 + 59) ~/ 60 % 60,
        filaments: [
          for (final slot in slots)
            FilamentUsageDraft(
              filamentId: bySlot[slot]!.suggestedFilamentId ?? '',
              grams: double.parse(grams[slot]!.toStringAsFixed(1)),
              label:
                  bySlot[slot]!.suggestedName ??
                  [
                    bySlot[slot]!.material,
                    'slot $slot',
                  ].whereType<String>().join(' · '),
              colorHex: bySlot[slot]!.colorHex,
            ),
        ],
      ),
    );
    AppLogger.info(
      'Fatiamento importado',
      category: 'budgets',
      data: {'plates': plates.length, 'filaments': slots.length},
    );
  }

  void _schedulePreview({bool immediate = false}) {
    _debounce?.cancel();
    if (!state.draft.isPreviewable) {
      emit(state.copyWith(previewing: false, previewError: () => null));
      return;
    }
    emit(state.copyWith(previewing: true));
    _debounce = Timer(
      immediate ? Duration.zero : previewDebounce,
      () => unawaited(_runPreview()),
    );
  }

  Future<void> _runPreview() async {
    final request = ++_previewRequest;
    final draft = state.draft;
    try {
      final preview = await _budgets.preview(draft);
      if (isClosed || request != _previewRequest) return;
      emit(
        state.copyWith(
          preview: () => preview,
          previewing: false,
          previewError: () => null,
        ),
      );
    } on ApiError catch (e) {
      if (isClosed || request != _previewRequest) return;
      emit(state.copyWith(previewing: false, previewError: () => e.message));
    }
  }

  /// Salva (cria ou atualiza). Retorna o orçamento salvo ou `null`.
  Future<Budget?> save() async {
    _submitted = true;
    final errors = state.draft.validate();
    if (errors.isNotEmpty) {
      emit(state.copyWith(errors: errors));
      return null;
    }
    emit(state.copyWith(status: EditorStatus.saving, saveError: () => null));
    try {
      final saved = budgetId == null
          ? await _budgets.create(state.draft)
          : await _budgets.update(budgetId!, state.draft);
      AppLogger.info(
        budgetId == null ? 'Orçamento criado' : 'Orçamento atualizado',
        category: 'budgets',
        data: {'items': state.draft.items.length},
      );
      if (isClosed) return saved;
      emit(
        state.copyWith(status: EditorStatus.saved, saved: saved, dirty: false),
      );
      return saved;
    } on ValidationError catch (e) {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: EditorStatus.ready,
            saveError: () => e.fields.isEmpty
                ? e.message
                : '${e.message}\n${e.fields.values.join('\n')}',
          ),
        );
      }
      return null;
    } on ApiError catch (e) {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: EditorStatus.ready,
            saveError: () => e.message,
          ),
        );
      }
      return null;
    }
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
