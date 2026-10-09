import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spooliq_desktop/core/network/api_client.dart';
import 'package:spooliq_desktop/features/models3d/data/api_model3d_repository.dart';

class _Api extends Mock implements ApiClient {}

void main() {
  late _Api api;
  late ApiModel3DRepository repo;

  setUp(() {
    api = _Api();
    repo = ApiModel3DRepository(api);
    when(
      () => api.putJson(any(), body: any(named: 'body')),
    ).thenAnswer(
      (_) async => {
        'id': 'm',
        'name': 'Hulk',
        'file_name': 'hulk.3mf',
        'file_format': '.3mf',
        'file_size_bytes': 10,
        'tags': 'Marvel',
      },
    );
  });

  Map<String, dynamic> sentBody() =>
      verify(
            () => api.putJson('/models3d/m', body: captureAny(named: 'body')),
          ).captured.single
          as Map<String, dynamic>;

  test('update sends trimmed metadata and parses the model', () async {
    final m = await repo.update(
      'm',
      name: ' Hulk ',
      customerId: 'c1',
      tags: ' Marvel ',
    );
    expect(m.tags, ['Marvel']);
    expect(sentBody(), {
      'name': 'Hulk',
      'description': '',
      'notes': '',
      'tags': 'Marvel',
      'customer_id': 'c1',
    });
  });

  test('update sends an explicit null to detach the customer', () async {
    await repo.update('m', name: 'Hulk', customerId: null);
    final body = sentBody();
    expect(body.containsKey('customer_id'), isTrue);
    expect(body['customer_id'], isNull);
  });
}
