import 'package:flutter/material.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:spooliq_desktop/core/config/app_config.dart';
import 'package:spooliq_desktop/core/di/injector.dart';

/// Versão do app e ambiente, para suporte e relatos de bug.
Future<void> showAboutSpoolIQ(BuildContext context) async {
  final info = await PackageInfo.fromPlatform();
  if (!context.mounted) return;
  final config = di<AppConfig>();
  await FormaDialog.show<void>(
    context,
    title: 'SpoolIQ',
    width: 420,
    child: _AboutBody(
      version: '${info.version} (${info.buildNumber})',
      environment: config.environment,
      api: config.apiBaseUrl,
    ),
  );
}

class _AboutBody extends StatelessWidget {
  const _AboutBody({
    required this.version,
    required this.environment,
    required this.api,
  });

  final String version;
  final String environment;
  final String api;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Image.asset('assets/brand/app_icon_1024.png', width: 64, height: 64),
        const SizedBox(height: 12),
        Text(
          'Orçamentos de impressão 3D',
          textAlign: TextAlign.center,
          style: typo.body14.copyWith(color: ext.textMuted),
        ),
        const SizedBox(height: 20),
        for (final (label, value) in [
          ('Versão', version),
          ('Ambiente', environment),
          ('API', api),
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    label,
                    style: typo.body13.copyWith(color: ext.textMuted),
                  ),
                ),
                Expanded(
                  child: SelectableText(
                    value,
                    style: typo.body13.copyWith(color: ext.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: FormaButton.secondary(
            label: 'Fechar',
            small: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}
