import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/features/customers/domain/customer.dart';

abstract interface class CustomerRepository {
  Future<Paginated<Customer>> list({PageQuery page = const PageQuery()});

  Future<Customer> get(String id);

  Future<Customer> create(CustomerInput input);

  Future<Customer> update(String id, CustomerInput input);

  Future<void> delete(String id);
}
