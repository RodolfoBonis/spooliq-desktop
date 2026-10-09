import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Conectividade com a API, inferida das próprias requisições: qualquer
/// resposta (mesmo 4xx/5xx) = online; erro de conexão = offline.
class NetworkStatus extends ValueNotifier<bool> {
  NetworkStatus() : super(true);

  bool get online => value;

  void markOnline() => value = true;
  void markOffline() => value = false;
}

/// Erros sem resposta que indicam rede indisponível (e valem nova tentativa).
bool isConnectivityError(DioException e) =>
    e.response == null &&
    switch (e.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout => true,
      _ => false,
    };

/// Atualiza o [NetworkStatus] e repete GETs que falharam por conexão
/// (escritas não são repetidas para não duplicar efeitos).
class ResilienceInterceptor extends Interceptor {
  ResilienceInterceptor({
    required this.status,
    required this.retryDio,
    this.delays = const [Duration(seconds: 1), Duration(seconds: 3)],
  });

  final NetworkStatus status;
  final Dio retryDio;

  /// Espera antes de cada nova tentativa (o tamanho define quantas).
  final List<Duration> delays;

  static const _attemptKey = 'resilience.attempt';

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    status.markOnline();
    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!isConnectivityError(err)) {
      // Houve resposta (ou erro que não é de rede): o servidor está lá.
      if (err.response != null) status.markOnline();
      return handler.next(err);
    }
    status.markOffline();
    final options = err.requestOptions;
    final attempt = (options.extra[_attemptKey] as int?) ?? 0;
    if (options.method != 'GET' || attempt >= delays.length) {
      return handler.next(err);
    }
    await Future<void>.delayed(delays[attempt]);
    options.extra[_attemptKey] = attempt + 1;
    try {
      handler.resolve(await retryDio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
