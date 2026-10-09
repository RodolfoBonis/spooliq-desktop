import 'package:spooliq_desktop/core/network/api_client.dart';
import 'package:spooliq_desktop/core/network/json.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/features/notifications/domain/notification.dart';

class ApiNotificationRepository implements NotificationRepository {
  const ApiNotificationRepository(this._api);

  final ApiClient _api;

  @override
  Future<Paginated<AppNotification>> list({
    PageQuery page = const PageQuery(),
    bool unreadOnly = false,
  }) async => Paginated.fromJson(
    await _api.get(
      '/notifications',
      query: {
        'page': page.page,
        'page_size': page.pageSize,
        if (unreadOnly) 'unread': true,
      },
    ),
    AppNotification.fromJson,
  );

  @override
  Future<int> unreadCount() async =>
      (await _api.getJson('/notifications/unread-count')).integer('count');

  @override
  Future<void> markRead(String id) => _api.post('/notifications/$id/read');

  @override
  Future<void> markAllRead() => _api.post('/notifications/read-all');
}
