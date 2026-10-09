import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/core/update/update_checker.dart';
import 'package:spooliq_desktop/core/update/update_cubit.dart';
import 'package:url_launcher/url_launcher.dart';

/// Faixa "nova versão disponível" no topo do conteúdo.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final update = context.watch<UpdateCubit>().state;
    if (update == null) return const SizedBox.shrink();
    return _Banner(update: update);
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.update});

  final AvailableUpdate update;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final cubit = context.read<UpdateCubit>();
    return Container(
      color: ext.infoSurface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.system_update_alt_rounded, size: 18, color: ext.infoText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Nova versão do SpoolIQ disponível: ${update.version}',
              style: typo.body14Medium.copyWith(color: ext.infoText),
            ),
          ),
          TextButton(
            onPressed: () => unawaited(launchUrl(Uri.parse(update.releaseUrl))),
            child: const Text('Novidades'),
          ),
          TextButton(
            onPressed: () => unawaited(cubit.skip()),
            child: const Text('Ignorar versão'),
          ),
          const SizedBox(width: 4),
          FormaButton.primary(
            label: 'Baixar',
            small: true,
            icon: const Icon(Icons.download_rounded, size: 16),
            onPressed: () => unawaited(
              launchUrl(Uri.parse(update.downloadUrl ?? update.releaseUrl)),
            ),
          ),
          IconButton(
            tooltip: 'Depois',
            icon: Icon(Icons.close_rounded, size: 18, color: ext.infoText),
            onPressed: cubit.dismiss,
          ),
        ],
      ),
    );
  }
}
