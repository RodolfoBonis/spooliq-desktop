import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/network/network_status.dart';

/// Faixa "sem conexão" enquanto a API não responde. Testa de novo a cada
/// [probeEvery] e some sozinha quando a conexão volta.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({
    required this.status,
    required this.ping,
    this.probeEvery = const Duration(seconds: 15),
    super.key,
  });

  final NetworkStatus status;

  /// Requisição leve que atualiza [status] (ex.: `ApiClient.ping`).
  final Future<void> Function() ping;
  final Duration probeEvery;

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  Timer? _probe;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    widget.status.addListener(_onStatus);
  }

  @override
  void dispose() {
    widget.status.removeListener(_onStatus);
    _probe?.cancel();
    super.dispose();
  }

  void _onStatus() {
    final online = widget.status.online;
    _probe?.cancel();
    if (!online) {
      _probe = Timer.periodic(widget.probeEvery, (_) => unawaited(_ping()));
    }
    setState(() {});
  }

  Future<void> _ping() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      await widget.ping();
    } on ApiError {
      // Continua offline; o status já foi atualizado pelo interceptor.
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.status.online) return const SizedBox.shrink();
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    return Container(
      color: ext.errorSurface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 18, color: ext.errorText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sem conexão com o SpoolIQ. Verifique sua internet; '
              'tentaremos de novo automaticamente.',
              style: typo.body14Medium.copyWith(color: ext.errorText),
            ),
          ),
          FormaButton.secondary(
            label: 'Tentar agora',
            small: true,
            isLoading: _checking,
            onPressed: () => unawaited(_ping()),
          ),
        ],
      ),
    );
  }
}
