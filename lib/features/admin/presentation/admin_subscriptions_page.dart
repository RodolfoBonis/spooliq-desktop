import 'package:flutter/material.dart';
import 'package:spooliq_desktop/features/admin/presentation/admin_companies_page.dart';

/// Assinaturas: mesma tela de empresas, alimentada por `/admin/subscriptions`.
class AdminSubscriptionsPage extends StatelessWidget {
  const AdminSubscriptionsPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const AdminCompaniesPage(subscriptions: true);
}
