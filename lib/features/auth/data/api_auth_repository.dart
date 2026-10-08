import 'package:dio/dio.dart';
import 'package:spooliq_desktop/core/auth/session_user.dart';
import 'package:spooliq_desktop/core/auth/token_store.dart';
import 'package:spooliq_desktop/core/network/api_client.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/network/auth_interceptor.dart';
import 'package:spooliq_desktop/core/network/json.dart';
import 'package:spooliq_desktop/core/observability/app_logger.dart';
import 'package:spooliq_desktop/features/auth/domain/auth_repository.dart';

class ApiAuthRepository implements AuthRepository {
  const ApiAuthRepository({required ApiClient api, required TokenStore tokens})
    : _api = api,
      _tokens = tokens;

  final ApiClient _api;
  final TokenStore _tokens;

  @override
  Future<SessionUser?> restore() async {
    final tokens = await _tokens.read();
    if (tokens == null) return null;
    final user = SessionUser.fromAccessToken(tokens.accessToken);
    if (user == null) {
      await _tokens.clear();
      return null;
    }
    // Token expirado sem refresh token: não há como recuperar a sessão.
    final expired = user.expiresAt?.isBefore(DateTime.now()) ?? false;
    if (expired && tokens.refreshToken.isEmpty) {
      await _tokens.clear();
      return null;
    }
    return user;
  }

  @override
  Future<SessionUser> login({
    required String email,
    required String password,
  }) async {
    final json = await _api.postJson(
      '/login',
      body: {'email': email.trim(), 'password': password},
      auth: false,
    );
    final access = json.strOrNull('accessToken');
    if (access == null) {
      throw const ServerError('Resposta de login inválida.');
    }
    final user = SessionUser.fromAccessToken(access);
    if (user == null) throw const ServerError('Token de acesso inválido.');
    await _tokens.write(
      AuthTokens(
        accessToken: access,
        refreshToken: json.str('refreshToken'),
      ),
    );
    AppLogger.info('Login realizado', category: 'auth');
    return user;
  }

  @override
  Future<void> register(RegisterData d) async {
    await _api.post(
      '/register',
      auth: false,
      body: compactJson({
        'name': d.name.trim(),
        'email': d.email.trim(),
        'password': d.password,
        'company_name': d.companyName.trim(),
        'company_trade_name': d.companyTradeName?.trim(),
        'company_document': d.companyDocument.replaceAll(RegExp(r'\D'), ''),
        'company_phone': d.companyPhone.trim(),
        'address': d.address.trim(),
        'address_number': d.addressNumber.trim(),
        'complement': d.complement?.trim(),
        'neighborhood': d.neighborhood.trim(),
        'city': d.city.trim(),
        'state': d.state.trim().toUpperCase(),
        'zip_code': d.zipCode.replaceAll(RegExp(r'\D'), ''),
      }),
    );
  }

  @override
  Future<void> logout() async {
    final tokens = await _tokens.read();
    await _tokens.clear();
    if (tokens == null || tokens.refreshToken.isEmpty) return;
    try {
      // /logout autentica com o refresh token; falhas não bloqueiam a saída.
      await _api.dio.post<Object?>(
        '/logout',
        options: Options(
          headers: {'Authorization': 'Bearer ${tokens.refreshToken}'},
          extra: {kSkipAuth: true},
        ),
      );
    } on Object catch (e) {
      AppLogger.warning('Logout remoto falhou', category: 'auth', error: e);
    }
  }
}
