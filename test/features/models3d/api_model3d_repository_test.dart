import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spooliq_desktop/core/network/api_client.dart';
import 'package:spooliq_desktop/features/models3d/data/api_model3d_repository.dart';
import 'package:spooliq_desktop/features/models3d/domain/model3d.dart';

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
      description: '',
      notes: '',
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
    await repo.update(
      'm',
      name: 'Hulk',
      customerId: null,
      description: '',
      notes: '',
      tags: '',
    );
    final body = sentBody();
    expect(body.containsKey('customer_id'), isTrue);
    expect(body['customer_id'], isNull);
  });

  test('model equality reflects the editable fields', () {
    Model3D model({String? customerId}) => Model3D(
      id: 'm',
      name: 'Hulk',
      fileName: 'hulk.3mf',
      format: '3MF',
      sizeBytes: 10,
      customerId: customerId,
    );
    expect(model(customerId: 'c1'), isNot(model()));
  });
}
