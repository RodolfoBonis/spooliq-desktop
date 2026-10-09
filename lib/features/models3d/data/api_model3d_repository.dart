import 'dart:typed_data';

import 'package:spooliq_desktop/core/network/api_client.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/features/models3d/domain/model3d.dart';

class ApiModel3DRepository implements Model3DRepository {
  const ApiModel3DRepository(this._api);

  final ApiClient _api;

  @override
  Future<Paginated<Model3D>> list({
    PageQuery page = const PageQuery(),
    String? customerId,
  }) async => Paginated.fromJson(
    await _api.get(
      '/models3d',
      query: {...page.toQuery(), 'customer_id': customerId},
    ),
    Model3D.fromJson,
  );

  @override
  Future<Model3D> upload({
    required String filePath,
    required String name,
    String? description,
    String? customerId,
    String? notes,
    String? tags,
    void Function(int sent, int total)? onProgress,
  }) async => Model3D.fromJson(
    await _api.upload(
      '/models3d',
      field: 'file',
      filePath: filePath,
      fields: {
        'name': name.trim(),
        'description': description,
        'customer_id': customerId,
        'notes': notes,
        'tags': tags,
      },
      onProgress: onProgress,
    ),
  );

  @override
  Future<Model3D> update(
    String id, {
    required String name,
    required String? customerId,
    String? description,
    String? notes,
    String? tags,
  }) async => Model3D.fromJson(
    await _api.putJson(
      '/models3d/$id',
      body: {
        'name': name.trim(),
        'description': description?.trim() ?? '',
        'notes': notes?.trim() ?? '',
        'tags': tags?.trim() ?? '',
        // Sempre enviado: null explícito desvincula o cliente na API.
        'customer_id': customerId,
      },
    ),
  );

  @override
  Future<void> delete(String id) => _api.delete('/models3d/$id');

  @override
  Future<Uint8List> download(String id) => _api.download('/models3d/$id/file');

  @override
  Future<SliceAnalysis> sliceAnalysis(String id) async =>
      SliceAnalysis.fromJson(
        await _api.getJson('/models3d/$id/slice-analysis'),
      );

  @override
  Future<SliceAnalysis> analyzeFile(
    String filePath, {
    void Function(int sent, int total)? onProgress,
  }) async => SliceAnalysis.fromJson(
    await _api.upload(
      '/slicer/analyze',
      field: 'file',
      filePath: filePath,
      onProgress: onProgress,
    ),
  );
}
