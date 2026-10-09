import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/features/company/domain/company.dart';
import 'package:spooliq_desktop/features/company/domain/company_repository.dart';
import 'package:spooliq_desktop/features/company/presentation/current_company_cubit.dart';

class _Repo extends Mock implements CompanyRepository {}

final _company = Company.fromJson(const {'id': 'c', 'name': 'Artesier'});

void main() {
  late _Repo repo;

  setUp(() => repo = _Repo());

  blocTest<CurrentCompanyCubit, CurrentCompanyState>(
    'loads the company',
    setUp: () => when(() => repo.get()).thenAnswer((_) async => _company),
    build: () => CurrentCompanyCubit(repo),
    act: (c) => c.load(),
    expect: () => [
      const CurrentCompanyState(loading: true),
      CurrentCompanyState(company: _company),
    ],
  );

  blocTest<CurrentCompanyCubit, CurrentCompanyState>(
    'keeps the last company when reloading fails',
    setUp: () =>
        when(() => repo.get()).thenThrow(const NetworkError('offline')),
    build: () => CurrentCompanyCubit(repo),
    seed: () => CurrentCompanyState(company: _company),
    act: (c) => c.load(),
    expect: () => [
      CurrentCompanyState(company: _company, loading: true),
      CurrentCompanyState(company: _company, error: 'offline'),
    ],
  );

  blocTest<CurrentCompanyCubit, CurrentCompanyState>(
    'clears on logout',
    build: () => CurrentCompanyCubit(repo),
    seed: () => CurrentCompanyState(company: _company),
    act: (c) => c.clear(),
    expect: () => [const CurrentCompanyState()],
  );
}
