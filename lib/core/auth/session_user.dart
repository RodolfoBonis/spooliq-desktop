import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:spooliq_desktop/core/network/json.dart';

/// Papéis do realm Keycloak (`realm_access.roles`).
enum Role {
  platformAdmin('PlatformAdmin'),
  owner('Owner'),
  orgAdmin('OrgAdmin'),
  user('User');

  const Role(this.claim);

  final String claim;

  static Role? fromClaim(String value) {
    for (final r in values) {
      if (r.claim == value) return r;
    }
    return null;
  }

  String get label => switch (this) {
    Role.platformAdmin => 'Admin da plataforma',
    Role.owner => 'Proprietário',
    Role.orgAdmin => 'Administrador',
    Role.user => 'Usuário',
  };
}

/// Usuário autenticado, extraído do access token.
class SessionUser extends Equatable {
  const SessionUser({
    required this.id,
    required this.email,
    required this.name,
    required this.organizationId,
    required this.roles,
    required this.expiresAt,
  });

  /// Decodifica o payload do JWT. Não valida assinatura — quem valida é a API.
  static SessionUser? fromAccessToken(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final json = jsonDecode(payload);
      if (json is! Map<String, dynamic>) return null;
      final exp = json.intOrNull('exp');
      final realm = json.obj('realm_access');
      final name =
          json.strOrNull('name') ??
          json.strOrNull('preferred_username') ??
          json.str('email');
      return SessionUser(
        id: json.str('sub'),
        email: json.str('email'),
        name: name,
        organizationId: json.str('organization_id'),
        roles: {
          for (final r in realm?.strings('roles') ?? const <String>[])
            ?Role.fromClaim(r),
        },
        expiresAt: exp == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(exp * 1000),
      );
    } on FormatException {
      return null;
    }
  }

  final String id;
  final String email;
  final String name;
  final String organizationId;
  final Set<Role> roles;
  final DateTime? expiresAt;

  /// Mesmo usuário com outro nome (ex.: após editar o perfil).
  SessionUser withName(String name) => SessionUser(
    id: id,
    email: email,
    name: name,
    organizationId: organizationId,
    roles: roles,
    expiresAt: expiresAt,
  );

  bool has(Role role) => roles.contains(role);
  bool hasAny(Iterable<Role> any) => any.any(roles.contains);

  bool get isPlatformAdmin => has(Role.platformAdmin);
  bool get isOwner => has(Role.owner);
  bool get isOrgAdmin => has(Role.orgAdmin);

  /// Owner ou OrgAdmin — gerencia catálogo, presets, exclusões e empresa.
  bool get canManage => isOwner || isOrgAdmin;

  /// Acesso às áreas da organização (orçamentos, clientes, catálogo…).
  bool get hasOrganizationAccess => hasAny(const [
    Role.owner,
    Role.orgAdmin,
    Role.user,
  ]);

  Role? get primaryRole {
    for (final r in Role.values) {
      if (roles.contains(r)) return r;
    }
    return null;
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  List<Object?> get props => [
    id,
    email,
    name,
    organizationId,
    roles,
    expiresAt,
  ];
}
