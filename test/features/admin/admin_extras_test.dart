import 'package:flutter_test/flutter_test.dart';
import 'package:spooliq_desktop/features/admin/domain/admin.dart';
import 'package:spooliq_desktop/features/subscription/domain/billing.dart';

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
}
