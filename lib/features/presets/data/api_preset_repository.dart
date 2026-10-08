import 'package:spooliq_desktop/core/network/api_client.dart';
import 'package:spooliq_desktop/core/network/json.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/features/presets/domain/preset.dart';
import 'package:spooliq_desktop/features/presets/domain/preset_repository.dart';

class ApiPresetRepository implements PresetRepository {
  const ApiPresetRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Preset>> list(PresetType type) async {
    final body = await _api.get(type.endpoint, query: {'page_size': 100});
    return Paginated.fromJson(
      body,
      (j) => Preset.fromJson(j, type: type),
    ).items;
  }

  @override
  Future<Preset> save(Preset preset, {bool create = false}) async {
    final json = create
        ? await _api.postJson(preset.type.endpoint, body: preset.toJson())
        : await _api.putJson(
            '${preset.type.endpoint}/${preset.id}',
            body: preset.toJson(),
          );
    final saved = Preset.fromJson(json, type: preset.type);
    // Create/update devolvem o PresetEntity genérico (sem os campos do tipo).
    return saved.values.isEmpty ? saved.copyWith(values: preset.values) : saved;
  }

  @override
  Future<void> delete(String id) => _api.delete('/presets/$id');

  @override
  Future<void> setDefault(String id) => _api.post('/presets/$id/default');

  @override
  Future<Preset> duplicate(String id, PresetType type) async => Preset.fromJson(
    await _api.postJson('/presets/$id/duplicate'),
    type: type,
  );

  @override
  Future<List<PresetTemplate>> templates(PresetType type) async {
    final body = await _api.get(
      '/presets/templates',
      query: {'type': type.value},
    );
    final raw = body is Map
        ? (body['data'] ?? body['templates'] ?? body)
        : body;
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map) PresetTemplate.fromJson(Map<String, dynamic>.from(e)),
    ];
  }

  @override
  Future<Preset> fromTemplate(
    String key,
    PresetType type, {
    String? name,
  }) async => Preset.fromJson(
    await _api.postJson(
      '/presets/from-template/$key',
      body: compactJson({'name': name}),
    ),
    type: type,
  );

  @override
  Future<Paginated<PrintProfile>> profiles() async => Paginated.fromJson(
    await _api.get('/profiles', query: {'page_size': 100}),
    PrintProfile.fromJson,
  );

  @override
  Future<PrintProfile> saveProfile({
    required String name,
    required String machinePresetId,
    required String energyPresetId,
    String? id,
    String? costPresetId,
    String? description,
    bool isDefault = false,
  }) async {
    final body = compactJson({
      'name': name.trim(),
      'description': description?.trim(),
      'machine_preset_id': machinePresetId,
      'energy_preset_id': energyPresetId,
      'cost_preset_id': costPresetId,
      'is_default': isDefault,
    });
    final json = id == null
        ? await _api.postJson('/profiles', body: body)
        : await _api.putJson('/profiles/$id', body: body);
    return PrintProfile.fromJson(json);
  }

  @override
  Future<void> deleteProfile(String id) => _api.delete('/profiles/$id');

  @override
  Future<void> setDefaultProfile(String id) =>
      _api.post('/profiles/$id/default');

  @override
  Future<PrintProfile> duplicateProfile(String id) async =>
      PrintProfile.fromJson(await _api.postJson('/profiles/$id/duplicate'));
}
