import 'package:spooliq_desktop/core/auth/session_user.dart';

/// Matriz de permissões espelhando `ROUTE_PERMISSIONS` do spooliq-web e os
/// papéis exigidos pelas rotas do backend (`features/*/routes.go`).
extension Permissions on SessionUser {
  // Navegação.
  bool get canSeeDashboard => roles.isNotEmpty;
  bool get canSeeOrganization => hasOrganizationAccess;
  bool get canSeeCompanySettings => canManage;
  bool get canSeeUsers => canManage;
  bool get canSeeSubscription => isOwner;
  bool get canSeeAdmin => isPlatformAdmin;

  // Ações (o backend é a fonte da verdade; a UI só esconde/desabilita).
  bool get canDeleteBudgets => canManage;
  bool get canDeleteCustomers => canManage;
  bool get canManageCatalog => canManage;
  bool get canManagePresets => canManage;
  bool get canDeleteModels => canManage;
  bool get canManageUsers => canManage;
}
