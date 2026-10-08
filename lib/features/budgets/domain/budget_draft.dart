import 'package:equatable/equatable.dart';
import 'package:spooliq_desktop/core/network/json.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget.dart';

/// Filamento escolhido para um item. [label]/[colorHex] são só para a UI.
class FilamentUsageDraft extends Equatable {
  const FilamentUsageDraft({
    required this.filamentId,
    required this.grams,
    this.label = '',
    this.colorHex,
  });

  final String filamentId;
  final double grams;
  final String label;
  final String? colorHex;

  FilamentUsageDraft copyWith({
    String? filamentId,
    double? grams,
    String? label,
    String? colorHex,
  }) => FilamentUsageDraft(
    filamentId: filamentId ?? this.filamentId,
    grams: grams ?? this.grams,
    label: label ?? this.label,
    colorHex: colorHex ?? this.colorHex,
  );

  @override
  List<Object?> get props => [filamentId, grams, label, colorHex];
}

/// Item em edição.
class BudgetItemDraft extends Equatable {
  const BudgetItemDraft({
    required this.key,
    this.productName = '',
    this.description = '',
    this.quantity = 1,
    this.dimensions = '',
    this.printHours = 0,
    this.printMinutes = 0,
    this.setupMinutes = 0,
    this.laborMinutes = 0,
    this.postProcessingMinutes = 0,
    this.supportRemovalMinutes = 0,
    this.notes = '',
    this.costPresetId,
    this.model3dId,
    this.model3dName,
    this.filaments = const [],
  });

  factory BudgetItemDraft.fromItem(BudgetItem item, int key) => BudgetItemDraft(
    key: key,
    productName: item.productName,
    description: item.description ?? '',
    quantity: item.quantity,
    dimensions: item.dimensions ?? '',
    printHours: item.printHours,
    printMinutes: item.printMinutes,
    setupMinutes: item.setupMinutes,
    laborMinutes: item.laborMinutes,
    postProcessingMinutes: item.postProcessingMinutes,
    supportRemovalMinutes: item.supportRemovalMinutes,
    notes: item.notes ?? '',
    costPresetId: item.costPresetId,
    model3dId: item.model3dId,
    filaments: [
      for (final f in item.filaments)
        FilamentUsageDraft(
          filamentId: f.filamentId,
          grams: f.grams,
          label: [f.name, f.color].where((s) => s.isNotEmpty).join(' · '),
          colorHex: f.colorHex,
        ),
    ],
  );

  /// Identidade local estável (para `ValueKey` na lista).
  final int key;
  final String productName;
  final String description;
  final int quantity;
  final String dimensions;
  final int printHours;
  final int printMinutes;
  final int setupMinutes;
  final int laborMinutes;
  final int postProcessingMinutes;
  final int supportRemovalMinutes;
  final String notes;
  final String? costPresetId;
  final String? model3dId;
  final String? model3dName;
  final List<FilamentUsageDraft> filaments;

  /// Pronto para o preview (o servidor rejeita itens sem filamento/nome).
  bool get isPreviewable =>
      productName.trim().isNotEmpty &&
      quantity > 0 &&
      filaments.any((f) => f.filamentId.isNotEmpty && f.grams > 0);

  BudgetItemDraft copyWith({
    String? productName,
    String? description,
    int? quantity,
    String? dimensions,
    int? printHours,
    int? printMinutes,
    int? setupMinutes,
    int? laborMinutes,
    int? postProcessingMinutes,
    int? supportRemovalMinutes,
    String? notes,
    String? Function()? costPresetId,
    String? Function()? model3dId,
    String? Function()? model3dName,
    List<FilamentUsageDraft>? filaments,
  }) => BudgetItemDraft(
    key: key,
    productName: productName ?? this.productName,
    description: description ?? this.description,
    quantity: quantity ?? this.quantity,
    dimensions: dimensions ?? this.dimensions,
    printHours: printHours ?? this.printHours,
    printMinutes: printMinutes ?? this.printMinutes,
    setupMinutes: setupMinutes ?? this.setupMinutes,
    laborMinutes: laborMinutes ?? this.laborMinutes,
    postProcessingMinutes: postProcessingMinutes ?? this.postProcessingMinutes,
    supportRemovalMinutes: supportRemovalMinutes ?? this.supportRemovalMinutes,
    notes: notes ?? this.notes,
    costPresetId: costPresetId == null ? this.costPresetId : costPresetId(),
    model3dId: model3dId == null ? this.model3dId : model3dId(),
    model3dName: model3dName == null ? this.model3dName : model3dName(),
    filaments: filaments ?? this.filaments,
  );

  Json toJson(int order) => compactJson({
    'product_name': productName.trim(),
    'product_description': _nullIfBlank(description),
    'product_quantity': quantity,
    'product_dimensions': _nullIfBlank(dimensions),
    'print_time_hours': printHours,
    'print_time_minutes': printMinutes.clamp(0, 59),
    'setup_time_minutes': setupMinutes,
    'manual_labor_minutes_total': laborMinutes,
    'post_processing_minutes': postProcessingMinutes,
    'support_removal_minutes': supportRemovalMinutes,
    'additional_notes': _nullIfBlank(notes),
    'cost_preset_id': costPresetId,
    'model_3d_id': model3dId,
    'order': order,
    'filaments': [
      for (final (i, f)
          in filaments
              .where((f) => f.filamentId.isNotEmpty && f.grams > 0)
              .indexed)
        {'filament_id': f.filamentId, 'quantity': f.grams, 'order': i + 1},
    ],
  });

  @override
  List<Object?> get props => [
    key,
    productName,
    description,
    quantity,
    dimensions,
    printHours,
    printMinutes,
    setupMinutes,
    laborMinutes,
    postProcessingMinutes,
    supportRemovalMinutes,
    notes,
    costPresetId,
    model3dId,
    model3dName,
    filaments,
  ];
}

/// Estado completo do editor de orçamento.
class BudgetDraft extends Equatable {
  const BudgetDraft({
    this.name = '',
    this.description = '',
    this.customerId,
    this.customerName,
    this.profileId,
    this.machinePresetId,
    this.energyPresetId,
    this.costPresetId,
    this.includeEnergyCost = true,
    this.includeWasteCost = true,
    this.includeMachineCost = true,
    this.discountType,
    this.discountValue,
    this.includeShipping = false,
    this.shippingOverrideReais,
    this.taxRate,
    this.deliveryDays,
    this.paymentTerms = '',
    this.notes = '',
    this.validUntil,
    this.items = const [BudgetItemDraft(key: 0)],
  });

  factory BudgetDraft.fromBudget(Budget b) => BudgetDraft(
    name: b.name,
    description: b.description ?? '',
    customerId: b.customerId,
    customerName: b.customer?.name,
    profileId: b.profileId,
    machinePresetId: b.machinePresetId,
    energyPresetId: b.energyPresetId,
    costPresetId: b.costPresetId,
    includeEnergyCost: b.includeEnergyCost,
    includeWasteCost: b.includeWasteCost,
    includeMachineCost: b.includeMachineCost,
    discountType: b.discountType,
    discountValue: b.discountValue,
    includeShipping: b.includeShipping,
    shippingOverrideReais: b.shippingOverrideCents == null
        ? null
        : b.shippingOverrideCents! / 100,
    taxRate: b.taxRate,
    deliveryDays: b.deliveryDays,
    paymentTerms: b.paymentTerms ?? '',
    notes: b.notes ?? '',
    validUntil: b.validUntil,
    items: [
      for (final (i, item) in b.items.indexed)
        BudgetItemDraft.fromItem(item, i),
    ],
  );

  final String name;
  final String description;
  final String? customerId;
  final String? customerName;
  final String? profileId;
  final String? machinePresetId;
  final String? energyPresetId;
  final String? costPresetId;
  final bool includeEnergyCost;
  final bool includeWasteCost;
  final bool includeMachineCost;
  final DiscountType? discountType;

  /// Percentual (0–100) ou reais, conforme [discountType].
  final double? discountValue;
  final bool includeShipping;
  final double? shippingOverrideReais;

  /// `null` = usar alíquota padrão da empresa.
  final double? taxRate;
  final int? deliveryDays;
  final String paymentTerms;
  final String notes;
  final DateTime? validUntil;
  final List<BudgetItemDraft> items;

  int get nextItemKey =>
      items.fold(0, (max, i) => i.key > max ? i.key : max) + 1;

  bool get isPreviewable => items.any((i) => i.isPreviewable);

  /// Erros de validação do formulário (campo → mensagem).
  Map<String, String> validate() => {
    if (name.trim().length < 3)
      'name': 'Informe um nome com pelo menos 3 caracteres.',
    if (customerId == null) 'customer': 'Selecione um cliente.',
    if (discountType == DiscountType.percent && (discountValue ?? 0) > 100)
      'discount': 'O desconto percentual deve ser no máximo 100%.',
    if (taxRate != null && (taxRate! < 0 || taxRate! >= 100))
      'tax': 'A alíquota deve estar entre 0 e 99,99%.',
    for (final (i, item) in items.indexed) ...{
      if (item.productName.trim().isEmpty)
        'item.$i.name': 'Informe o nome do produto.',
      if (item.quantity <= 0) 'item.$i.quantity': 'Quantidade inválida.',
      if (!item.filaments.any((f) => f.filamentId.isNotEmpty && f.grams > 0))
        'item.$i.filaments': 'Adicione ao menos um filamento com quantidade.',
    },
  };

  BudgetDraft copyWith({
    String? name,
    String? description,
    String? Function()? customerId,
    String? Function()? customerName,
    String? Function()? profileId,
    String? Function()? machinePresetId,
    String? Function()? energyPresetId,
    String? Function()? costPresetId,
    bool? includeEnergyCost,
    bool? includeWasteCost,
    bool? includeMachineCost,
    DiscountType? Function()? discountType,
    double? Function()? discountValue,
    bool? includeShipping,
    double? Function()? shippingOverrideReais,
    double? Function()? taxRate,
    int? Function()? deliveryDays,
    String? paymentTerms,
    String? notes,
    DateTime? Function()? validUntil,
    List<BudgetItemDraft>? items,
  }) => BudgetDraft(
    name: name ?? this.name,
    description: description ?? this.description,
    customerId: customerId == null ? this.customerId : customerId(),
    customerName: customerName == null ? this.customerName : customerName(),
    profileId: profileId == null ? this.profileId : profileId(),
    machinePresetId: machinePresetId == null
        ? this.machinePresetId
        : machinePresetId(),
    energyPresetId: energyPresetId == null
        ? this.energyPresetId
        : energyPresetId(),
    costPresetId: costPresetId == null ? this.costPresetId : costPresetId(),
    includeEnergyCost: includeEnergyCost ?? this.includeEnergyCost,
    includeWasteCost: includeWasteCost ?? this.includeWasteCost,
    includeMachineCost: includeMachineCost ?? this.includeMachineCost,
    discountType: discountType == null ? this.discountType : discountType(),
    discountValue: discountValue == null ? this.discountValue : discountValue(),
    includeShipping: includeShipping ?? this.includeShipping,
    shippingOverrideReais: shippingOverrideReais == null
        ? this.shippingOverrideReais
        : shippingOverrideReais(),
    taxRate: taxRate == null ? this.taxRate : taxRate(),
    deliveryDays: deliveryDays == null ? this.deliveryDays : deliveryDays(),
    paymentTerms: paymentTerms ?? this.paymentTerms,
    notes: notes ?? this.notes,
    validUntil: validUntil == null ? this.validUntil : validUntil(),
    items: items ?? this.items,
  );

  int? get _shippingOverrideCents {
    final reais = shippingOverrideReais;
    if (!includeShipping || reais == null || reais <= 0) return null;
    return (reais * 100).round();
  }

  Json _base({required bool forPreview}) {
    final itemsJson = [
      for (final (i, item)
          in items.where((it) => !forPreview || it.isPreviewable).indexed)
        item.toJson(i + 1),
    ];
    return {
      'name': name.trim(),
      'description': _nullIfBlank(description),
      'customer_id': customerId,
      'profile_id': profileId,
      'machine_preset_id': machinePresetId,
      'energy_preset_id': energyPresetId,
      'cost_preset_id': costPresetId,
      'include_energy_cost': includeEnergyCost,
      'include_waste_cost': includeWasteCost,
      'include_machine_cost': includeMachineCost,
      'discount_type': discountType?.value,
      'discount_value': discountType == null ? null : (discountValue ?? 0),
      'include_shipping': includeShipping,
      'shipping_override': _shippingOverrideCents,
      'tax_rate': taxRate,
      'delivery_days': deliveryDays,
      'payment_terms': _nullIfBlank(paymentTerms),
      'notes': _nullIfBlank(notes),
      'items': itemsJson,
    };
  }

  /// `POST /budgets` — opcionais nulos são omitidos.
  Json toCreateJson() => compactJson({
    ..._base(forPreview: false),
    'valid_until': validUntil == null ? null : _endOfDay(validUntil!),
  });

  /// `POST /budgets/preview` — só itens completos; cliente opcional.
  Json toPreviewJson() => compactJson(_base(forPreview: true));

  /// `PUT /budgets/{id}` — os campos "limpáveis" vão explícitos como `null`
  /// (tax_rate → padrão da empresa, desconto, frete manual, validade).
  Json toUpdateJson() {
    final base = compactJson(_base(forPreview: false));
    return {
      ...base,
      'discount_type': discountType?.value,
      'discount_value': discountType == null ? null : (discountValue ?? 0),
      'shipping_override': _shippingOverrideCents,
      'tax_rate': taxRate,
      'valid_until': validUntil == null ? null : _endOfDay(validUntil!),
    };
  }

  @override
  List<Object?> get props => [
    name,
    description,
    customerId,
    customerName,
    profileId,
    machinePresetId,
    energyPresetId,
    costPresetId,
    includeEnergyCost,
    includeWasteCost,
    includeMachineCost,
    discountType,
    discountValue,
    includeShipping,
    shippingOverrideReais,
    taxRate,
    deliveryDays,
    paymentTerms,
    notes,
    validUntil,
    items,
  ];
}

String? _nullIfBlank(String s) => s.trim().isEmpty ? null : s.trim();

/// Fim do dia local em RFC3339 (o backend interpreta em America/Sao_Paulo).
String _endOfDay(DateTime d) =>
    DateTime(d.year, d.month, d.day, 23, 59, 59).toUtc().toIso8601String();
