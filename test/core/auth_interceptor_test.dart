import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spooliq_desktop/core/auth/token_store.dart';
import 'package:spooliq_desktop/core/network/auth_interceptor.dart';
import 'package:spooliq_desktop/core/network/session_events.dart';

/// Responde conforme uma função (status + JSON), contando as chamadas.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);

  final (int, Object?) Function(RequestOptions o) respond;
  final calls = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    // Dá chance a requisições concorrentes chegarem juntas no refresh.
    await Future<void>.delayed(Duration.zero);
    final (status, body) = respond(options);
    return ResponseBody.fromString(
      jsonEncode(body ?? {}),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late MemoryTokenStore tokens;
  late SessionEvents events;
  late List<SessionEvent> emitted;
  late _Adapter api;
  late _Adapter refresh;

  String? bearer(RequestOptions o) =>
      (o.headers['Authorization'] as String?)?.replaceFirst('Bearer ', '');

  Dio build() {
    final dio = Dio()..httpClientAdapter = api;
    final refreshDio = Dio()..httpClientAdapter = refresh;
    dio.interceptors.add(
      AuthInterceptor(
        tokens: tokens,
        events: events,
        refreshDio: refreshDio,
        retryDio: dio,
      ),
    );
    return dio;
  }

  setUp(() {
    tokens = MemoryTokenStore()
      ..tokens = const AuthTokens(accessToken: 'old', refreshToken: 'r1');
    events = SessionEvents();
    emitted = [];
    events.stream.listen(emitted.add);
    // A API aceita só o token novo.
    api = _Adapter((o) => bearer(o) == 'new' ? (200, {'ok': true}) : (401, {}));
    refresh = _Adapter(
      (o) => bearer(o) == 'r1'
          ? (200, {'accessToken': 'new', 'refreshToken': 'r2'})
          : (401, {}),
    );
  });

  tearDown(() => events.dispose());

  test('refreshes once for concurrent 401s and retries them', () async {
    final dio = build();
    final results = await Future.wait([
      dio.get<Object?>('https://api/a'),
      dio.get<Object?>('https://api/b'),
      dio.get<Object?>('https://api/c'),
    ]);

    expect(results.map((r) => r.statusCode), everyElement(200));
    expect(refresh.calls, hasLength(1));
    expect(tokens.tokens?.accessToken, 'new');
    expect(tokens.tokens?.refreshToken, 'r2');
  });

  test('expires the session when the refresh is rejected', () async {
    tokens.tokens = const AuthTokens(accessToken: 'old', refreshToken: 'bad');
    final dio = build();

    await expectLater(
      dio.get<Object?>('https://api/a'),
      throwsA(isA<DioException>()),
    );
    await Future<void>.delayed(Duration.zero);

    expect(tokens.tokens, isNull);
    expect(emitted, contains(const SessionExpired()));
  });

  test('public requests are never refreshed', () async {
    final dio = build();
    await expectLater(
      dio.get<Object?>(
        'https://api/login',
        options: Options(extra: {kSkipAuth: true}),
      ),
      throwsA(isA<DioException>()),
    );
    expect(refresh.calls, isEmpty);
    expect(api.calls.single.headers.containsKey('Authorization'), isFalse);
  });

  test('402 announces a blocked subscription', () async {
    api = _Adapter(
      (_) => (402, {'code': 'trial_expired', 'message': 'Teste acabou'}),
    );
    final dio = build();
    await expectLater(
      dio.get<Object?>('https://api/a'),
      throwsA(isA<DioException>()),
    );
    await Future<void>.delayed(Duration.zero);

    expect(
      emitted.single,
      const SubscriptionBlocked(code: 'trial_expired', message: 'Teste acabou'),
    );
    expect(refresh.calls, isEmpty);
  });
}
