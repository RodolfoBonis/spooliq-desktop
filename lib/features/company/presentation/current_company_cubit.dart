import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/features/company/domain/company.dart';
import 'package:spooliq_desktop/features/company/domain/company_repository.dart';

class CurrentCompanyState extends Equatable {
  const CurrentCompanyState({this.company, this.loading = false, this.error});

  final Company? company;
  final bool loading;
  final String? error;

  @override
  List<Object?> get props => [company, loading, error];
}

/// Empresa da sessão (logo/nome no shell, defaults de orçamento).
class CurrentCompanyCubit extends Cubit<CurrentCompanyState> {
  CurrentCompanyCubit(this._repository) : super(const CurrentCompanyState());

  final CompanyRepository _repository;

  Future<void> load() async {
    emit(CurrentCompanyState(company: state.company, loading: true));
    try {
      emit(CurrentCompanyState(company: await _repository.get()));
    } on ApiError catch (e) {
      emit(CurrentCompanyState(company: state.company, error: e.message));
    }
  }

  void replace(Company company) => emit(CurrentCompanyState(company: company));

  void clear() => emit(const CurrentCompanyState());
}
