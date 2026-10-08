import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spooliq_desktop/core/auth/token_store.dart';
import 'package:spooliq_desktop/core/config/app_config.dart';
import 'package:spooliq_desktop/core/network/api_client.dart';
import 'package:spooliq_desktop/core/network/session_events.dart';
import 'package:spooliq_desktop/features/admin/data/api_admin_repository.dart';
import 'package:spooliq_desktop/features/admin/domain/admin.dart';
import 'package:spooliq_desktop/features/auth/data/api_auth_repository.dart';
import 'package:spooliq_desktop/features/auth/domain/auth_repository.dart';
import 'package:spooliq_desktop/features/budgets/data/api_budget_repository.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_repository.dart';
import 'package:spooliq_desktop/features/catalog/data/api_catalog_repository.dart';
import 'package:spooliq_desktop/features/catalog/domain/catalog_repository.dart';
import 'package:spooliq_desktop/features/company/data/api_company_repository.dart';
import 'package:spooliq_desktop/features/company/domain/company_repository.dart';
import 'package:spooliq_desktop/features/customers/data/api_customer_repository.dart';
import 'package:spooliq_desktop/features/customers/domain/customer_repository.dart';
import 'package:spooliq_desktop/features/dashboard/data/api_dashboard_repository.dart';
import 'package:spooliq_desktop/features/dashboard/domain/dashboard.dart';
import 'package:spooliq_desktop/features/models3d/data/api_model3d_repository.dart';
import 'package:spooliq_desktop/features/models3d/domain/model3d.dart';
import 'package:spooliq_desktop/features/presets/data/api_preset_repository.dart';
import 'package:spooliq_desktop/features/presets/domain/preset_repository.dart';
import 'package:spooliq_desktop/features/subscription/data/api_billing_repository.dart';
import 'package:spooliq_desktop/features/subscription/domain/billing.dart';
import 'package:spooliq_desktop/features/users/data/api_user_repository.dart';
import 'package:spooliq_desktop/features/users/domain/app_user.dart';

final GetIt di = GetIt.instance;

/// Raiz de composição. Repositórios são registrados pela interface para
/// que os testes possam substituí-los.
Future<void> configureDependencies(AppConfig config) async {
  final prefs = await SharedPreferences.getInstance();
  final tokens = SecureTokenStore();
  final events = SessionEvents();
  final api = ApiClient(
    baseUrl: config.apiBaseUrl,
    tokens: tokens,
    events: events,
  );

  di
    ..registerSingleton<AppConfig>(config)
    ..registerSingleton<SharedPreferences>(prefs)
    ..registerSingleton<TokenStore>(tokens)
    ..registerSingleton<SessionEvents>(events)
    ..registerSingleton<ApiClient>(api)
    ..registerLazySingleton<AuthRepository>(
      () => ApiAuthRepository(api: api, tokens: tokens),
    )
    ..registerLazySingleton<BudgetRepository>(() => ApiBudgetRepository(api))
    ..registerLazySingleton<CustomerRepository>(
      () => ApiCustomerRepository(api),
    )
    ..registerLazySingleton<CatalogRepository>(() => ApiCatalogRepository(api))
    ..registerLazySingleton<PresetRepository>(() => ApiPresetRepository(api))
    ..registerLazySingleton<CompanyRepository>(() => ApiCompanyRepository(api))
    // (customers/catalog registrations)
    ..registerLazySingleton<UserRepository>(() => ApiUserRepository(api))
    // (settings registrations)
    ..registerLazySingleton<DashboardRepository>(
      () => ApiDashboardRepository(api),
    )
    ..registerLazySingleton<BillingRepository>(
      () => ApiBillingRepository(api),
    )
    ..registerLazySingleton<AdminRepository>(() => ApiAdminRepository(api))
    ..registerLazySingleton<Model3DRepository>(
      () => ApiModel3DRepository(api),
    )
  // (insights registrations)
  ;
}
