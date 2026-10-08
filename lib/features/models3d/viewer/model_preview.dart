import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/format/formatters.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/observability/app_logger.dart';
import 'package:spooliq_desktop/features/models3d/domain/model3d.dart';
import 'package:spooliq_desktop/features/models3d/viewer/mesh.dart';
import 'package:spooliq_desktop/features/models3d/viewer/model_viewer.dart';

/// Malha completa + versão simplificada para interação.
typedef LoadedMesh = ({Mesh full, Mesh preview});

/// Executado fora da UI thread (sem capturar contexto de widget).
LoadedMesh _parseInBackground((Uint8List, String) args) {
  final full = parseMesh(args.$1, fileName: args.$2).placedOnPlate();
  return (full: full, preview: full.simplified());
}

/// Cache simples (por sessão) das malhas já baixadas e processadas.
final _cache = <String, LoadedMesh>{};

/// Baixa o arquivo do modelo, processa em uma isolate e exibe em 3D.
class ModelPreview extends StatefulWidget {
  const ModelPreview({
    required this.model,
    this.height = 320,
    this.showToolbar = true,
    super.key,
  });

  final Model3D model;
  final double? height;
  final bool showToolbar;

  @override
  State<ModelPreview> createState() => _ModelPreviewState();
}

class _ModelPreviewState extends State<ModelPreview> {
  LoadedMesh? _mesh;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final id = widget.model.id;
    final cached = _cache[id];
    if (cached != null) {
      setState(() => _mesh = cached);
      return;
    }
    try {
      final bytes = await di<Model3DRepository>().download(id);
      final mesh = await compute(
        _parseInBackground,
        (bytes, widget.model.fileName),
      );
      _cache[id] = mesh;
      if (mounted) setState(() => _mesh = mesh);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Object catch (e, st) {
      unawaited(
        AppLogger.error(e, st, reason: 'parse_model', category: 'models3d'),
      );
      if (mounted) {
        setState(
          () => _error = e is MeshFormatException
              ? e.message
              : 'Não foi possível abrir este arquivo 3D.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final mesh = _mesh;

    final Widget content;
    if (_error != null) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: typo.body13.copyWith(color: ext.textMuted),
          ),
        ),
      );
    } else if (mesh == null) {
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            const SizedBox(height: 10),
            Text(
              'Carregando modelo…',
              style: typo.caption12.copyWith(color: ext.textMuted),
            ),
          ],
        ),
      );
    } else {
      content = Stack(
        children: [
          Positioned.fill(
            child: ModelViewer(mesh: mesh.full, preview: mesh.preview),
          ),
          if (widget.showToolbar)
            Positioned(
              left: 10,
              bottom: 10,
              child: _Chip(
                '${Fmt.number(mesh.full.sizeX, decimals: 1)} × '
                '${Fmt.number(mesh.full.sizeY, decimals: 1)} × '
                '${Fmt.number(mesh.full.sizeZ, decimals: 1)} mm · '
                '${Fmt.plain(mesh.full.triangleCount)} triângulos',
              ),
            ),
          if (widget.showToolbar)
            Positioned(
              right: 8,
              top: 8,
              child: Tooltip(
                message: 'Tela cheia',
                child: IconButton.filledTonal(
                  iconSize: 18,
                  icon: const Icon(Icons.open_in_full_rounded),
                  onPressed: () =>
                      unawaited(showModelViewerDialog(context, widget.model)),
                ),
              ),
            ),
          if (widget.showToolbar)
            const Positioned(
              right: 10,
              bottom: 10,
              child: _Chip(
                'Arraste para girar · scroll para zoom · shift para mover',
              ),
            ),
        ],
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: ext.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: content,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: context.formaTypography.caption12.copyWith(color: Colors.white),
    ),
  );
}

/// Visualização em tela cheia.
Future<void> showModelViewerDialog(BuildContext context, Model3D model) =>
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) {
        final size = MediaQuery.sizeOf(context);
        final typo = context.formaTypography;
        final ext = Theme.of(context).extension<FormaThemeExtension>()!;
        return Dialog(
          insetPadding: const EdgeInsets.all(32),
          child: SizedBox(
            width: size.width - 64,
            height: size.height - 64,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 8, 10),
                  child: Row(
                    children: [
                      Icon(Icons.view_in_ar_outlined, color: ext.accentColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          model.name,
                          style: typo.title16.copyWith(color: ext.textPrimary),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Fechar',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: ModelPreview(model: model, height: null),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
