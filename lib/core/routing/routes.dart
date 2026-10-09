import 'package:flutter/material.dart';
import 'package:spooliq_desktop/core/auth/permissions.dart';
import 'package:spooliq_desktop/core/auth/session_user.dart';

/// Caminhos da aplicação.
abstract final class Routes {
  static const login = '/login';
  static const register = '/register';
  static const dashboard = '/dashboard';
  static const budgets = '/budgets';
  static const budgetNew = '/budgets/new';
  static String budget(String id) => '/budgets/$id';
  static String budgetEdit(String id) => '/budgets/$id/edit';
  static const customers = '/customers';
  static String customer(String id) => '/customers/$id';
  static const activities = '/activities';
  static const filaments = '/catalog/filaments';
  static const materials = '/catalog/materials';
  static const brands = '/catalog/brands';
  static const models = '/catalog/models';
  static const machines = '/presets/machines';
  static const energy = '/presets/energy';
  static const costs = '/presets/costs';
  static const profiles = '/presets/profiles';
  static const company = '/settings/company';
  static const branding = '/settings/branding';
  static const users = '/settings/users';
  static const subscription = '/settings/subscription';
  static const admin = '/admin';
  static const adminCompanies = '/admin/companies';
  static const adminPlans = '/admin/plans';
  static const adminSubscriptions = '/admin/subscriptions';

  static const Set<String> publicPaths = {login, register};
}

/// Item de navegação (sidebar + command palette).
class NavEntry {
  const NavEntry({
    required this.path,
    required this.label,
    required this.icon,
    required this.visible,
    this.keywords = const [],
  });

  final String path;
  final String label;
  final IconData icon;
  final bool Function(SessionUser user) visible;
  final List<String> keywords;
}

class NavGroup {
  const NavGroup({required this.entries, this.title});

  final String? title;
  final List<NavEntry> entries;
}

bool _org(SessionUser u) => u.canSeeOrganization;

/// Estrutura de navegação, filtrada por permissão.
const navigation = <NavGroup>[
  NavGroup(
    entries: [
      NavEntry(
        path: Routes.dashboard,
        label: 'Visão geral',
        icon: Icons.space_dashboard_outlined,
        visible: _always,
        keywords: ['dashboard', 'indicadores', 'início'],
      ),
      NavEntry(
        path: Routes.budgets,
        label: 'Orçamentos',
        icon: Icons.view_kanban_outlined,
        visible: _org,
        keywords: ['kanban', 'quadro', 'propostas'],
      ),
      NavEntry(
        path: Routes.customers,
        label: 'Clientes',
        icon: Icons.people_alt_outlined,
        visible: _org,
      ),
      NavEntry(
        path: Routes.activities,
        label: 'Atividades',
        icon: Icons.history_rounded,
        visible: _org,
        keywords: ['histórico', 'log', 'auditoria'],
      ),
    ],
  ),
  NavGroup(
    title: 'Catálogo',
    entries: [
      NavEntry(
        path: Routes.filaments,
        label: 'Filamentos',
        icon: Icons.blur_circular_outlined,
        visible: _org,
        keywords: ['estoque', 'carretel'],
      ),
      NavEntry(
        path: Routes.materials,
        label: 'Materiais',
        icon: Icons.science_outlined,
        visible: _org,
      ),
      NavEntry(
        path: Routes.brands,
        label: 'Marcas',
        icon: Icons.sell_outlined,
        visible: _org,
      ),
      NavEntry(
        path: Routes.models,
        label: 'Modelos 3D',
        icon: Icons.view_in_ar_outlined,
        visible: _org,
        keywords: ['stl', '3mf', 'fatiador', 'slicer'],
      ),
    ],
  ),
  NavGroup(
    title: 'Presets',
    entries: [
      NavEntry(
        path: Routes.profiles,
        label: 'Perfis de impressão',
        icon: Icons.tune_outlined,
        visible: _org,
      ),
      NavEntry(
        path: Routes.machines,
        label: 'Máquinas',
        icon: Icons.print_outlined,
        visible: _org,
        keywords: ['impressora'],
      ),
      NavEntry(
        path: Routes.energy,
        label: 'Energia',
        icon: Icons.bolt_outlined,
        visible: _org,
        keywords: ['kwh', 'tarifa'],
      ),
      NavEntry(
        path: Routes.costs,
        label: 'Custos',
        icon: Icons.payments_outlined,
        visible: _org,
        keywords: ['margem', 'mão de obra', 'overhead'],
      ),
    ],
  ),
  NavGroup(
    title: 'Configurações',
    entries: [
      NavEntry(
        path: Routes.company,
        label: 'Empresa',
        icon: Icons.storefront_outlined,
        visible: _manage,
      ),
      NavEntry(
        path: Routes.branding,
        label: 'Identidade do PDF',
        icon: Icons.palette_outlined,
        visible: _manage,
        keywords: ['branding', 'cores'],
      ),
      NavEntry(
        path: Routes.users,
        label: 'Usuários',
        icon: Icons.manage_accounts_outlined,
        visible: _manage,
      ),
      NavEntry(
        path: Routes.subscription,
        label: 'Assinatura',
        icon: Icons.workspace_premium_outlined,
        visible: _owner,
        keywords: ['plano', 'pagamento', 'cobrança'],
      ),
    ],
  ),
  NavGroup(
    title: 'Plataforma',
    entries: [
      NavEntry(
        path: Routes.admin,
        label: 'Painel admin',
        icon: Icons.admin_panel_settings_outlined,
        visible: _admin,
      ),
      NavEntry(
        path: Routes.adminCompanies,
        label: 'Empresas',
        icon: Icons.domain_outlined,
        visible: _admin,
      ),
      NavEntry(
        path: Routes.adminSubscriptions,
        label: 'Assinaturas',
        icon: Icons.receipt_long_outlined,
        visible: _admin,
      ),
      NavEntry(
        path: Routes.adminPlans,
        label: 'Planos',
        icon: Icons.layers_outlined,
        visible: _admin,
      ),
    ],
  ),
];

bool _always(SessionUser u) => true;
bool _manage(SessionUser u) => u.canSeeCompanySettings;
bool _owner(SessionUser u) => u.canSeeSubscription;
bool _admin(SessionUser u) => u.canSeeAdmin;

/// Entrada de navegação que melhor corresponde ao caminho atual.
NavEntry? navEntryFor(String location) {
  NavEntry? best;
  for (final g in navigation) {
    for (final e in g.entries) {
      final matches = location == e.path || location.startsWith('${e.path}/');
      if (matches && (best == null || e.path.length > best.path.length)) {
        best = e;
      }
    }
  }
  return best;
}

/// O usuário pode acessar [location]?
bool canAccess(SessionUser user, String location) {
  final entry = navEntryFor(location);
  return entry == null || entry.visible(user);
}
