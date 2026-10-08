import 'package:spooliq_desktop/core/network/api_client.dart';
import 'package:spooliq_desktop/core/network/json.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/features/customers/domain/customer.dart';
import 'package:spooliq_desktop/features/customers/domain/customer_repository.dart';

class ApiCustomerRepository implements CustomerRepository {
  const ApiCustomerRepository(this._api);

  final ApiClient _api;

  @override
  Future<Paginated<Customer>> list({PageQuery page = const PageQuery()}) async {
    // /customers/search aceita `q` (nome, e-mail, documento…) e ordenação.
    final hasSearch = page.search != null && page.search!.trim().isNotEmpty;
    final body = await _api.get(
      hasSearch ? '/customers/search' : '/customers',
      query: page.toQuery(),
    );
    return Paginated.fromJson(body, Customer.fromJson);
  }

  @override
  Future<Customer> get(String id) async =>
      Customer.fromJson((await _api.getJson('/customers/$id')).unwrapData());

  @override
  Future<Customer> create(CustomerInput input) async => Customer.fromJson(
    await _api.postJson('/customers', body: input.toJson()),
  );

  @override
  Future<Customer> update(String id, CustomerInput input) async =>
      Customer.fromJson(
        await _api.putJson('/customers/$id', body: input.toJson()),
      );

  @override
  Future<void> delete(String id) => _api.delete('/customers/$id');
}
