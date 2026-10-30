import 'package:equatable/equatable.dart';
import 'package:spooliq_desktop/core/network/json.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget.dart';
import 'package:spooliq_desktop/features/budgets/domain/print_batch.dart';

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

/// Insumo escolhido para um item, por peca. [label]/[unit]/[unitCostCents]
/// sao so para a UI (subtotal e rotulo); o envio leva apenas id e quantidade.
class SupplyUsageDraft extends Equatable {
  const SupplyUsageDraft({
    required this.supplyId,
    required this.quantityPerPiece,
    this.label = '',
    this.unit = '',
    this.unitCostCents = 0,
    this.packageSize = 1,
    this.packagePriceCents = 0,
  });

  final String supplyId;
  final double quantityPerPiece;
  final String label;
  final String unit;
  final int unitCostCents;

  /// Conteudo da embalagem, na [unit] (ex.: 400 ml); so para a UI.
  final double packageSize;

  /// Preco da embalagem inteira em centavos; usado no subtotal ao vivo.
  final int packagePriceCents;

  SupplyUsageDraft copyWith({
    String? supplyId,
    double? quantityPerPiece,
    String? label,
    String? unit,
    int? unitCostCents,
    double? packageSize,
    int? packagePriceCents,
  }) => SupplyUsageDraft(
    supplyId: supplyId ?? this.supplyId,
    quantityPerPiece: quantityPerPiece ?? this.quantityPerPiece,
    label: label ?? this.label,
    unit: unit ?? this.unit,
    unitCostCents: unitCostCents ?? this.unitCostCents,
    packageSize: packageSize ?? this.packageSize,
    packagePriceCents: packagePriceCents ?? this.packagePriceCents,
  );

  @override
  List<Object?> get props => [
    supplyId,
    quantityPerPiece,
    label,
    unit,
    unitCostCents,
    packageSize,
    packagePriceCents,
  ];
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
    this.unitsPerPrint,
    this.filaments = const [],
    this.supplies = const [],
  });

  /// Reconstrói o item salvo. Com [BudgetItem.unitsPerPrint], a API guarda
  /// totais; os valores de uma impressão vêm de [BudgetItem.perPrint] (exatos)
  /// ou, em itens sem eles, são recalculados a partir dos totais.
  factory BudgetItemDraft.fromItem(BudgetItem item, int key) {
    final units = item.unitsPerPrint;
    final batch = units == null || units <= 0
        ? null
        : PrintBatch(quantity: item.quantity, unitsPerPrint: units);
    final saved = item.perPrint;
    final exact =
        batch != null &&
        saved != null &&
        saved.filamentGrams.length == item.filaments.length;
    int minutes(int total) => batch?.unscaleMinutes(total) ?? total;
    final printPerRun = exact
        ? saved.printMinutes
        : minutes(item.printHours * 60 + item.printMinutes);
    return BudgetItemDraft(
      key: key,
      productName: item.productName,
      description: item.description ?? '',
      quantity: item.quantity,
      dimensions: item.dimensions ?? '',
      printHours: printPerRun ~/ 60,
      printMinutes: printPerRun % 60,
      setupMinutes: exact
          ? saved.setupMinutes
          : batch?.unscaleSetup(item.setupMinutes) ?? item.setupMinutes,
      laborMinutes: exact ? saved.laborMinutes : minutes(item.laborMinutes),
      postProcessingMinutes: exact
          ? saved.postProcessingMinutes
          : minutes(item.postProcessingMinutes),
      supportRemovalMinutes: exact
          ? saved.supportRemovalMinutes
          : minutes(item.supportRemovalMinutes),
      notes: item.notes ?? '',
      costPresetId: item.costPresetId,
      model3dId: item.model3dId,
      unitsPerPrint: batch == null ? null : units,
      filaments: [
        for (final (i, f) in item.filaments.indexed)
          FilamentUsageDraft(
            filamentId: f.filamentId,
            grams: exact
                ? saved.filamentGrams[i]
                : batch?.unscaleGrams(f.grams) ?? f.grams,
            label: [f.name, f.color].where((s) => s.isNotEmpty).join(' · '),
            colorHex: f.colorHex,
          ),
      ],
      supplies: [
        for (final s in item.supplies)
          SupplyUsageDraft(
            supplyId: s.supplyId,
            quantityPerPiece: s.quantityPerPiece,
            label: s.name,
            unit: s.unit,
            unitCostCents: s.unitCostCents,
            packageSize: s.packageSize,
            packagePriceCents: s.packagePriceCents,
          ),
      ],
    );
  }

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

  /// Peças que uma impressão do arquivo produz. Quando definido, tempo,
  /// gramas e minutos de trabalho deste rascunho são de UMA impressão e são
  /// escalados para [quantity] ao enviar (ver [PrintBatch]).
  final int? unitsPerPrint;
  final List<FilamentUsageDraft> filaments;
  final List<SupplyUsageDraft> supplies;

  /// Lote para a quantidade atual; null no modo "valores totais".
  PrintBatch? get batch => unitsPerPrint == null || unitsPerPrint! <= 0
      ? null
      : PrintBatch(quantity: quantity, unitsPerPrint: unitsPerPrint!);

  /// Sai do modo "peças por impressão" mantendo o mesmo orçamento: os
  /// valores de uma impressão viram os totais escalados da quantidade atual.
  BudgetItemDraft toTotals() {
    final b = batch;
    if (b == null) return copyWith(unitsPerPrint: () => null);
    final printTotal = b.scaleMinutes(printHours * 60 + printMinutes);
    return copyWith(
      unitsPerPrint: () => null,
      printHours: printTotal ~/ 60,
      printMinutes: printTotal % 60,
      setupMinutes: b.scaleSetup(setupMinutes),
      laborMinutes: b.scaleMinutes(laborMinutes),
      postProcessingMinutes: b.scaleMinutes(postProcessingMinutes),
      supportRemovalMinutes: b.scaleMinutes(supportRemovalMinutes),
      filaments: [
        for (final f in filaments) f.copyWith(grams: b.scaleGrams(f.grams)),
      ],
    );
  }

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
    int? Function()? unitsPerPrint,
    List<FilamentUsageDraft>? filaments,
    List<SupplyUsageDraft>? supplies,
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
    unitsPerPrint: unitsPerPrint == null ? this.unitsPerPrint : unitsPerPrint(),
    filaments: filaments ?? this.filaments,
    supplies: supplies ?? this.supplies,
  );

  Json toJson(int order) {
    // Com peças por impressão, envia totais escalados para a quantidade: a API
    // (preço, estoque, dashboard) sempre trabalha com o total do item.
    final b = batch;
    int minutes(int perRun) => b?.scaleMinutes(perRun) ?? perRun;
    final printTotal = minutes(printHours * 60 + printMinutes);
    final sent = filaments
        .where((f) => f.filamentId.isNotEmpty && f.grams > 0)
        .toList();
    return compactJson({
      'product_name': productName.trim(),
      'product_description': _nullIfBlank(description),
      'product_quantity': quantity,
      'units_per_print': b == null ? null : unitsPerPrint,
      // Valores de uma impressão, para reabrir sem desfazer arredondamentos.
      'per_print': b == null
          ? null
          : PerPrintValues(
              printMinutes: printHours * 60 + printMinutes,
              setupMinutes: setupMinutes,
              laborMinutes: laborMinutes,
              postProcessingMinutes: postProcessingMinutes,
              supportRemovalMinutes: supportRemovalMinutes,
              filamentGrams: [for (final f in sent) f.grams],
            ).toJson(),
      'product_dimensions': _nullIfBlank(dimensions),
      'print_time_hours': b == null ? printHours : printTotal ~/ 60,
      'print_time_minutes': b == null
          ? printMinutes.clamp(0, 59)
          : printTotal % 60,
      'setup_time_minutes': b?.scaleSetup(setupMinutes) ?? setupMinutes,
      'manual_labor_minutes_total': minutes(laborMinutes),
      'post_processing_minutes': minutes(postProcessingMinutes),
      'support_removal_minutes': minutes(supportRemovalMinutes),
      'additional_notes': _nullIfBlank(notes),
      'cost_preset_id': costPresetId,
      'model_3d_id': model3dId,
      'order': order,
      'filaments': [
        for (final (i, f) in sent.indexed)
          {
            'filament_id': f.filamentId,
            'quantity': b?.scaleGrams(f.grams) ?? f.grams,
            'order': i + 1,
          },
      ],
      // Insumos sao por peca: NUNCA escalam com PrintBatch. Sempre enviamos a
      // lista (vazia quando nao ha nenhum) para que limpar insumos persista.
      'supplies': [
        for (final s in supplies)
          if (s.supplyId.isNotEmpty && s.quantityPerPiece > 0)
            {
              'supply_id': s.supplyId,
              'quantity_per_piece': s.quantityPerPiece,
            },
      ],
    });
  }

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
    unitsPerPrint,
    filaments,
    supplies,
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
      // Um insumo escolhido sem quantidade seria descartado em silêncio.
      if (item.supplies.any(
        (s) => s.supplyId.isNotEmpty && s.quantityPerPiece <= 0,
      ))
        'item.$i.supplies': 'Informe a quantidade por peça de cada insumo.',
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
