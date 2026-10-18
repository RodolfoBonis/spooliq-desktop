import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spooliq_desktop/core/network/api_client.dart';
import 'package:spooliq_desktop/features/catalog/data/api_catalog_repository.dart';
import 'package:spooliq_desktop/features/catalog/domain/catalog.dart';

class _Api extends Mock implements ApiClient {}

void main() {
  test('stock movements send whole grams (the API rejects 382.0)', () async {
    final api = _Api();
    when(
      () => api.postJson(any(), body: any(named: 'body')),
    ).thenAnswer((_) async => {'movement': <String, dynamic>{}});

    await ApiCatalogRepository(api).addStockMovement(
      'f1',
      type: StockMovementType.purchase,
      grams: 382,
      note: 'Estoque inicial',
    );

    final body =
        verify(
              () => api.postJson(
                '/filaments/f1/stock-movements',
                body: captureAny(named: 'body'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(body['grams'], isA<int>());
    expect(jsonEncode(body), contains('"grams":382'));
    expect(jsonEncode(body), isNot(contains('382.0')));
  });

  test('the low stock alert is sent as whole grams', () {
    const input = FilamentInput(
      name: 'PLA Premium',
      brandId: 'b',
      materialId: 'm',
      color: 'Rosa',
      colorType: ColorType.solid,
      diameter: 1.75,
      pricePerKgCents: 12000,
      trackStock: true,
      lowStockThresholdGrams: 100,
    );
    expect(input.toJson()['low_stock_threshold_grams'], 100);
    expect(input.toJson()['low_stock_threshold_grams'], isA<int>());
    expect(input.toJson()['track_stock'], isTrue);
  });
}
