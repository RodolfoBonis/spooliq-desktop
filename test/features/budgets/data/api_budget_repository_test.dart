import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spooliq_desktop/core/network/api_client.dart';
import 'package:spooliq_desktop/features/budgets/data/api_budget_repository.dart';

import '../../../helpers/fixtures.dart';

class _Api extends Mock implements ApiClient {}

void main() {
  test('recalculate posts to the budget and parses the result', () async {
    final api = _Api();
    when(
      () => api.postJson(any(), body: any(named: 'body')),
    ).thenAnswer((_) async => budgetJson(id: 'b-9', total: 30000));

    final b = await ApiBudgetRepository(api).recalculate('b-9');

    expect(b.id, 'b-9');
    expect(b.totalCents, 30000);
    verify(() => api.postJson('/budgets/b-9/recalculate')).called(1);
  });
}
