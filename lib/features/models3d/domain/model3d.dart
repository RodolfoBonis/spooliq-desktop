import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:spooliq_desktop/core/network/json.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';

class Model3D extends Equatable {
  const Model3D({
    required this.id,
    required this.name,
    required this.fileName,
    required this.format,
    required this.sizeBytes,
    this.description,
    this.customerId,
    this.notes,
    this.tags = const [],
    this.thumbnailUrl,
    this.createdAt,
  });

  /// Referência mínima (id + nome) para abrir o visualizador quando só o
  /// vínculo é conhecido (ex.: item de orçamento).
  factory Model3D.ref(String id, String name) => Model3D(
    id: id,
    name: name,
    fileName: '',
    format: '',
    sizeBytes: 0,
  );

  factory Model3D.fromJson(Json json) {
    final j = json.unwrapData();
    return Model3D(
      id: j.str('id'),
      name: j.str('name'),
      fileName: j.str('file_name'),
      format: j.str('file_format').replaceAll('.', '').toUpperCase(),
      sizeBytes: j.integer('file_size_bytes'),
      description: j.strOrNull('description'),
      customerId: j.strOrNull('customer_id'),
      notes: j.strOrNull('notes'),
      tags: j['tags'] is List
          ? j.strings('tags')
          : (j
                    .strOrNull('tags')
                    ?.split(',')
                    .map((t) => t.trim())
                    .where((t) => t.isNotEmpty)
                    .toList() ??
                const []),
      thumbnailUrl: j.strOrNull('thumbnail_url'),
      createdAt: j.date('created_at'),
    );
  }

  final String id;
  final String name;
  final String fileName;
  final String format;
  final int sizeBytes;
  final String? description;
  final String? customerId;
  final String? notes;
  final List<String> tags;
  final String? thumbnailUrl;
  final DateTime? createdAt;

  String get sizeLabel {
    if (sizeBytes >= 1 << 20) {
      return '${(sizeBytes / (1 << 20)).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
  }

  @override
  List<Object?> get props => [
    id,
    name,
    fileName,
    sizeBytes,
    description,
    customerId,
    notes,
    tags,
  ];
}

/// Filamento detectado pelo fatiador num slot do AMS.
class SliceFilament extends Equatable {
  const SliceFilament({
    required this.slot,
    required this.grams,
    this.colorHex,
    this.material,
    this.suggestedFilamentId,
    this.suggestedName,
  });

  factory SliceFilament.fromJson(Json j) {
    final s = j.obj('suggestion');
    return SliceFilament(
      slot: j.integer('slot'),
      grams: j.dbl('grams'),
      colorHex: j.strOrNull('color_hex'),
      material: j.strOrNull('material'),
      suggestedFilamentId: s?.strOrNull('filament_id'),
      suggestedName: s?.strOrNull('name'),
    );
  }

  final int slot;
  final double grams;
  final String? colorHex;
  final String? material;

  /// Filamento do catálogo mais parecido (cor/material), se houver.
  final String? suggestedFilamentId;
  final String? suggestedName;

  @override
  List<Object?> get props => [slot, grams, colorHex, suggestedFilamentId];
}

class SlicePlate extends Equatable {
  const SlicePlate({
    required this.index,
    required this.name,
    required this.printSeconds,
    required this.estimated,
    required this.filaments,
  });

  factory SlicePlate.fromJson(Json j) => SlicePlate(
    index: j.integer('index'),
    name: j.str('name'),
    printSeconds: j.integer('print_time_seconds'),
    estimated: j.boolean('estimated'),
    filaments: j.list('filaments', SliceFilament.fromJson),
  );

  final int index;
  final String name;
  final int printSeconds;
  final bool estimated;
  final List<SliceFilament> filaments;

  int get hours => printSeconds ~/ 3600;
  int get minutes => (printSeconds % 3600) ~/ 60;

  @override
  List<Object?> get props => [index, printSeconds, filaments];
}

/// Resultado de `POST /slicer/analyze` ou `GET /models3d/{id}/slice-analysis`.
class SliceAnalysis extends Equatable {
  const SliceAnalysis({
    required this.plates,
    this.slicer,
    this.warnings = const [],
  });

  factory SliceAnalysis.fromJson(Json json) {
    final j = json.obj('slice_analysis') ?? json.unwrapData();
    final s = j.obj('slicer');
    return SliceAnalysis(
      slicer: s == null
          ? null
          : [
              s.str('name'),
              s.str('version'),
            ].where((x) => x.isNotEmpty).join(' '),
      plates: j.list('plates', SlicePlate.fromJson),
      warnings: j.strings('warnings'),
    );
  }

  final String? slicer;
  final List<SlicePlate> plates;
  final List<String> warnings;

  @override
  List<Object?> get props => [slicer, plates, warnings];
}

abstract interface class Model3DRepository {
  /// [format] é a extensão sem ponto (`stl`, `3mf`).
  Future<Paginated<Model3D>> list({
    PageQuery page = const PageQuery(),
    String? customerId,
    String? format,
  });
  Future<Model3D> upload({
    required String filePath,
    required String name,
    String? description,
    String? customerId,
    String? notes,
    String? tags,
    void Function(int sent, int total)? onProgress,
  });

  /// Substitui todos os metadados: texto vazio limpa o campo e
  /// `customerId` nulo desvincula o cliente.
  Future<Model3D> update(
    String id, {
    required String name,
    required String? customerId,
    required String description,
    required String notes,
    required String tags,
  });
  Future<void> delete(String id);
  Future<Uint8List> download(String id);
  Future<SliceAnalysis> sliceAnalysis(String id);

  /// Analisa um arquivo do fatiador (.3mf / .gcode) sem salvá-lo.
  Future<SliceAnalysis> analyzeFile(
    String filePath, {
    void Function(int sent, int total)? onProgress,
  });
}
