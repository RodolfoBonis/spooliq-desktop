import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_draft.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_repository.dart';
import 'package:spooliq_desktop/features/budgets/presentation/editor/budget_editor_cubit.dart';
import 'package:spooliq_desktop/features/company/domain/company.dart';
import 'package:spooliq_desktop/features/company/domain/company_repository.dart';
import 'package:spooliq_desktop/features/customers/domain/customer_repository.dart';
import 'package:spooliq_desktop/features/presets/domain/preset.dart';
import 'package:spooliq_desktop/features/presets/domain/preset_repository.dart';

import '../../../helpers/fixtures.dart';

class _Budgets extends Mock implements BudgetRepository {}

class _Presets extends Mock implements PresetRepository {}

class _Company extends Mock implements CompanyRepository {}

class _Customers extends Mock implements CustomerRepository {}

void main() {
  late _Budgets budgets;
  late _Presets presets;
  late _Company company;

  setUpAll(() {
    registerFallbackValue(const BudgetDraft());
    registerFallbackValue(PresetType.machine);
  });

  setUp(() {
    budgets = _Budgets();
    presets = _Presets();
    company = _Company();
    when(() => presets.profiles()).thenAnswer(
      (_) async => const Paginated(
        items: [
          PrintProfile(id: 'p-default', name: 'P1S', isDefault: true),
          PrintProfile(id: 'p-2', name: 'A1', isDefault: false),
        ],
        total: 2,
        page: 1,
        pageSize: 100,
        totalPages: 1,
      ),
    );
    when(() => presets.list(any())).thenAnswer((_) async => const []);
    when(() => company.get()).thenAnswer(
      (_) async => const Company(
        id: 'co',
        name: 'Loja',
        defaultPaymentTerms: '50% na aprovação',
      ),
    );
  });

  BudgetEditorCubit build({String? id}) => BudgetEditorCubit(
    budgets: budgets,
    presets: presets,
    company: company,
    customers: _Customers(),
    budgetId: id,
    previewDebounce: const Duration(milliseconds: 10),
  );

  const filled = BudgetItemDraft(
    key: 0,
    productName: 'Vaso',
    filaments: [FilamentUsageDraft(filamentId: 'f-1', grams: 50)],
  );

  blocTest<BudgetEditorCubit, BudgetEditorState>(
    'new budget preselects the default profile and company payment terms',
    build: build,
    act: (c) => c.load(),
    verify: (c) {
      expect(c.state.status, EditorStatus.ready);
      expect(c.state.draft.profileId, 'p-default');
      expect(c.state.draft.paymentTerms, '50% na aprovação');
      verifyNever(() => budgets.preview(any()));
    },
  );

  blocTest<BudgetEditorCubit, BudgetEditorState>(
    'debounces preview to a single request for rapid edits',
    build: build,
    setUp: () => when(
      () => budgets.preview(any()),
    ).thenAnswer((_) async => Budget.fromJson(budgetJson())),
    act: (c) async {
      await c.load();
      c
        ..updateItem(0, (_) => filled)
        ..updateItem(0, (i) => i.copyWith(quantity: 2))
        ..updateItem(0, (i) => i.copyWith(quantity: 3));
      await Future<void>.delayed(const Duration(milliseconds: 60));
    },
    verify: (c) {
      verify(() => budgets.preview(any())).called(1);
      expect(c.state.preview?.totalCents, 25990);
      expect(c.state.previewing, isFalse);
      expect(c.state.dirty, isTrue);
    },
  );

  blocTest<BudgetEditorCubit, BudgetEditorState>(
    'save shows validation errors without calling the API',
    build: build,
    act: (c) async {
      await c.load();
      expect(await c.save(), isNull);
    },
    verify: (c) {
      expect(c.state.errors, contains('name'));
      verifyNever(() => budgets.create(any()));
    },
  );

  blocTest<BudgetEditorCubit, BudgetEditorState>(
    'save creates the budget when valid',
    build: build,
    setUp: () {
      when(
        () => budgets.preview(any()),
      ).thenAnswer((_) async => Budget.fromJson(budgetJson()));
      when(
        () => budgets.create(any()),
      ).thenAnswer((_) async => Budget.fromJson(budgetJson(id: 'new')));
    },
    act: (c) async {
      await c.load();
      c.update(
        (d) => d.copyWith(
          name: 'Vasos',
          customerId: () => 'c-1',
          items: [filled],
        ),
      );
      final saved = await c.save();
      expect(saved?.id, 'new');
    },
    verify: (c) {
      expect(c.state.status, EditorStatus.saved);
      expect(c.state.dirty, isFalse);
    },
  );

  blocTest<BudgetEditorCubit, BudgetEditorState>(
    'editing a non-draft budget fails with a helpful message',
    build: () => build(id: 'b-1'),
    setUp: () => when(() => budgets.get('b-1')).thenAnswer(
      (_) async => Budget.fromJson(budgetJson(status: 'sent')),
    ),
    act: (c) => c.load(),
    verify: (c) {
      expect(c.state.status, EditorStatus.failure);
      expect(c.state.loadError, contains('rascunhos'));
    },
  );

  blocTest<BudgetEditorCubit, BudgetEditorState>(
    'preview errors are surfaced without breaking the form',
    build: build,
    setUp: () => when(
      () => budgets.preview(any()),
    ).thenThrow(const BusinessError('Filamento inexistente')),
    act: (c) async {
      await c.load();
      c.updateItem(0, (_) => filled);
      await Future<void>.delayed(const Duration(milliseconds: 40));
    },
    verify: (c) {
      expect(c.state.previewError, 'Filamento inexistente');
      expect(c.state.status, EditorStatus.ready);
    },
  );
}
