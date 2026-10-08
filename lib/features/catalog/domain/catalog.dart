import 'package:equatable/equatable.dart';
import 'package:spooliq_desktop/core/network/json.dart';

class Brand extends Equatable {
  const Brand({
    required this.id,
    required this.name,
    this.description,
    this.createdAt,
  });

  factory Brand.fromJson(Json json) {
    final j = json.unwrapData();
    return Brand(
      id: j.str('id'),
      name: j.str('name'),
      description: j.strOrNull('description'),
      createdAt: j.date('created_at'),
    );
  }

  final String id;
  final String name;
  final String? description;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [id, name, description];
}

class Material extends Equatable {
  const Material({
    required this.id,
    required this.name,
    this.description,
    this.tempTable,
    this.tempExtruder,
    this.createdAt,
  });

  factory Material.fromJson(Json json) {
    final j = json.unwrapData();
    return Material(
      id: j.str('id'),
      name: j.str('name'),
      description: j.strOrNull('description'),
      tempTable: j.intOrNull('temp_table'),
      tempExtruder: j.intOrNull('temp_extruder'),
      createdAt: j.date('created_at'),
    );
  }

  final String id;
  final String name;
  final String? description;
  final int? tempTable;
  final int? tempExtruder;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [id, name, description, tempTable, tempExtruder];
}

/// Tipos de cor suportados pelo backend (`color_entity.go`).
enum ColorType {
  solid('solid', 'Sólida'),
  gradient('gradient', 'Gradiente'),
  duo('duo', 'Duo'),
  rainbow('rainbow', 'Arco-íris'),
  metallic('metallic', 'Metálica'),
  transparent('transparent', 'Translúcida'),
  woodFill('wood-fill', 'Madeira'),
  carbonFiber('carbon-fiber', 'Fibra de carbono');

  const ColorType(this.value, this.label);

  final String value;
  final String label;

  static ColorType fromValue(String? v) =>
      values.firstWhere((t) => t.value == v, orElse: () => solid);
}

class Filament extends Equatable {
  const Filament({
    required this.id,
    required this.name,
    required this.brandId,
    required this.materialId,
    required this.color,
    required this.colorType,
    required this.diameter,
    required this.pricePerKgCents,
    this.brandName = '',
    this.materialName = '',
    this.colorHex,
    this.colorData,
    this.description,
    this.weight,
    this.url,
    this.printTemperature,
    this.bedTemperature,
    this.isActive = true,
    this.trackStock = false,
    this.stockGrams = 0,
    this.lowStockThresholdGrams,
    this.isLowStock = false,
    this.createdAt,
  });

  factory Filament.fromJson(Json json) {
    final j = json.unwrapData();
    return Filament(
      id: j.str('id'),
      name: j.str('name'),
      description: j.strOrNull('description'),
      brandId: j.str('brand_id'),
      brandName: j.obj('brand')?.str('name') ?? j.str('brand_name'),
      materialId: j.str('material_id'),
      materialName: j.obj('material')?.str('name') ?? j.str('material_name'),
      color: j.str('color'),
      colorHex: j.strOrNull('color_hex'),
      colorType: ColorType.fromValue(j.strOrNull('color_type')),
      colorData: j.obj('color_data'),
      diameter: j.dbl('diameter', 1.75),
      weight: j.dblOrNull('weight'),
      pricePerKgCents: j.integer('price_per_kg'),
      url: j.strOrNull('url'),
      printTemperature: j.intOrNull('print_temperature'),
      bedTemperature: j.intOrNull('bed_temperature'),
      isActive: j.boolean('is_active', fallback: true),
      trackStock: j.boolean('track_stock'),
      stockGrams: j.dbl('stock_grams'),
      lowStockThresholdGrams: j.dblOrNull('low_stock_threshold_grams'),
      isLowStock: j.boolean('is_low_stock'),
      createdAt: j.date('created_at'),
    );
  }

  final String id;
  final String name;
  final String? description;
  final String brandId;
  final String brandName;
  final String materialId;
  final String materialName;
  final String color;
  final String? colorHex;
  final ColorType colorType;
  final Json? colorData;
  final double diameter;
  final double? weight;

  /// Preço por kg em centavos (a web grava `reais * 100`).
  final int pricePerKgCents;
  final String? url;
  final int? printTemperature;
  final int? bedTemperature;
  final bool isActive;
  final bool trackStock;
  final double stockGrams;
  final double? lowStockThresholdGrams;
  final bool isLowStock;
  final DateTime? createdAt;

  /// "Bambu PLA Basic · Vermelho".
  String get displayName =>
      [name, color].where((s) => s.isNotEmpty).join(' · ');

  String get subtitle => [
    brandName,
    materialName,
    '${diameter}mm',
  ].where((s) => s.isNotEmpty).join(' · ');

  @override
  List<Object?> get props => [
    id,
    name,
    color,
    colorHex,
    colorType,
    pricePerKgCents,
    isActive,
    trackStock,
    stockGrams,
    lowStockThresholdGrams,
    isLowStock,
  ];
}

class FilamentInput extends Equatable {
  const FilamentInput({
    required this.name,
    required this.brandId,
    required this.materialId,
    required this.color,
    required this.colorType,
    required this.diameter,
    required this.pricePerKgCents,
    this.colorHex,
    this.colorData,
    this.description,
    this.weight,
    this.url,
    this.printTemperature,
    this.bedTemperature,
    this.isActive,
    this.trackStock,
    this.lowStockThresholdGrams,
  });

  final String name;
  final String brandId;
  final String materialId;
  final String color;
  final ColorType colorType;
  final String? colorHex;
  final Json? colorData;
  final double diameter;
  final int pricePerKgCents;
  final String? description;
  final double? weight;
  final String? url;
  final int? printTemperature;
  final int? bedTemperature;
  final bool? isActive;
  final bool? trackStock;
  final double? lowStockThresholdGrams;

  Json toJson() => compactJson({
    'name': name.trim(),
    'brand_id': brandId,
    'material_id': materialId,
    'color': color.trim(),
    'color_type': colorType.value,
    'color_hex': colorHex,
    'color_data': colorData ?? (colorHex == null ? null : {'color': colorHex}),
    'diameter': diameter,
    'price_per_kg': pricePerKgCents,
    'description': description,
    'weight': weight,
    'url': url,
    'print_temperature': printTemperature,
    'bed_temperature': bedTemperature,
    'is_active': isActive,
    'track_stock': trackStock,
    'low_stock_threshold_grams': lowStockThresholdGrams,
  });

  @override
  List<Object?> get props => [
    name,
    brandId,
    materialId,
    color,
    pricePerKgCents,
  ];
}

enum StockMovementType {
  purchase('purchase', 'Compra'),
  adjustment('adjustment', 'Ajuste'),
  waste('waste', 'Perda'),
  consumption('consumption', 'Consumo');

  const StockMovementType(this.value, this.label);

  final String value;
  final String label;

  static StockMovementType fromValue(String? v) =>
      values.firstWhere((t) => t.value == v, orElse: () => adjustment);
}

class StockMovement extends Equatable {
  const StockMovement({
    required this.id,
    required this.type,
    required this.grams,
    this.unitPricePerKgCents,
    this.budgetId,
    this.budgetQuoteNumber,
    this.note,
    this.createdAt,
  });

  factory StockMovement.fromJson(Json json) => StockMovement(
    id: json.str('id'),
    type: StockMovementType.fromValue(json.strOrNull('type')),
    grams: json.dbl('grams'),
    unitPricePerKgCents: json.intOrNull('unit_price_per_kg'),
    budgetId: json.strOrNull('budget_id'),
    budgetQuoteNumber: json.intOrNull('budget_quote_number'),
    note: json.strOrNull('note'),
    createdAt: json.date('created_at'),
  );

  final String id;
  final StockMovementType type;

  /// Com sinal: compra +, perda/consumo −, ajuste ±.
  final double grams;
  final int? unitPricePerKgCents;
  final String? budgetId;
  final int? budgetQuoteNumber;
  final String? note;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [id, type, grams, createdAt];
}

/// Filtros da listagem de filamentos.
class FilamentFilter extends Equatable {
  const FilamentFilter({this.brandId, this.materialId, this.lowStock = false});

  final String? brandId;
  final String? materialId;
  final bool lowStock;

  Map<String, dynamic> toQuery() => {
    'brand_id': brandId,
    'material_id': materialId,
    if (lowStock) 'low_stock': true,
  };

  @override
  List<Object?> get props => [brandId, materialId, lowStock];
}
