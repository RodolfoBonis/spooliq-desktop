import 'package:equatable/equatable.dart';
import 'package:spooliq_desktop/core/network/json.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget.dart';

enum PresetType {
  machine('machine', 'Máquina', 'Máquinas', '/presets/machines'),
  energy('energy', 'Energia', 'Energia', '/presets/energy'),
  cost('cost', 'Custo', 'Custos', '/presets/costs');

  const PresetType(this.value, this.label, this.plural, this.endpoint);

  final String value;
  final String label;
  final String plural;
  final String endpoint;

  static PresetType fromValue(String? v) =>
      values.firstWhere((t) => t.value == v, orElse: () => machine);
}

enum PresetFieldKind { text, decimal, integer, money, percent }

/// Descreve um campo específico de um tipo de preset.
class PresetField {
  const PresetField(
    this.key,
    this.label, {
    this.kind = PresetFieldKind.decimal,
    this.unit,
    this.required = false,
    this.decimals = 2,
    this.min,
    this.max,
    this.help,
    this.inTable = false,
  });

  final String key;
  final String label;
  final PresetFieldKind kind;
  final String? unit;
  final bool required;
  final int decimals;
  final num? min;
  final num? max;
  final String? help;

  /// Exibido como coluna na listagem.
  final bool inTable;

  bool get isNumeric => kind != PresetFieldKind.text;
}

/// Schema dos campos de cada tipo (valores monetários em REAIS).
abstract final class PresetSchema {
  static List<PresetField> of(PresetType type) => switch (type) {
    PresetType.machine => machine,
    PresetType.energy => energy,
    PresetType.cost => cost,
  };

  static const machine = <PresetField>[
    PresetField('brand', 'Marca', kind: PresetFieldKind.text, inTable: true),
    PresetField('model', 'Modelo', kind: PresetFieldKind.text, inTable: true),
    PresetField(
      'power_consumption',
      'Consumo',
      unit: 'W',
      required: true,
      decimals: 0,
      min: 1,
      inTable: true,
    ),
    PresetField(
      'cost_per_hour',
      'Custo/hora da máquina',
      kind: PresetFieldKind.money,
      help: 'Depreciação + manutenção por hora de impressão.',
      inTable: true,
    ),
    PresetField(
      'build_volume_x',
      'Volume X',
      unit: 'mm',
      required: true,
      decimals: 0,
      min: 1,
    ),
    PresetField(
      'build_volume_y',
      'Volume Y',
      unit: 'mm',
      required: true,
      decimals: 0,
      min: 1,
    ),
    PresetField(
      'build_volume_z',
      'Volume Z',
      unit: 'mm',
      required: true,
      decimals: 0,
      min: 1,
    ),
    PresetField(
      'nozzle_diameter',
      'Bico',
      unit: 'mm',
      required: true,
      min: 0.1,
    ),
    PresetField(
      'filament_diameter',
      'Diâmetro do filamento',
      unit: 'mm',
      required: true,
      min: 1,
    ),
    PresetField(
      'layer_height_min',
      'Camada mín.',
      unit: 'mm',
      required: true,
      min: 0.01,
    ),
    PresetField(
      'layer_height_max',
      'Camada máx.',
      unit: 'mm',
      required: true,
      min: 0.01,
    ),
    PresetField(
      'print_speed_max',
      'Velocidade máx.',
      unit: 'mm/s',
      required: true,
      decimals: 0,
      min: 1,
    ),
    PresetField('bed_temperature_max', 'Mesa máx.', unit: '°C', decimals: 0),
    PresetField(
      'extruder_temperature_max',
      'Extrusora máx.',
      unit: '°C',
      decimals: 0,
    ),
  ];

  static const energy = <PresetField>[
    PresetField(
      'energy_cost_per_kwh',
      'Tarifa',
      kind: PresetFieldKind.money,
      unit: '/kWh',
      required: true,
      decimals: 4,
      min: 0,
      inTable: true,
    ),
    PresetField(
      'currency',
      'Moeda',
      kind: PresetFieldKind.text,
      required: true,
      inTable: true,
    ),
    PresetField(
      'provider',
      'Distribuidora',
      kind: PresetFieldKind.text,
      inTable: true,
    ),
    PresetField('country', 'País', kind: PresetFieldKind.text),
    PresetField('state', 'Estado', kind: PresetFieldKind.text, inTable: true),
    PresetField('city', 'Cidade', kind: PresetFieldKind.text),
    PresetField('tariff_type', 'Tipo de tarifa', kind: PresetFieldKind.text),
    PresetField('peak_hour_multiplier', 'Multiplicador ponta', unit: '×'),
    PresetField(
      'off_peak_hour_multiplier',
      'Multiplicador fora de ponta',
      unit: '×',
    ),
  ];

  static const cost = <PresetField>[
    PresetField(
      'labor_cost_per_hour',
      'Mão de obra/hora',
      kind: PresetFieldKind.money,
      inTable: true,
    ),
    PresetField(
      'overhead_percentage',
      'Overhead',
      kind: PresetFieldKind.percent,
      max: 100,
      inTable: true,
    ),
    PresetField(
      'profit_margin_percentage',
      'Margem de lucro',
      kind: PresetFieldKind.percent,
      max: 1000,
      inTable: true,
    ),
    PresetField(
      'failure_rate_percentage',
      'Taxa de falha',
      kind: PresetFieldKind.percent,
      max: 100,
      help: 'Percentual esperado de peças perdidas.',
    ),
    PresetField(
      'post_processing_cost_per_hour',
      'Pós-processamento/hora',
      kind: PresetFieldKind.money,
    ),
    PresetField(
      'support_removal_cost_per_hour',
      'Remoção de suporte/hora',
      kind: PresetFieldKind.money,
    ),
    PresetField(
      'packaging_cost_per_item',
      'Embalagem/item',
      kind: PresetFieldKind.money,
      inTable: true,
    ),
    PresetField(
      'quality_control_cost_per_item',
      'Controle de qualidade/item',
      kind: PresetFieldKind.money,
    ),
    PresetField(
      'waste_grams_per_color_change',
      'Desperdício por troca de cor',
      unit: 'g',
      decimals: 1,
      help: 'Purga do AMS a cada troca (padrão 15 g).',
    ),
    PresetField(
      'shipping_cost_base',
      'Frete base',
      kind: PresetFieldKind.money,
    ),
    PresetField(
      'shipping_cost_per_gram',
      'Frete por grama',
      kind: PresetFieldKind.money,
      decimals: 4,
    ),
  ];
}

/// Preset (máquina, energia ou custo). [values] guarda os campos do schema.
class Preset extends Equatable {
  const Preset({
    required this.id,
    required this.type,
    required this.name,
    this.description,
    this.isDefault = false,
    this.isActive = true,
    this.values = const {},
  });

  factory Preset.fromJson(Json json, {PresetType? type}) {
    final j = json.unwrapData();
    final t = type ?? PresetType.fromValue(j.strOrNull('type'));
    // Respostas de criação/edição podem vir aninhadas por tipo.
    final nested = j.obj(t.value) ?? const <String, dynamic>{};
    final source = {...j, ...nested};
    return Preset(
      id: j.str('id'),
      type: t,
      name: j.str('name'),
      description: j.strOrNull('description'),
      isDefault: j.boolean('is_default'),
      isActive: j.boolean('is_active', fallback: true),
      values: {
        for (final f in PresetSchema.of(t))
          if (source[f.key] != null) f.key: source[f.key],
      },
    );
  }

  final String id;
  final PresetType type;
  final String name;
  final String? description;
  final bool isDefault;
  final bool isActive;
  final Json values;

  num? number(String key) => switch (values[key]) {
    final num n => n,
    final String s => num.tryParse(s),
    _ => null,
  };

  String? text(String key) => values[key]?.toString();

  NamedRef get ref => NamedRef(id: id, name: name);

  Json toJson() => {
    'name': name.trim(),
    'description': description?.trim() ?? '',
    'is_default': isDefault,
    'is_active': isActive,
    ...values,
  };

  Preset copyWith({
    String? name,
    String? description,
    bool? isDefault,
    bool? isActive,
    Json? values,
  }) => Preset(
    id: id,
    type: type,
    name: name ?? this.name,
    description: description ?? this.description,
    isDefault: isDefault ?? this.isDefault,
    isActive: isActive ?? this.isActive,
    values: values ?? this.values,
  );

  @override
  List<Object?> get props => [
    id,
    type,
    name,
    description,
    isDefault,
    isActive,
    values,
  ];
}

/// Template oferecido pelo backend (`/presets/templates`).
class PresetTemplate extends Equatable {
  const PresetTemplate({
    required this.key,
    required this.name,
    required this.type,
    this.description,
  });

  factory PresetTemplate.fromJson(Json json) => PresetTemplate(
    key: json.str('key'),
    name: json.str('name'),
    description: json.strOrNull('description'),
    type: PresetType.fromValue(json.strOrNull('type')),
  );

  final String key;
  final String name;
  final String? description;
  final PresetType type;

  @override
  List<Object?> get props => [key, name, type];
}

/// Perfil de impressão = máquina + energia (+ custo).
class PrintProfile extends Equatable {
  const PrintProfile({
    required this.id,
    required this.name,
    required this.isDefault,
    this.description,
    this.machinePreset,
    this.energyPreset,
    this.costPreset,
  });

  factory PrintProfile.fromJson(Json json) {
    final j = json.unwrapData();
    return PrintProfile(
      id: j.str('id'),
      name: j.str('name'),
      description: j.strOrNull('description'),
      isDefault: j.boolean('is_default'),
      machinePreset: NamedRef.fromJson(j.obj('machine_preset')),
      energyPreset: NamedRef.fromJson(j.obj('energy_preset')),
      costPreset: NamedRef.fromJson(j.obj('cost_preset')),
    );
  }

  final String id;
  final String name;
  final String? description;
  final bool isDefault;
  final NamedRef? machinePreset;
  final NamedRef? energyPreset;
  final NamedRef? costPreset;

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    isDefault,
    machinePreset,
    energyPreset,
    costPreset,
  ];
}
