import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/features/dashboard/domain/dashboard.dart';

/// Tipos de entidade registrados no log (`entity_type`).
enum ActivityEntity {
  budget('budget', 'Orçamentos'),
  customer('customer', 'Clientes'),
  filament('filament', 'Filamentos'),
  stockMovement('stock_movement', 'Estoque'),
  material('material', 'Materiais'),
  brand('brand', 'Marcas'),
  preset('preset', 'Presets'),
  model3d('model3d', 'Modelos 3D');

  const ActivityEntity(this.value, this.label);

  final String value;
  final String label;
}

/// Ações registradas no log (`action`).
enum ActivityAction {
  created('created', 'Criação'),
  updated('updated', 'Edição'),
  deleted('deleted', 'Exclusão'),
  statusChanged('status_changed', 'Mudança de status'),
  approved('approved', 'Aprovação'),
  rejected('rejected', 'Rejeição');

  const ActivityAction(this.value, this.label);

  final String value;
  final String label;
}

// Interface (e não função) para trocar a implementação no DI e nos testes.
// ignore: one_member_abstracts
abstract interface class ActivityRepository {
  Future<Paginated<Activity>> list({
    PageQuery page = const PageQuery(),
    ActivityEntity? entity,
    ActivityAction? action,
  });
}
