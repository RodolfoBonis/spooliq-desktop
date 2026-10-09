import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spooliq_desktop/core/network/api_client.dart';
import 'package:spooliq_desktop/features/catalog/domain/catalog.dart';
import 'package:spooliq_desktop/features/models3d/data/api_model3d_repository.dart';

class _Api extends Mock implements ApiClient {}

void main() {
  test('filament filter sends the diameter only when set', () {
    const filter = FilamentFilter(brandId: 'b');
    expect(filter.toQuery().containsKey('diameter'), isFalse);

    final withDiameter = filter.copyWith(diameter: () => 2.85);
    expect(withDiameter.toQuery(), containsPair('diameter', 2.85));
    expect(withDiameter.brandId, 'b');
    expect(withDiameter.copyWith(diameter: () => null).diameter, isNull);
  });

  test('models list sends the format with a leading dot', () async {
    final api = _Api();
    when(
      () => api.get(any(), query: any(named: 'query')),
    ).thenAnswer((_) async => {'data': <Object>[], 'total': 0});

    await ApiModel3DRepository(api).list(format: '3mf');

    final query =
        verify(
              () => api.get('/models3d', query: captureAny(named: 'query')),
            ).captured.single
            as Map<String, dynamic>;
    expect(query['format'], '.3mf');
  });
}
