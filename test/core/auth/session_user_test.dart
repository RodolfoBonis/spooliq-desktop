import 'package:flutter_test/flutter_test.dart';
import 'package:spooliq_desktop/core/auth/permissions.dart';
import 'package:spooliq_desktop/core/auth/session_user.dart';

import '../../helpers/fixtures.dart';

void main() {
  group('SessionUser.fromAccessToken', () {
    test('reads claims and realm roles', () {
      final user = SessionUser.fromAccessToken(
        fakeJwt({
          'sub': 'u-1',
          'email': 'ana@x.com',
          'name': 'Ana Maria Souza',
          'organization_id': 'org-1',
          'exp': 1893456000,
          'realm_access': {
            'roles': ['Owner', 'offline_access', 'User'],
          },
        }),
      )!;
      expect(user.id, 'u-1');
      expect(user.organizationId, 'org-1');
      expect(user.roles, {Role.owner, Role.user});
      expect(user.initials, 'AS');
      expect(
        user.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(1893456000 * 1000),
      );
      expect(user.primaryRole, Role.owner);
    });

    test('falls back to preferred_username for the name', () {
      final user = SessionUser.fromAccessToken(
        fakeJwt({'sub': 'u', 'preferred_username': 'ana', 'realm_access': {}}),
      )!;
      expect(user.name, 'ana');
      expect(user.roles, isEmpty);
    });

    test('returns null for malformed tokens', () {
      expect(SessionUser.fromAccessToken('nope'), isNull);
      expect(SessionUser.fromAccessToken('a.!!!.c'), isNull);
    });
  });

  group('Permissions', () {
    SessionUser withRoles(Set<Role> roles) => SessionUser(
      id: 'u',
      email: 'e',
      name: 'n',
      organizationId: 'o',
      roles: roles,
      expiresAt: null,
    );

    test('User sees organization but cannot manage', () {
      final u = withRoles({Role.user});
      expect(u.canSeeOrganization, isTrue);
      expect(u.canDeleteBudgets, isFalse);
      expect(u.canSeeCompanySettings, isFalse);
      expect(u.canSeeAdmin, isFalse);
    });

    test('OrgAdmin manages but has no billing', () {
      final u = withRoles({Role.orgAdmin});
      expect(u.canManageCatalog, isTrue);
      expect(u.canSeeSubscription, isFalse);
    });

    test('Owner has billing; PlatformAdmin has admin', () {
      expect(withRoles({Role.owner}).canSeeSubscription, isTrue);
      final admin = withRoles({Role.platformAdmin});
      expect(admin.canSeeAdmin, isTrue);
      expect(admin.canSeeOrganization, isFalse);
    });
  });
}
