import 'package:spooliq_desktop/core/network/api_client.dart';
import 'package:spooliq_desktop/features/account/domain/account.dart';

class ApiAccountRepository implements AccountRepository {
  const ApiAccountRepository(this._api);

  final ApiClient _api;

  @override
  Future<void> forgotPassword(String email) => _api.post(
    '/password/forgot',
    body: {'email': email.trim()},
    auth: false,
  );

  @override
  Future<Me> me() async => Me.fromJson(await _api.getJson('/me'));

  @override
  Future<Me> updateName(String name) async =>
      Me.fromJson(await _api.putJson('/me', body: {'name': name.trim()}));

  @override
  Future<void> changePassword({
    required String current,
    required String newPassword,
  }) => _api.post(
    '/me/password',
    body: {'current_password': current, 'new_password': newPassword},
  );
}
