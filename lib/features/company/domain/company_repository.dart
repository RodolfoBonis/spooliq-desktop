import 'package:spooliq_desktop/features/company/domain/company.dart';

abstract interface class CompanyRepository {
  Future<Company> get();
  Future<Company> update(Company company);
  Future<String> uploadLogo(String filePath);
  Future<CompanyBranding> branding();
  Future<CompanyBranding> updateBranding(CompanyBranding branding);
  Future<List<BrandingTemplate>> brandingTemplates();
}
