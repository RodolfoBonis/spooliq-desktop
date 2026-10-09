import 'package:spooliq_desktop/core/network/api_client.dart';
import 'package:spooliq_desktop/core/network/json.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/features/catalog/domain/catalog.dart';
import 'package:spooliq_desktop/features/catalog/domain/catalog_repository.dart';

class ApiCatalogRepository implements CatalogRepository {
  const ApiCatalogRepository(this._api);

  final ApiClient _api;

  @override
  Future<Paginated<Brand>> brands({
    PageQuery page = const PageQuery(pageSize: 100),
  }) async => Paginated.fromJson(
    await _api.get('/brands', query: page.toQuery()),
    Brand.fromJson,
  );

  @override
  Future<Brand> saveBrand({
    required String name,
    String? id,
    String? description,
  }) async {
    final body = {
      'name': name.trim(),
      'description': description?.trim() ?? '',
    };
    final json = id == null
        ? await _api.postJson('/brands', body: body)
        : await _api.putJson('/brands/$id', body: body);
    return Brand.fromJson(json);
  }

  @override
  Future<void> deleteBrand(String id) => _api.delete('/brands/$id');

  @override
  Future<Paginated<Material>> materials({
    PageQuery page = const PageQuery(pageSize: 100),
  }) async => Paginated.fromJson(
    await _api.get('/materials', query: page.toQuery()),
    Material.fromJson,
  );

  @override
  Future<Material> saveMaterial({
    required String name,
    String? id,
    String? description,
    int? tempTable,
    int? tempExtruder,
  }) async {
    final body = compactJson({
      'name': name.trim(),
      'description': description?.trim() ?? '',
      'temp_table': tempTable,
      'temp_extruder': tempExtruder,
    });
    final json = id == null
        ? await _api.postJson('/materials', body: body)
        : await _api.putJson('/materials/$id', body: body);
    return Material.fromJson(json);
  }

  @override
  Future<void> deleteMaterial(String id) => _api.delete('/materials/$id');

  @override
  Future<Paginated<Filament>> filaments({
    PageQuery page = const PageQuery(),
    FilamentFilter filter = const FilamentFilter(),
  }) async {
    final hasSearch = page.search != null && page.search!.trim().isNotEmpty;
    final body = await _api.get(
      hasSearch ? '/filaments/search' : '/filaments',
      query: {...page.toQuery(), ...filter.toQuery()},
    );
    return Paginated.fromJson(body, Filament.fromJson);
  }

  @override
  Future<Filament> filament(String id) async =>
      Filament.fromJson(await _api.getJson('/filaments/$id'));

  @override
  Future<Filament> saveFilament(FilamentInput input, {String? id}) async {
    final json = id == null
        ? await _api.postJson('/filaments', body: input.toJson())
        : await _api.putJson('/filaments/$id', body: input.toJson());
    return Filament.fromJson(json);
  }

  @override
  Future<void> deleteFilament(String id) => _api.delete('/filaments/$id');

  @override
  Future<Paginated<StockMovement>> stockMovements(
    String filamentId, {
    int page = 1,
    StockMovementType? type,
  }) async => Paginated.fromJson(
    await _api.get(
      '/filaments/$filamentId/stock-movements',
      query: {
        'page': page,
        'page_size': 50,
        if (type != null) 'type': type.value,
      },
    ),
    StockMovement.fromJson,
  );

  @override
  Future<StockMovement> addStockMovement(
    String filamentId, {
    required StockMovementType type,
    required double grams,
    int? unitPricePerKgCents,
    String? note,
  }) async {
    final json = await _api.postJson(
      '/filaments/$filamentId/stock-movements',
      body: compactJson({
        'type': type.value,
        'grams': grams,
        'unit_price_per_kg': unitPricePerKgCents,
        'note': (note == null || note.trim().isEmpty) ? null : note.trim(),
      }),
    );
    return StockMovement.fromJson(json.obj('movement') ?? json);
  }
}
