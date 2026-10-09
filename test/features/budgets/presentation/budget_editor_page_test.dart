import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forma_theme_spooliq/forma_theme_spooliq.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spooliq_desktop/app/theme_mode_cubit.dart';
import 'package:spooliq_desktop/core/auth/session_user.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/core/routing/app_router.dart';
import 'package:spooliq_desktop/core/routing/routes.dart';
import 'package:spooliq_desktop/core/update/update_checker.dart';
import 'package:spooliq_desktop/core/update/update_cubit.dart';
import 'package:spooliq_desktop/features/auth/presentation/session_cubit.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_draft.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_repository.dart';
import 'package:spooliq_desktop/features/budgets/presentation/editor/budget_editor_cubit.dart';
import 'package:spooliq_desktop/features/budgets/presentation/editor/budget_editor_page.dart';
import 'package:spooliq_desktop/features/company/domain/company.dart';
import 'package:spooliq_desktop/features/company/domain/company_repository.dart';
import 'package:spooliq_desktop/features/company/presentation/current_company_cubit.dart';
import 'package:spooliq_desktop/features/customers/domain/customer_repository.dart';
import 'package:spooliq_desktop/features/dashboard/domain/dashboard.dart';
import 'package:spooliq_desktop/features/presets/domain/preset.dart';
import 'package:spooliq_desktop/features/presets/domain/preset_repository.dart';

class _Budgets extends Mock implements BudgetRepository {}

class _Presets extends Mock implements PresetRepository {}

class _Company extends Mock implements CompanyRepository {}

class _Customers extends Mock implements CustomerRepository {}

class _Session extends Mock implements SessionCubit {}

/// Qualquer chamada falha como se estivesse offline.
class _OfflineDashboard implements DashboardRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<Never>.error(const NetworkError());
}

void main() {
  setUpAll(() {
    registerFallbackValue(const BudgetDraft());
    registerFallbackValue(PresetType.machine);
    registerFallbackValue(const PageQuery());
  });

  setUp(() {
    final presets = _Presets();
    final company = _Company();
    final customers = _Customers();
    when(
      () => customers.list(page: any(named: 'page')),
    ).thenAnswer((_) async => const Paginated.empty());
    when(presets.profiles).thenAnswer((_) async => const Paginated.empty());
    when(() => presets.list(any())).thenAnswer((_) async => const []);
    when(
      company.get,
    ).thenAnswer((_) async => const Company(id: 'c', name: 'Loja'));
    di
      ..allowReassignment = true
      ..registerSingleton<BudgetRepository>(_Budgets())
      ..registerSingleton<PresetRepository>(presets)
      ..registerSingleton<CompanyRepository>(company)
      ..registerSingleton<CustomerRepository>(customers)
      ..registerSingleton<DashboardRepository>(_OfflineDashboard());
  });

  testWidgets('can type in the project name field', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = _Session();
    when(() => session.state).thenReturn(const SessionState.unknown());
    when(() => session.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(
      MaterialApp(
        theme: SpooliqTheme.light,
        home: BlocProvider<SessionCubit>.value(
          value: session,
          child: const Scaffold(body: BudgetEditorPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final name = find.widgetWithText(
      TextField,
      'Ex.: Kit organizadores de mesa',
    );
    expect(name, findsOneWidget);
    await tester.tap(name);
    await tester.pump();
    await tester.enterText(name, 'Hulk');
    await tester.pump(const Duration(milliseconds: 500));

    final cubit = tester
        .element(find.text('Informações básicas'))
        .read<BudgetEditorCubit>();
    expect(find.text('Hulk'), findsOneWidget);
    expect(cubit.state.draft.name, 'Hulk');
    expect(
      tester.binding.focusManager.primaryFocus?.context?.widget,
      isNot(isA<FocusScope>()),
    );
  });
  testWidgets('can type in the editor inside the real shell and router', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final session = _Session();
    const user = SessionUser(
      id: 'u',
      email: 'a@b.c',
      name: 'Ana',
      organizationId: 'o',
      roles: {Role.owner},
      expiresAt: null,
    );
    when(
      () => session.state,
    ).thenReturn(const SessionState.authenticated(user));
    when(() => session.stream).thenAnswer((_) => const Stream.empty());
    final router = buildRouter(session);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<SessionCubit>.value(value: session),
          BlocProvider(create: (_) => ThemeModeCubit(prefs)),
          BlocProvider(create: (_) => CurrentCompanyCubit(di())),
          // Sem start(): nenhuma checagem de atualização no teste.
          BlocProvider(
            create: (_) => UpdateCubit(UpdateChecker(feedUrl: ''), prefs),
          ),
        ],
        child: MaterialApp.router(
          theme: SpooliqTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    router.go(Routes.customers);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    router.go(Routes.budgetNew);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final name = find.widgetWithText(
      TextField,
      'Ex.: Kit organizadores de mesa',
    );
    expect(name, findsOneWidget);
    await tester.tap(name);
    await tester.pump();
    final focused = tester.binding.focusManager.primaryFocus;
    expect(
      focused?.context?.findAncestorWidgetOfExactType<EditableText>(),
      isNotNull,
      reason: 'primary focus: $focused',
    );
  });
}
