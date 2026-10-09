import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spooliq_desktop/core/network/network_status.dart';

/// Adapter que falha com erro de conexão nas primeiras [failures] chamadas.
class _FlakyAdapter implements HttpClientAdapter {
  _FlakyAdapter({required this.failures, this.status = 200});

  int failures;
  final int status;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    if (failures > 0) {
      failures--;
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    return ResponseBody.fromString(
      '{}',
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
  late NetworkStatus status;

  Dio client(_FlakyAdapter adapter) {
    final dio = Dio()..httpClientAdapter = adapter;
    dio.interceptors.add(
      ResilienceInterceptor(
        status: status,
        retryDio: dio,
        delays: const [Duration.zero, Duration.zero],
      ),
    );
    return dio;
  }

  setUp(() => status = NetworkStatus());

  test('retries a GET after connection errors and goes back online', () async {
    final adapter = _FlakyAdapter(failures: 2);
    final res = await client(adapter).get<Object?>('https://api/x');
    expect(res.statusCode, 200);
    expect(adapter.calls, 3);
    expect(status.online, isTrue);
  });

  test('gives up after the configured attempts and stays offline', () async {
    final adapter = _FlakyAdapter(failures: 5);
    await expectLater(
      client(adapter).get<Object?>('https://api/x'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.calls, 3);
    expect(status.online, isFalse);
  });

  test('never repeats writes', () async {
    final adapter = _FlakyAdapter(failures: 1);
    await expectLater(
      client(adapter).post<Object?>('https://api/x', data: {}),
      throwsA(isA<DioException>()),
    );
    expect(adapter.calls, 1);
    expect(status.online, isFalse);
  });

  test('HTTP errors mean the server is reachable', () async {
    status.markOffline();
    final adapter = _FlakyAdapter(failures: 0, status: 500);
    await expectLater(
      client(adapter).get<Object?>('https://api/x'),
      throwsA(isA<DioException>()),
    );
    expect(status.online, isTrue);
  });
}
