import 'dart:async';

import 'package:dio/dio.dart';
import 'package:spooliq_desktop/core/auth/token_store.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/network/session_events.dart';
import 'package:spooliq_desktop/core/observability/app_logger.dart';

/// Chave em `RequestOptions.extra` para requisições públicas (sem Bearer).
const kSkipAuth = 'skip_auth';
const _kRetried = 'auth_retried';

/// Anexa o Bearer token e tenta um único refresh em 401.
///
/// O refresh é "single-flight": várias requisições que recebem 401 ao mesmo
/// tempo aguardam a mesma renovação. Se o refresh falhar (inclusive porque o
/// backend pode rejeitar refresh tokens no middleware de access token), os
/// tokens são apagados e [SessionExpired] é emitido.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required TokenStore tokens,
    required SessionEvents events,
    required Dio refreshDio,
    required Dio retryDio,
  }) : _tokens = tokens,
       _events = events,
       _refreshDio = refreshDio,
       _retryDio = retryDio;

  final TokenStore _tokens;
  final SessionEvents _events;
  final Dio _refreshDio;
  final Dio _retryDio;

  Future<AuthTokens?>? _refreshing;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[kSkipAuth] != true) {
      final tokens = await _tokens.read();
      if (tokens != null) {
        options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final options = err.requestOptions;
    final status = response?.statusCode;

    if (status == 402 || status == 403) {
      final data = response?.data;
      final code = data is Map ? data['code']?.toString() : null;
      if (status == 402 ||
          (code != null && SubscriptionError.codes.contains(code))) {
        _events.emit(
          SubscriptionBlocked(
            code: code ?? 'payment_required',
            message:
                (data is Map ? data['message']?.toString() : null) ??
                'Sua assinatura precisa de atenção.',
          ),
        );
      }
      return handler.next(err);
    }

    final canRefresh =
        status == 401 &&
        options.extra[kSkipAuth] != true &&
        options.extra[_kRetried] != true;
    if (!canRefresh) return handler.next(err);

    final refreshed = await _refreshOnce();
    if (refreshed == null) {
      _events.emit(const SessionExpired());
      return handler.next(err);
    }

    try {
      options
        ..extra[_kRetried] = true
        ..headers['Authorization'] = 'Bearer ${refreshed.accessToken}';
      final retry = await _retryDio.fetch<dynamic>(options);
      return handler.resolve(retry);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _tokens.clear();
        _events.emit(const SessionExpired());
      }
      return handler.next(e);
    }
  }

  Future<AuthTokens?> _refreshOnce() {
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<AuthTokens?> _refresh() async {
    final current = await _tokens.read();
    if (current == null || current.refreshToken.isEmpty) return null;
    try {
      final res = await _refreshDio.post<Map<String, dynamic>>(
        '/refresh',
        options: Options(
          headers: {'Authorization': 'Bearer ${current.refreshToken}'},
        ),
      );
      final data = res.data ?? const {};
      final access = data['accessToken'] as String?;
      if (access == null || access.isEmpty) throw StateError('no token');
      final tokens = AuthTokens(
        accessToken: access,
        refreshToken: (data['refreshToken'] as String?) ?? current.refreshToken,
      );
      await _tokens.write(tokens);
      AppLogger.info('Sessão renovada', category: 'auth');
      return tokens;
    } on Object catch (e) {
      AppLogger.warning('Falha ao renovar sessão', category: 'auth', error: e);
      await _tokens.clear();
      return null;
    }
  }
}
