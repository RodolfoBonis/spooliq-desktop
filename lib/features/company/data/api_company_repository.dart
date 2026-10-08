import 'package:spooliq_desktop/core/network/api_client.dart';
import 'package:spooliq_desktop/core/network/json.dart';
import 'package:spooliq_desktop/features/company/domain/company.dart';
import 'package:spooliq_desktop/features/company/domain/company_repository.dart';

class ApiCompanyRepository implements CompanyRepository {
  const ApiCompanyRepository(this._api);

  final ApiClient _api;

  // As rotas da empresa exigem a barra final.
  @override
  Future<Company> get() async =>
      Company.fromJson(await _api.getJson('/company/'));

  @override
  Future<Company> update(Company company) async => Company.fromJson(
    await _api.putJson('/company/', body: company.toUpdateJson()),
  );

  @override
  Future<String> uploadLogo(String filePath) async {
    final json = await _api.upload(
      '/company/logo',
      field: 'logo',
      filePath: filePath,
    );
    return json.str('logo_url');
  }

  @override
  Future<CompanyBranding> branding() async =>
      CompanyBranding.fromJson(await _api.getJson('/company/branding'));

  @override
  Future<CompanyBranding> updateBranding(CompanyBranding branding) async =>
      CompanyBranding.fromJson(
        await _api.putJson('/company/branding', body: branding.toJson()),
      );

  @override
  Future<List<BrandingTemplate>> brandingTemplates() async {
    final body = await _api.get('/company/branding/templates');
    final raw = body is Map ? (body['data'] ?? body['templates']) : body;
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map) BrandingTemplate.fromJson(Map<String, dynamic>.from(e)),
    ];
  }
}
