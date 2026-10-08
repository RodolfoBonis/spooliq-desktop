import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/features/catalog/domain/catalog.dart';

abstract interface class CatalogRepository {
  // Marcas.
  Future<Paginated<Brand>> brands({
    PageQuery page = const PageQuery(pageSize: 100),
  });
  Future<Brand> saveBrand({
    required String name,
    String? id,
    String? description,
  });
  Future<void> deleteBrand(String id);

  // Materiais.
  Future<Paginated<Material>> materials({
    PageQuery page = const PageQuery(pageSize: 100),
  });
  Future<Material> saveMaterial({
    required String name,
    String? id,
    String? description,
    int? tempTable,
    int? tempExtruder,
  });
  Future<void> deleteMaterial(String id);

  // Filamentos.
  Future<Paginated<Filament>> filaments({
    PageQuery page = const PageQuery(),
    FilamentFilter filter = const FilamentFilter(),
  });
  Future<Filament> filament(String id);
  Future<Filament> saveFilament(FilamentInput input, {String? id});
  Future<void> deleteFilament(String id);

  // Estoque.
  Future<Paginated<StockMovement>> stockMovements(
    String filamentId, {
    int page = 1,
  });
  Future<StockMovement> addStockMovement(
    String filamentId, {
    required StockMovementType type,
    required double grams,
    int? unitPricePerKgCents,
    String? note,
  });
}
