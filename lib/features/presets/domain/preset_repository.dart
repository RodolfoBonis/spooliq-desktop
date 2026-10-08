import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/features/presets/domain/preset.dart';

abstract interface class PresetRepository {
  Future<List<Preset>> list(PresetType type);
  Future<Preset> save(Preset preset, {bool create = false});
  Future<void> delete(String id);
  Future<void> setDefault(String id);
  Future<Preset> duplicate(String id, PresetType type);
  Future<List<PresetTemplate>> templates(PresetType type);
  Future<Preset> fromTemplate(String key, PresetType type, {String? name});

  Future<Paginated<PrintProfile>> profiles();
  Future<PrintProfile> saveProfile({
    required String name,
    required String machinePresetId,
    required String energyPresetId,
    String? id,
    String? costPresetId,
    String? description,
    bool isDefault = false,
  });
  Future<void> deleteProfile(String id);
  Future<void> setDefaultProfile(String id);
  Future<PrintProfile> duplicateProfile(String id);
}
