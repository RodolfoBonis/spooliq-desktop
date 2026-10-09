import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forma_theme_spooliq/forma_theme_spooliq.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spooliq_desktop/core/auth/session_user.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/features/auth/presentation/session_cubit.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_repository.dart';
import 'package:spooliq_desktop/features/customers/domain/customer.dart';
import 'package:spooliq_desktop/features/customers/domain/customer_repository.dart';
import 'package:spooliq_desktop/features/customers/presentation/customer_detail_page.dart';
import 'package:spooliq_desktop/features/models3d/domain/model3d.dart';

import '../../helpers/fixtures.dart';

class _Customers extends Mock implements CustomerRepository {}

class _Budgets extends Mock implements BudgetRepository {}

class _Models extends Mock implements Model3DRepository {}

class _Session extends Mock implements SessionCubit {}

Paginated<T> _page<T>(List<T> items) => Paginated(
  items: items,
  total: items.length,
  page: 1,
  pageSize: 100,
  totalPages: 1,
);

void main() {
  late _Customers customers;
  late _Budgets budgets;
  late _Models models;

  setUpAll(() {
    registerFallbackValue(const PageQuery());
    registerFallbackValue(const BudgetFilter());
  });

  setUp(() {
    customers = _Customers();
    budgets = _Budgets();
    models = _Models();
    di
      ..allowReassignment = true
      ..registerSingleton<CustomerRepository>(customers)
      ..registerSingleton<BudgetRepository>(budgets)
      ..registerSingleton<Model3DRepository>(models);
    when(
      () => customers.get('c1'),
    ).thenAnswer((_) async => const Customer(id: 'c1', name: 'Ana Souza'));
    when(
      () => budgets.list(
        filter: any(named: 'filter'),
        page: any(named: 'page'),
      ),
    ).thenAnswer((_) async => _page([Budget.fromJson(budgetJson())]));
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = _Session();
    when(() => session.state).thenReturn(
      const SessionState.authenticated(
        SessionUser(
          id: 'u',
          email: 'a@b.c',
          name: 'Ana',
          organizationId: 'o',
          roles: {Role.owner},
          expiresAt: null,
        ),
      ),
    );
    when(() => session.stream).thenAnswer((_) => const Stream.empty());
    await tester.pumpWidget(
      MaterialApp(
        theme: SpooliqTheme.light,
        home: BlocProvider<SessionCubit>.value(
          value: session,
          child: const Scaffold(body: CustomerDetailPage(id: 'c1')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('lists the customer models with actions', (tester) async {
    when(
      () => models.list(
        customerId: 'c1',
        page: any(named: 'page'),
      ),
    ).thenAnswer(
      (_) async => _page([
        Model3D.fromJson(const {
          'id': 'm1',
          'name': 'Vaso Voronoi',
          'file_name': 'vaso.3mf',
          'file_format': '.3mf',
          'file_size_bytes': 2048,
          'tags': 'decoração',
          'customer_id': 'c1',
        }),
      ]),
    );

    await pump(tester);

    expect(find.text('Ana Souza'), findsWidgets);
    expect(find.text('Modelos 3D'), findsOneWidget);
    expect(find.text('Vaso Voronoi'), findsOneWidget);
    expect(find.text('3MF'), findsOneWidget);
    // Menu por orçamento (ações rápidas) + menu do modelo.
    expect(find.byType(FormaMenuButton), findsAtLeastNWidgets(2));
  });

  testWidgets('offers an upload when the customer has no models', (
    tester,
  ) async {
    when(
      () => models.list(
        customerId: 'c1',
        page: any(named: 'page'),
      ),
    ).thenAnswer((_) async => _page(const <Model3D>[]));

    await pump(tester);

    expect(find.text('Nenhum modelo deste cliente'), findsOneWidget);
    expect(find.text('Enviar modelo'), findsOneWidget);
  });
}
