import 'package:flutter_test/flutter_test.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';

void main() {
  group('apiErrorFrom', () {
    test('maps validation errors with fields', () {
      final e = apiErrorFrom(400, {
        'error': 'Dados inválidos',
        'message': 'Dados inválidos',
        'code': 'validation_error',
        'fields': {'name': 'obrigatório'},
      });
      expect(e, isA<ValidationError>());
      expect((e as ValidationError).fields, {'name': 'obrigatório'});
      expect(e.message, 'Dados inválidos');
    });

    test('maps subscription gate codes regardless of status', () {
      final e = apiErrorFrom(403, {
        'code': 'subscription_cancelled',
        'message': 'Assinatura cancelada',
      });
      expect(e, isA<SubscriptionError>());
      expect(e.code, 'subscription_cancelled');
      expect(apiErrorFrom(402, null), isA<SubscriptionError>());
    });

    test('maps status codes', () {
      expect(apiErrorFrom(401, null), isA<UnauthorizedError>());
      expect(
        apiErrorFrom(403, {'code': 'insufficient_role'}),
        isA<ForbiddenError>(),
      );
      expect(apiErrorFrom(404, null), isA<NotFoundError>());
      expect(
        apiErrorFrom(409, {'code': 'budget_status_conflict'}).code,
        'budget_status_conflict',
      );
      expect(
        apiErrorFrom(400, {'code': 'invalid_status_transition'}),
        isA<BusinessError>(),
      );
      expect(apiErrorFrom(500, 'oops'), isA<ServerError>());
    });

    test('uses fallback messages when body is empty', () {
      expect(apiErrorFrom(500, null).message, isNotEmpty);
      expect(apiErrorFrom(404, {}).message, 'Registro não encontrado.');
    });
  });
}
