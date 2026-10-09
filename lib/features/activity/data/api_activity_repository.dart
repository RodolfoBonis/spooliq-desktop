import 'package:spooliq_desktop/core/network/api_client.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/features/activity/domain/activity_repository.dart';
import 'package:spooliq_desktop/features/dashboard/domain/dashboard.dart';

class ApiActivityRepository implements ActivityRepository {
  const ApiActivityRepository(this._api);

  final ApiClient _api;

  @override
  Future<Paginated<Activity>> list({
    PageQuery page = const PageQuery(),
    ActivityEntity? entity,
    ActivityAction? action,
  }) async => Paginated.fromJson(
    await _api.get(
      '/activities',
      query: {
        // O endpoint não aceita busca/ordenação: só paginação e filtros.
        'page': page.page,
        'page_size': page.pageSize,
        'entity_type': ?entity?.value,
        'action': ?action?.value,
      },
    ),
    Activity.fromJson,
  );
}
