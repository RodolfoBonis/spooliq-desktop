import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forma_theme_spooliq/forma_theme_spooliq.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spooliq_desktop/core/network/api_client.dart';
import 'package:spooliq_desktop/features/budgets/data/api_budget_repository.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_repository.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_status.dart';
import 'package:spooliq_desktop/features/customers/data/api_customer_repository.dart';
import 'package:spooliq_desktop/features/customers/domain/customer_repository.dart';
import 'package:spooliq_desktop/features/customers/presentation/customer_import_result.dart';

class _Api extends Mock implements ApiClient {}

void main() {
  late _Api api;

  setUp(() {
    api = _Api();
    when(
      () => api.download(any(), query: any(named: 'query')),
    ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
  });

  test('budget export reuses the list filters', () async {
    await ApiBudgetRepository(api).exportCsv(
      BudgetFilter(
        search: 'vaso',
        status: BudgetStatus.sent,
        from: DateTime(2026, 9),
      ),
    );
    final query =
        verify(
              () => api.download(
                '/budgets/export.csv',
                query: captureAny(named: 'query'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(query['q'], 'vaso');
    expect(query['status'], 'sent');
    expect(query['from'], '2026-09-01');
  });

  test('customer import parses the per-row report', () async {
    when(
      () => api.upload(
        any(),
        field: any(named: 'field'),
        filePath: any(named: 'filePath'),
      ),
    ).thenAnswer(
      (_) async => {
        'created': 1,
        'skipped': 1,
        'failed': 1,
        'rows': [
          {'line': 2, 'status': 'created', 'name': 'Ana'},
          {'line': 3, 'status': 'skipped', 'message': 'Já existe'},
          {'line': 4, 'status': 'error', 'message': 'Nome obrigatório'},
        ],
      },
    );

    final result = await ApiCustomerRepository(api).importCsv('/tmp/c.csv');

    expect(result.created, 1);
    expect(result.problems.map((r) => r.line), [3, 4]);
    verify(
      () => api.upload(
        '/customers/import',
        field: 'file',
        filePath: '/tmp/c.csv',
      ),
    ).called(1);
  });

  testWidgets('import result lists the rows that were not imported', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: SpooliqTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showCustomerImportResult(
                context,
                const CustomerImportResult(
                  created: 2,
                  skipped: 1,
                  failed: 0,
                  rows: [
                    CustomerImportRow(
                      line: 5,
                      status: 'skipped',
                      name: 'Ana',
                      message: 'Já existe um cliente com este e-mail',
                    ),
                  ],
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('2 criado(s)'), findsOneWidget);
    expect(find.text('1 ignorado(s)'), findsOneWidget);
    expect(
      find.text('Linha 5 (Ana): Já existe um cliente com este e-mail'),
      findsOneWidget,
    );
  });
}
