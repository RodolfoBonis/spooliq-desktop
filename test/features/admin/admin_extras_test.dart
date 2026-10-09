import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spooliq_desktop/core/network/api_client.dart';
import 'package:spooliq_desktop/features/admin/data/api_admin_repository.dart';
import 'package:spooliq_desktop/features/admin/domain/admin.dart';
import 'package:spooliq_desktop/features/subscription/domain/billing.dart';

class _Api extends Mock implements ApiClient {}

void main() {
  test('migration reads per-company results', () {
    final m = PlanMigration.fromJson(const {
      'migration_id': 'mig',
      'status': 'scheduled',
      'total_companies': 2,
      'successful': 1,
      'failed': 1,
      'scheduled_for': '2026-10-10T12:00:00Z',
      'results': [
        {'company_name': 'Artesier', 'success': true},
        {'company_name': 'Voolt', 'success': false, 'error': 'sem cartão'},
      ],
    });
    expect(m.canExecute, isTrue);
    expect(m.scheduledFor, isNotNull);
    expect(m.results.last.error, 'sem cartão');
  });

  test('feature validation lists invalid features and suggestions', () {
    final v = FeatureValidation.fromJson(const {
      'is_valid': false,
      'invalid_features': [
        {
          'feature': {'name': 'Orcamentos'},
          'error': 'desconhecido',
        },
      ],
      'suggestions': ['Orçamentos ilimitados'],
    });
    expect(v.isValid, isFalse);
    expect(v.invalid, ['Orcamentos: desconhecido']);
    expect(v.suggestions, ['Orçamentos ilimitados']);
  });

  test('plan audit entry labels the action and changed fields', () {
    final e = PlanAuditEntry.fromJson(const {
      'id': 'a',
      'action': 'deactivated',
      'user_email': 'admin@spooliq.com',
      'changes': {'is_active': false, 'price': 49.9},
    });
    expect(e.actionLabel, 'Desativado');
    expect(e.changedFields, ['is_active', 'price']);
  });

  test('subscription detail reads the current plan', () {
    final d = SubscriptionDetail.fromJson(const {
      'current_plan': {'name': 'Pro', 'price': 49.9, 'cycle': 'YEARLY'},
      'status_updated_at': '2026-09-01T10:00:00Z',
    });
    expect(d.planName, 'Pro');
    expect(billingCycleSuffix(d.planCycle), '/ano');
    expect(d.statusUpdatedAt, isNotNull);
  });

  test('validateFeatures posts the features payload', () async {
    final api = _Api();
    when(
      () => api.postJson(any(), body: any(named: 'body')),
    ).thenAnswer((_) async => {'is_valid': true});

    final v = await ApiAdminRepository(
      api,
    ).validateFeatures(const [PlanFeature(name: 'Kanban')]);

    expect(v.isValid, isTrue);
    verify(
      () => api.postJson(
        '/admin/features/validate',
        body: {
          'features': [
            {'name': 'Kanban', 'description': '', 'is_active': true},
          ],
        },
      ),
    ).called(1);
  });
}
