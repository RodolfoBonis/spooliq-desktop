enum Flavor { development, staging, production }

/// Configuração por flavor, com overrides via `--dart-define`.
///
/// ```sh
/// flutter run -d macos --flavor development -t lib/main_development.dart
/// flutter run -d windows -t lib/main_production.dart \
///   --dart-define=API_BASE_URL=https://api.spooliq.com/v1
/// ```
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.sentryDsn,
    required this.environment,
    required this.publicBudgetBaseUrl,
    this.updateFeedUrl = '',
  });

  /// Valores padrão do flavor, sobrescrevíveis via `--dart-define`.
  factory AppConfig.forFlavor(Flavor flavor) {
    const apiOverride = String.fromEnvironment('API_BASE_URL');
    const publicOverride = String.fromEnvironment('PUBLIC_BUDGET_BASE_URL');
    const updateOverride = String.fromEnvironment('UPDATE_FEED_URL');
    final (api, public) = switch (flavor) {
      Flavor.development => (
        'http://localhost:8080/v1',
        'http://localhost:3000/orcamento',
      ),
      Flavor.staging => (
        'https://api.spooliq.stg.rb.lab/v1',
        'https://spooliq.stg.rb.lab/orcamento',
      ),
      Flavor.production => (
        'https://api.spooliq.com/v1',
        'https://spooliq.com/orcamento',
      ),
    };
    return AppConfig(
      apiBaseUrl: apiOverride.isEmpty ? api : apiOverride,
      sentryDsn: const String.fromEnvironment('SENTRY_DSN'),
      environment: flavor.name,
      publicBudgetBaseUrl: publicOverride.isEmpty ? public : publicOverride,
      // Só builds de produção procuram atualização.
      updateFeedUrl: updateOverride.isNotEmpty
          ? updateOverride
          : flavor == Flavor.production
          ? 'https://api.github.com/repos/RodolfoBonis/spooliq-desktop/releases/latest'
          : '',
    );
  }

  final String apiBaseUrl;
  final String sentryDsn;
  final String environment;

  /// Base da página pública de aprovação (`<base>/<token>`).
  final String publicBudgetBaseUrl;

  /// Última release (GitHub API); vazio = não verificar atualizações.
  final String updateFeedUrl;

  bool get hasSentry => sentryDsn.isNotEmpty;
  bool get checksForUpdates => updateFeedUrl.isNotEmpty;
}
