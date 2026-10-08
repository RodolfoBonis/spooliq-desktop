import 'package:spooliq_desktop/core/network/api_client.dart';
import 'package:spooliq_desktop/core/network/json.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/features/users/domain/app_user.dart';

class ApiUserRepository implements UserRepository {
  const ApiUserRepository(this._api);

  final ApiClient _api;

  @override
  Future<Paginated<AppUser>> list({PageQuery page = const PageQuery()}) async =>
      Paginated.fromJson(
        await _api.get('/users', query: page.toQuery()),
        AppUser.fromJson,
      );

  @override
  Future<AppUser> create({
    required String name,
    required String email,
    required String password,
    required UserType type,
  }) async => AppUser.fromJson(
    await _api.postJson(
      '/users',
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'user_type': type.value,
      },
    ),
  );

  @override
  Future<AppUser> update(String id, {String? name, bool? isActive}) async =>
      AppUser.fromJson(
        await _api.putJson(
          '/users/$id',
          body: compactJson({'name': name?.trim(), 'is_active': isActive}),
        ),
      );

  @override
  Future<void> delete(String id) => _api.delete('/users/$id');
}
