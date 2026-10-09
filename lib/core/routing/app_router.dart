import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:spooliq_desktop/app/shell/app_shell.dart';
import 'package:spooliq_desktop/core/routing/routes.dart';
import 'package:spooliq_desktop/features/account/presentation/account_page.dart';
import 'package:spooliq_desktop/features/activity/presentation/activities_page.dart';
import 'package:spooliq_desktop/features/admin/presentation/admin_companies_page.dart';
import 'package:spooliq_desktop/features/admin/presentation/admin_dashboard_page.dart';
import 'package:spooliq_desktop/features/admin/presentation/admin_plans_page.dart';
import 'package:spooliq_desktop/features/admin/presentation/admin_subscriptions_page.dart';
import 'package:spooliq_desktop/features/auth/presentation/login_page.dart';
import 'package:spooliq_desktop/features/auth/presentation/register_page.dart';
import 'package:spooliq_desktop/features/auth/presentation/session_cubit.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_status.dart';
import 'package:spooliq_desktop/features/budgets/presentation/board/budgets_page.dart';
import 'package:spooliq_desktop/features/budgets/presentation/detail/budget_detail_page.dart';
import 'package:spooliq_desktop/features/budgets/presentation/editor/budget_editor_page.dart';
import 'package:spooliq_desktop/features/catalog/presentation/brands_page.dart';
import 'package:spooliq_desktop/features/catalog/presentation/filaments_page.dart';
import 'package:spooliq_desktop/features/catalog/presentation/materials_page.dart';
import 'package:spooliq_desktop/features/company/presentation/branding_page.dart';
import 'package:spooliq_desktop/features/company/presentation/company_settings_page.dart';
import 'package:spooliq_desktop/features/customers/presentation/customer_detail_page.dart';
import 'package:spooliq_desktop/features/customers/presentation/customers_page.dart';
import 'package:spooliq_desktop/features/dashboard/presentation/dashboard_page.dart';
import 'package:spooliq_desktop/features/models3d/presentation/models_page.dart';
import 'package:spooliq_desktop/features/presets/domain/preset.dart';
import 'package:spooliq_desktop/features/presets/presentation/presets_page.dart';
import 'package:spooliq_desktop/features/presets/presentation/profiles_page.dart';
import 'package:spooliq_desktop/features/subscription/presentation/subscription_page.dart';
import 'package:spooliq_desktop/features/users/presentation/users_page.dart';

/// Converte o stream do [SessionCubit] num [Listenable] para o go_router.
class _SessionListenable extends ChangeNotifier {
  _SessionListenable(SessionCubit cubit) {
    _sub = cubit.stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<SessionState> _sub;

  @override
  void dispose() {
    unawaited(_sub.cancel());
    super.dispose();
  }
}

GoRouter buildRouter(SessionCubit session) {
  CustomTransitionPage<void> fade(GoRouterState state, Widget child) =>
      CustomTransitionPage<void>(
        key: state.pageKey,
        child: child,
        transitionDuration: const Duration(milliseconds: 160),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      );

  GoRoute page(String path, Widget Function(GoRouterState s) build) => GoRoute(
    path: path,
    pageBuilder: (_, state) => fade(state, build(state)),
  );

  return GoRouter(
    initialLocation: Routes.dashboard,
    refreshListenable: _SessionListenable(session),
    redirect: (context, state) {
      final s = session.state;
      final location = state.matchedLocation;
      final isPublic = Routes.publicPaths.contains(location);
      if (s.status == SessionStatus.unknown) return null;
      if (!s.isAuthenticated) return isPublic ? null : Routes.login;
      if (isPublic) return Routes.dashboard;
      final user = s.user!;
      if (!canAccess(user, location)) {
        return user.isPlatformAdmin && !user.hasOrganizationAccess
            ? Routes.admin
            : Routes.dashboard;
      }
      return null;
    },
    routes: [
      page(Routes.login, (_) => const LoginPage()),
      page(Routes.register, (_) => const RegisterPage()),
      GoRoute(path: '/', redirect: (_, _) => Routes.dashboard),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: [
          page(Routes.dashboard, (_) => const DashboardPage()),
          page(
            Routes.budgets,
            (s) => BudgetsPage(
              // Recria a página quando o filtro da URL muda.
              key: ValueKey(s.uri.queryParameters['status']),
              initialStatus: switch (s.uri.queryParameters['status']) {
                final v? => BudgetStatus.fromValue(v),
                null => null,
              },
            ),
          ),
          page(
            Routes.budgetNew,
            (s) => BudgetEditorPage(
              customerId: s.uri.queryParameters['customer'],
            ),
          ),
          page(
            '/budgets/:id',
            (s) => BudgetDetailPage(id: s.pathParameters['id']!),
          ),
          page(
            '/budgets/:id/edit',
            (s) => BudgetEditorPage(budgetId: s.pathParameters['id']),
          ),
          page(
            Routes.customers,
            (s) => CustomersPage(
              openCreate: s.uri.queryParameters['new'] == '1',
            ),
          ),
          page(
            '/customers/:id',
            (s) => CustomerDetailPage(id: s.pathParameters['id']!),
          ),
          page(Routes.activities, (_) => const ActivitiesPage()),
          page(
            Routes.filaments,
            (s) => FilamentsPage(
              lowStockOnly: s.uri.queryParameters['low_stock'] == '1',
            ),
          ),
          page(Routes.materials, (_) => const MaterialsPage()),
          page(Routes.brands, (_) => const BrandsPage()),
          page(Routes.models, (_) => const ModelsPage()),
          page(Routes.profiles, (_) => const ProfilesPage()),
          page(
            Routes.machines,
            (_) => const PresetsPage(type: PresetType.machine),
          ),
          page(
            Routes.energy,
            (_) => const PresetsPage(type: PresetType.energy),
          ),
          page(Routes.costs, (_) => const PresetsPage(type: PresetType.cost)),
          page(Routes.company, (_) => const CompanySettingsPage()),
          page(Routes.branding, (_) => const BrandingPage()),
          page(Routes.users, (_) => const UsersPage()),
          page(Routes.account, (_) => const AccountPage()),
          page(Routes.subscription, (_) => const SubscriptionPage()),
          page(Routes.admin, (_) => const AdminDashboardPage()),
          page(Routes.adminCompanies, (_) => const AdminCompaniesPage()),
          page(
            Routes.adminSubscriptions,
            (_) => const AdminSubscriptionsPage(),
          ),
          page(Routes.adminPlans, (_) => const AdminPlansPage()),
        ],
      ),
    ],
  );
}
