import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:spooliq_desktop/core/auth/token_store.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/network/auth_interceptor.dart';
import 'package:spooliq_desktop/core/network/json.dart';
import 'package:spooliq_desktop/core/network/network_status.dart';
import 'package:spooliq_desktop/core/network/session_events.dart';
import 'package:spooliq_desktop/core/observability/app_logger.dart';

/// Resposta binária (ex.: PDF devolvido como bytes).
class BinaryResponse {
  const BinaryResponse({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;
}

/// Cliente HTTP da API SpoolIQ.
///
/// Todos os métodos lançam somente [ApiError] — nunca `DioException`.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required TokenStore tokens,
    required SessionEvents events,
    NetworkStatus? status,
    Dio? dio,
  }) : _dio = dio ?? Dio(),
       status = status ?? NetworkStatus() {
    _dio.options = _dio.options.copyWith(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Accept': 'application/json'},
    );
    final refreshDio = Dio(BaseOptions(baseUrl: baseUrl));
    _dio.interceptors
      ..add(ResilienceInterceptor(status: this.status, retryDio: _dio))
      ..add(
        AuthInterceptor(
          tokens: tokens,
          events: events,
          refreshDio: refreshDio,
          retryDio: _dio,
        ),
      );
  }

  final Dio _dio;

  /// Online/offline conforme as últimas requisições.
  final NetworkStatus status;

  Dio get dio => _dio;

  /// Checagem leve de conectividade (sem autenticação).
  Future<void> ping() => get('/health/live', auth: false);

  Future<Object?> get(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) => _send(
    () => _dio.get<Object?>(
      path,
      queryParameters: _clean(query),
      options: _opts(auth),
    ),
  );

  Future<Json> getJson(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async => _asJson(await get(path, query: query, auth: auth));

  Future<Object?> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool auth = true,
  }) => _send(
    () => _dio.post<Object?>(
      path,
      data: body,
      queryParameters: _clean(query),
      options: _opts(auth),
    ),
  );

  Future<Json> postJson(String path, {Object? body, bool auth = true}) async =>
      _asJson(await post(path, body: body, auth: auth));

  Future<Object?> put(String path, {Object? body}) =>
      _send(() => _dio.put<Object?>(path, data: body));

  Future<Json> putJson(String path, {Object? body}) async =>
      _asJson(await put(path, body: body));

  Future<Object?> patch(String path, {Object? body}) =>
      _send(() => _dio.patch<Object?>(path, data: body));

  Future<Json> patchJson(String path, {Object? body}) async =>
      _asJson(await patch(path, body: body));

  Future<Object?> delete(String path, {Object? body}) =>
      _send(() => _dio.delete<Object?>(path, data: body));

  /// Upload multipart (`file`, `logo`…).
  Future<Json> upload(
    String path, {
    required String field,
    required String filePath,
    String? fileName,
    Map<String, Object?> fields = const {},
    void Function(int sent, int total)? onProgress,
  }) async {
    final form = FormData.fromMap({
      for (final e in fields.entries)
        if (e.value != null) e.key: e.value.toString(),
      field: await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final res = await _send(
      () => _dio.post<Object?>(path, data: form, onSendProgress: onProgress),
    );
    return _asJson(res);
  }

  /// GET que pode responder JSON ou binário (ex.: `/budgets/{id}/pdf`).
  Future<Object> getJsonOrBytes(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final res = await _dio.get<List<int>>(
        path,
        queryParameters: _clean(query),
        options: Options(responseType: ResponseType.bytes),
      );
      final type = res.headers.value(Headers.contentTypeHeader) ?? '';
      final bytes = Uint8List.fromList(res.data ?? const []);
      if (type.contains('json')) return _asJson(_decodeJson(bytes));
      return BinaryResponse(bytes: bytes, contentType: type);
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  /// Baixa um arquivo absoluto (ex.: CDN) ou relativo à API.
  Future<Uint8List> download(
    String urlOrPath, {
    bool auth = true,
    Map<String, dynamic>? query,
  }) async {
    try {
      final res = await _dio.get<List<int>>(
        urlOrPath,
        queryParameters: _clean(query),
        options: Options(
          responseType: ResponseType.bytes,
          extra: {if (!auth || urlOrPath.startsWith('http')) kSkipAuth: true},
        ),
      );
      return Uint8List.fromList(res.data ?? const []);
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Options _opts(bool auth) => Options(extra: {if (!auth) kSkipAuth: true});

  Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    return {
      for (final e in query.entries)
        if (e.value != null && e.value.toString().isNotEmpty) e.key: e.value,
    };
  }

  Future<Object?> _send(Future<Response<Object?>> Function() call) async {
    try {
      final res = await call();
      return res.data;
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Json _asJson(Object? data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data == null || data == '' || data == true) return <String, dynamic>{};
    throw const ServerError('Resposta inesperada do servidor.');
  }

  ApiError _map(DioException e) {
    final status = e.response?.statusCode;
    if (status == null) {
      AppLogger.warning(
        'Falha de rede: ${e.type.name} ${e.requestOptions.path}',
        category: 'http',
      );
      return const NetworkError();
    }
    var body = e.response?.data;
    if (body is List<int>) body = _decodeJson(body);
    final error = apiErrorFrom(status, body);
    if (error is ServerError) {
      unawaited(
        AppLogger.error(
          error,
          e.stackTrace,
          reason: '${e.requestOptions.method} ${e.requestOptions.path}',
          category: 'http',
        ),
      );
    } else {
      AppLogger.info(
        'HTTP $status ${e.requestOptions.method} ${e.requestOptions.path}',
        category: 'http',
        data: {'code': error.code},
      );
    }
    return error;
  }
}

final Converter<List<int>, Object?> _utf8Json = utf8.decoder.fuse(json.decoder);

Object? _decodeJson(List<int> bytes) {
  try {
    return _utf8Json.convert(bytes);
  } on FormatException {
    return null;
  }
}
