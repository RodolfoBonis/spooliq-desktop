import 'package:equatable/equatable.dart';
import 'package:spooliq_desktop/core/network/json.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_status.dart';

/// `{id, name}` de preset/perfil.
class NamedRef extends Equatable {
  const NamedRef({required this.id, required this.name});

  static NamedRef? fromJson(Json? json) {
    if (json == null) return null;
    final id = json.str('id');
    if (id.isEmpty) return null;
    return NamedRef(id: id, name: json.str('name'));
  }

  final String id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}

/// Cliente resumido embutido no orçamento.
class BudgetCustomer extends Equatable {
  const BudgetCustomer({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.document,
  });

  static BudgetCustomer? fromJson(Json? json) {
    if (json == null) return null;
    return BudgetCustomer(
      id: json.str('id'),
      name: json.str('name'),
      email: json.strOrNull('email'),
      phone: json.strOrNull('phone'),
      document: json.strOrNull('document'),
    );
  }

  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? document;

  @override
  List<Object?> get props => [id, name, email, phone, document];
}

/// Filamento usado por um item (ordem = sequência no AMS).
class BudgetItemFilament extends Equatable {
  const BudgetItemFilament({
    required this.filamentId,
    required this.name,
    required this.brandName,
    required this.materialName,
    required this.color,
    required this.colorHex,
    required this.colorType,
    required this.colorData,
    required this.grams,
    required this.costCents,
    required this.order,
  });

  factory BudgetItemFilament.fromJson(Json json) => BudgetItemFilament(
    filamentId: json.str('filament_id'),
    name: json.str('filament_name'),
    brandName: json.str('brand_name'),
    materialName: json.str('material_name'),
    color: json.str('color'),
    colorHex: json.strOrNull('color_hex'),
    colorType: json.str('color_type', 'solid'),
    colorData: json.obj('color_data'),
    grams: json.dbl('quantity'),
    costCents: json.integer('cost'),
    order: json.integer('order', 1),
  );

  final String filamentId;
  final String name;
  final String brandName;
  final String materialName;
  final String color;
  final String? colorHex;
  final String colorType;
  final Json? colorData;
  final double grams;
  final int costCents;
  final int order;

  @override
  List<Object?> get props => [filamentId, grams, costCents, order];
}

/// Item (produto) do orçamento, com custos calculados pelo servidor (centavos).
class BudgetItem extends Equatable {
  const BudgetItem({
    required this.id,
    required this.productName,
    required this.quantity,
    required this.printHours,
    required this.printMinutes,
    required this.printTimeDisplay,
    required this.setupMinutes,
    required this.laborMinutes,
    required this.postProcessingMinutes,
    required this.supportRemovalMinutes,
    required this.costs,
    required this.totalCostCents,
    required this.unitCostCents,
    required this.saleUnitPriceCents,
    required this.saleTotalCents,
    required this.filaments,
    required this.order,
    this.description,
    this.dimensions,
    this.costPresetId,
    this.costPreset,
    this.notes,
    this.model3dId,
  });

  factory BudgetItem.fromJson(Json json) => BudgetItem(
    id: json.str('id'),
    productName: json.str('product_name'),
    description: json.strOrNull('product_description'),
    quantity: json.integer('product_quantity', 1),
    dimensions: json.strOrNull('product_dimensions'),
    printHours: json.integer('print_time_hours'),
    printMinutes: json.integer('print_time_minutes'),
    printTimeDisplay: json.str('print_time_display'),
    setupMinutes: json.integer('setup_time_minutes'),
    laborMinutes: json.integer('manual_labor_minutes_total'),
    postProcessingMinutes: json.integer('post_processing_minutes'),
    supportRemovalMinutes: json.integer('support_removal_minutes'),
    costPresetId: json.strOrNull('cost_preset_id'),
    costPreset: NamedRef.fromJson(json.obj('cost_preset')),
    notes: json.strOrNull('additional_notes'),
    model3dId: json.strOrNull('model_3d_id'),
    costs: CostLines.fromItemJson(json),
    totalCostCents: json.integer('item_total_cost'),
    unitCostCents: json.integer('unit_price'),
    saleUnitPriceCents: json.integer('sale_unit_price'),
    saleTotalCents: json.integer('sale_total'),
    filaments: json.list('filaments', BudgetItemFilament.fromJson)
      ..sort((a, b) => a.order.compareTo(b.order)),
    order: json.integer('order'),
  );

  final String id;
  final String productName;
  final String? description;
  final int quantity;
  final String? dimensions;
  final int printHours;
  final int printMinutes;
  final String printTimeDisplay;
  final int setupMinutes;
  final int laborMinutes;
  final int postProcessingMinutes;
  final int supportRemovalMinutes;
  final String? costPresetId;
  final NamedRef? costPreset;
  final String? notes;
  final String? model3dId;
  final CostLines costs;
  final int totalCostCents;
  final int unitCostCents;
  final int saleUnitPriceCents;
  final int saleTotalCents;
  final List<BudgetItemFilament> filaments;
  final int order;

  double get totalGrams => filaments.fold(0, (sum, f) => sum + f.grams);

  @override
  List<Object?> get props => [
    id,
    productName,
    quantity,
    totalCostCents,
    saleTotalCents,
    filaments,
  ];
}

/// Linhas de custo (centavos), compartilhadas entre item e orçamento.
class CostLines extends Equatable {
  const CostLines({
    this.filament = 0,
    this.waste = 0,
    this.energy = 0,
    this.machine = 0,
    this.setup = 0,
    this.labor = 0,
    this.postProcessing = 0,
    this.supportRemoval = 0,
    this.packaging = 0,
    this.qualityControl = 0,
    this.failure = 0,
  });

  factory CostLines.fromItemJson(Json json) => CostLines(
    filament: json.integer('filament_cost'),
    waste: json.integer('waste_cost'),
    energy: json.integer('energy_cost'),
    machine: json.integer('machine_cost'),
    setup: json.integer('setup_cost'),
    labor: json.integer('manual_labor_cost'),
    postProcessing: json.integer('post_processing_cost'),
    supportRemoval: json.integer('support_removal_cost'),
    packaging: json.integer('packaging_cost'),
    qualityControl: json.integer('quality_control_cost'),
    failure: json.integer('failure_cost'),
  );

  factory CostLines.fromBudgetJson(Json json) => CostLines(
    filament: json.integer('filament_cost'),
    waste: json.integer('waste_cost'),
    energy: json.integer('energy_cost'),
    machine: json.integer('machine_cost'),
    setup: json.integer('setup_cost'),
    labor: json.integer('labor_cost'),
    postProcessing: json.integer('post_processing_cost'),
    packaging: json.integer('packaging_cost'),
    qualityControl: json.integer('quality_control_cost'),
    failure: json.integer('failure_cost'),
  );

  final int filament;
  final int waste;
  final int energy;
  final int machine;
  final int setup;
  final int labor;
  final int postProcessing;
  final int supportRemoval;
  final int packaging;
  final int qualityControl;
  final int failure;

  int get direct =>
      filament +
      waste +
      energy +
      machine +
      setup +
      labor +
      postProcessing +
      supportRemoval +
      packaging +
      qualityControl +
      failure;

  @override
  List<Object?> get props => [
    filament,
    waste,
    energy,
    machine,
    setup,
    labor,
    postProcessing,
    supportRemoval,
    packaging,
    qualityControl,
    failure,
  ];
}

/// Aviso de estoque insuficiente (informativo).
class StockWarning extends Equatable {
  const StockWarning({
    required this.filamentId,
    required this.filamentName,
    required this.color,
    required this.requiredGrams,
    required this.availableGrams,
  });

  factory StockWarning.fromJson(Json json) => StockWarning(
    filamentId: json.str('filament_id'),
    filamentName: json.str('filament_name'),
    color: json.str('color'),
    requiredGrams: json.integer('required_grams'),
    availableGrams: json.integer('available_grams'),
  );

  final String filamentId;
  final String filamentName;
  final String color;
  final int requiredGrams;
  final int availableGrams;

  @override
  List<Object?> get props => [filamentId, requiredGrams, availableGrams];
}

/// Entrada do histórico de status.
class StatusChange extends Equatable {
  const StatusChange({
    required this.id,
    required this.from,
    required this.to,
    required this.changedBy,
    required this.at,
    this.notes,
  });

  factory StatusChange.fromJson(Json json) => StatusChange(
    id: json.str('id'),
    from: json.strOrNull('previous_status') == null
        ? null
        : BudgetStatus.fromValue(json.str('previous_status')),
    to: BudgetStatus.fromValue(json.str('new_status')),
    changedBy: json.str('changed_by'),
    notes: json.strOrNull('notes'),
    at: json.date('created_at'),
  );

  final String id;
  final BudgetStatus? from;
  final BudgetStatus to;
  final String changedBy;
  final String? notes;
  final DateTime? at;

  @override
  List<Object?> get props => [id, from, to, at];
}

enum DiscountType {
  percent('percent'),
  fixed('fixed');

  const DiscountType(this.value);

  final String value;

  static DiscountType? fromValue(String? v) => switch (v) {
    'percent' => percent,
    'fixed' => fixed,
    _ => null,
  };
}

/// Orçamento completo (`BudgetResponse`). Também é o retorno de `/preview`.
class Budget extends Equatable {
  const Budget({
    required this.id,
    required this.name,
    required this.status,
    required this.customerId,
    required this.costs,
    required this.overheadCents,
    required this.profitCents,
    required this.basePriceCents,
    required this.discountCents,
    required this.shippingCents,
    required this.taxCents,
    required this.taxRateApplied,
    required this.totalCents,
    required this.includeEnergyCost,
    required this.includeWasteCost,
    required this.includeMachineCost,
    required this.includeShipping,
    required this.items,
    required this.stockWarnings,
    required this.statusHistory,
    required this.totalPrintTimeDisplay,
    this.description,
    this.quoteNumber,
    this.customer,
    this.validUntil,
    this.publicToken,
    this.customerResponseAt,
    this.customerResponseName,
    this.rejectionReason,
    this.profileId,
    this.machinePresetId,
    this.energyPresetId,
    this.costPresetId,
    this.profile,
    this.machinePreset,
    this.energyPreset,
    this.costPreset,
    this.discountType,
    this.discountValue,
    this.shippingOverrideCents,
    this.taxRate,
    this.deliveryDays,
    this.paymentTerms,
    this.notes,
    this.pdfUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory Budget.fromJson(Json json) => Budget(
    id: json.str('id'),
    name: json.str('name'),
    description: json.strOrNull('description'),
    status: BudgetStatus.fromValue(json.strOrNull('status')),
    quoteNumber: json.intOrNull('quote_number'),
    customerId: json.str('customer_id'),
    customer: BudgetCustomer.fromJson(json.obj('customer')),
    validUntil: json.date('valid_until'),
    publicToken: json.strOrNull('public_token'),
    customerResponseAt: json.date('customer_response_at'),
    customerResponseName: json.strOrNull('customer_response_name'),
    rejectionReason: json.strOrNull('rejection_reason'),
    profileId: json.strOrNull('profile_id'),
    machinePresetId: json.strOrNull('machine_preset_id'),
    energyPresetId: json.strOrNull('energy_preset_id'),
    costPresetId: json.strOrNull('cost_preset_id'),
    profile: NamedRef.fromJson(json.obj('profile')),
    machinePreset: NamedRef.fromJson(json.obj('machine_preset')),
    energyPreset: NamedRef.fromJson(json.obj('energy_preset')),
    costPreset: NamedRef.fromJson(json.obj('cost_preset')),
    includeEnergyCost: json.boolean('include_energy_cost'),
    includeWasteCost: json.boolean('include_waste_cost'),
    includeMachineCost: json.boolean('include_machine_cost', fallback: true),
    includeShipping: json.boolean('include_shipping'),
    discountType: DiscountType.fromValue(json.strOrNull('discount_type')),
    discountValue: json.dblOrNull('discount_value'),
    shippingOverrideCents: json.intOrNull('shipping_override'),
    taxRate: json.dblOrNull('tax_rate'),
    costs: CostLines.fromBudgetJson(json),
    overheadCents: json.integer('overhead_cost'),
    profitCents: json.integer('profit_amount'),
    basePriceCents: json.integer('base_price'),
    discountCents: json.integer('discount_amount'),
    shippingCents: json.integer('shipping_cost'),
    taxCents: json.integer('tax_amount'),
    taxRateApplied: json.dbl('tax_rate_applied'),
    totalCents: json.integer('total_cost'),
    deliveryDays: json.intOrNull('delivery_days'),
    paymentTerms: json.strOrNull('payment_terms'),
    notes: json.strOrNull('notes'),
    pdfUrl: json.strOrNull('pdf_url'),
    items: json.list('items', BudgetItem.fromJson)
      ..sort((a, b) => a.order.compareTo(b.order)),
    stockWarnings: json.list('stock_warnings', StockWarning.fromJson),
    statusHistory: json.list('status_history', StatusChange.fromJson),
    totalPrintTimeDisplay: json.str('total_print_time_display'),
    createdAt: json.date('created_at'),
    updatedAt: json.date('updated_at'),
  );

  final String id;
  final String name;
  final String? description;
  final BudgetStatus status;
  final int? quoteNumber;
  final String customerId;
  final BudgetCustomer? customer;
  final DateTime? validUntil;
  final String? publicToken;
  final DateTime? customerResponseAt;
  final String? customerResponseName;
  final String? rejectionReason;
  final String? profileId;
  final String? machinePresetId;
  final String? energyPresetId;
  final String? costPresetId;
  final NamedRef? profile;
  final NamedRef? machinePreset;
  final NamedRef? energyPreset;
  final NamedRef? costPreset;
  final bool includeEnergyCost;
  final bool includeWasteCost;
  final bool includeMachineCost;
  final bool includeShipping;
  final DiscountType? discountType;
  final double? discountValue;
  final int? shippingOverrideCents;
  final double? taxRate;
  final CostLines costs;
  final int overheadCents;
  final int profitCents;
  final int basePriceCents;
  final int discountCents;
  final int shippingCents;
  final int taxCents;
  final double taxRateApplied;
  final int totalCents;
  final int? deliveryDays;
  final String? paymentTerms;
  final String? notes;
  final String? pdfUrl;
  final List<BudgetItem> items;
  final List<StockWarning> stockWarnings;
  final List<StatusChange> statusHistory;
  final String totalPrintTimeDisplay;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get customerName => customer?.name ?? '';

  bool get isShared => publicToken != null;

  bool get isExpiringSoon {
    final v = validUntil;
    if (v == null || status != BudgetStatus.sent) return false;
    return v.difference(DateTime.now()).inDays <= 2;
  }

  int get itemCount => items.length;

  /// Cópia com outro status — usada no update otimista do kanban.
  Budget copyWithStatus(BudgetStatus status) {
    final b = this;
    return Budget(
      id: b.id,
      name: b.name,
      description: b.description,
      status: status,
      quoteNumber: b.quoteNumber,
      customerId: b.customerId,
      customer: b.customer,
      validUntil: b.validUntil,
      publicToken: b.publicToken,
      customerResponseAt: b.customerResponseAt,
      customerResponseName: b.customerResponseName,
      rejectionReason: b.rejectionReason,
      profileId: b.profileId,
      machinePresetId: b.machinePresetId,
      energyPresetId: b.energyPresetId,
      costPresetId: b.costPresetId,
      profile: b.profile,
      machinePreset: b.machinePreset,
      energyPreset: b.energyPreset,
      costPreset: b.costPreset,
      includeEnergyCost: b.includeEnergyCost,
      includeWasteCost: b.includeWasteCost,
      includeMachineCost: b.includeMachineCost,
      includeShipping: b.includeShipping,
      discountType: b.discountType,
      discountValue: b.discountValue,
      shippingOverrideCents: b.shippingOverrideCents,
      taxRate: b.taxRate,
      costs: b.costs,
      overheadCents: b.overheadCents,
      profitCents: b.profitCents,
      basePriceCents: b.basePriceCents,
      discountCents: b.discountCents,
      shippingCents: b.shippingCents,
      taxCents: b.taxCents,
      taxRateApplied: b.taxRateApplied,
      totalCents: b.totalCents,
      deliveryDays: b.deliveryDays,
      paymentTerms: b.paymentTerms,
      notes: b.notes,
      pdfUrl: b.pdfUrl,
      items: b.items,
      stockWarnings: b.stockWarnings,
      statusHistory: b.statusHistory,
      totalPrintTimeDisplay: b.totalPrintTimeDisplay,
      createdAt: b.createdAt,
      updatedAt: b.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    status,
    name,
    totalCents,
    updatedAt,
    items,
    publicToken,
  ];
}
