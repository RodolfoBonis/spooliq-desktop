import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/format/formatters.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/ui/feedback.dart';
import 'package:spooliq_desktop/features/catalog/presentation/widgets/filament_swatch.dart';
import 'package:spooliq_desktop/features/models3d/domain/model3d.dart';

/// Resultado da importação: placas escolhidas + nome sugerido do produto.
class SlicerImport {
  const SlicerImport({
    required this.plates,
    required this.fileName,
    required this.filePath,
  });

  final List<SlicePlate> plates;
  final String fileName;
  final String filePath;

  /// A biblioteca de modelos aceita STL e 3MF (inclui `.gcode.3mf`).
  bool get canSaveToLibrary => fileName.toLowerCase().endsWith('.3mf');

  String get productName => fileName
      .replaceAll(
        RegExp(r'\.(gcode\.3mf|3mf|gcode)$', caseSensitive: false),
        '',
      )
      .replaceAll(RegExp('[_-]+'), ' ')
      .trim();
}

/// Escolhe um arquivo do fatiador, analisa no backend e deixa o usuário
/// selecionar as placas. Retorna `null` se cancelado ou com erro.
Future<SlicerImport?> pickSlicerFile(BuildContext context) async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'Arquivos do fatiador',
        extensions: ['gcode', '3mf'],
      ),
    ],
  );
  if (file == null || !context.mounted) return null;

  SliceAnalysis analysis;
  try {
    analysis =
        await FormaDialog.show<SliceAnalysis>(
          context,
          title: 'Importando do fatiador',
          description: file.name,
          barrierDismissible: false,
          child: _AnalyzeProgress(path: file.path),
        ) ??
        const SliceAnalysis(plates: []);
  } on ApiError catch (e) {
    if (context.mounted) Toasts.error(context, e);
    return null;
  }
  if (!context.mounted || analysis.plates.isEmpty) return null;

  if (analysis.plates.length == 1) {
    return SlicerImport(
      plates: analysis.plates,
      fileName: file.name,
      filePath: file.path,
    );
  }
  final plates = await FormaDialog.show<List<SlicePlate>>(
    context,
    title: 'Escolha as placas',
    description:
        'O arquivo tem ${analysis.plates.length} placas. As selecionadas '
        'serão somadas neste item.',
    width: 560,
    child: _PlatePicker(analysis: analysis),
  );
  if (plates == null || plates.isEmpty) return null;
  return SlicerImport(
    plates: plates,
    fileName: file.name,
    filePath: file.path,
  );
}

/// Faz a análise dentro do diálogo e fecha com o resultado.
class _AnalyzeProgress extends StatefulWidget {
  const _AnalyzeProgress({required this.path});

  final String path;

  @override
  State<_AnalyzeProgress> createState() => _AnalyzeProgressState();
}

class _AnalyzeProgressState extends State<_AnalyzeProgress> {
  String? _error;
  int _sent = 0;
  int _total = 0;

  bool get _uploaded => _total > 0 && _sent >= _total;

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _run() async {
    try {
      final result = await di<Model3DRepository>().analyzeFile(
        widget.path,
        onProgress: (sent, total) {
          if (mounted) {
            setState(() {
              _sent = sent;
              _total = total;
            });
          }
        },
      );
      if (mounted) Navigator.of(context).pop(result);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  static String _mb(int bytes) => Fmt.number(bytes / (1 << 20), decimals: 1);

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_error!, style: typo.body14.copyWith(color: ext.errorColor)),
          const SizedBox(height: 16),
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

    final progress = _total == 0 ? null : _sent / _total;
    final (label, detail) = _uploaded
        ? (
            'Analisando no servidor…',
            'Lendo placas, tempos e filamentos do fatiamento.',
          )
        : (
            progress == null
                ? 'Enviando arquivo…'
                : 'Enviando arquivo… ${(progress * 100).round()}%',
            _total == 0 ? '' : '${_mb(_sent)} de ${_mb(_total)} MB',
          );

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: typo.body14Medium.copyWith(color: ext.textPrimary),
                ),
              ),
              if (!_uploaded && detail.isNotEmpty)
                Text(
                  detail,
                  style: typo.caption12.copyWith(
                    color: ext.textMuted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              // Avanço suave entre os eventos de progresso do upload.
              tween: Tween(end: _uploaded ? 1 : (progress ?? 0)),
              duration: const Duration(milliseconds: 200),
              builder: (context, value, _) => LinearProgressIndicator(
                // Indeterminada enquanto o servidor processa.
                value: _uploaded || progress == null ? null : value,
                minHeight: 6,
                backgroundColor: ext.primarySurface,
                color: ext.primaryColor,
              ),
            ),
          ),
          if (_uploaded) ...[
            const SizedBox(height: 10),
            Text(detail, style: typo.caption12.copyWith(color: ext.textMuted)),
          ],
        ],
      ),
    );
  }
}

double _plateGrams(SlicePlate p) =>
    p.filaments.fold<double>(0, (s, f) => s + f.grams);

class _PlatePicker extends StatefulWidget {
  const _PlatePicker({required this.analysis});

  final SliceAnalysis analysis;

  @override
  State<_PlatePicker> createState() => _PlatePickerState();
}

class _PlatePickerState extends State<_PlatePicker> {
  late final Set<int> _selected = {
    for (final p in widget.analysis.plates) p.index,
  };

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final plates = widget.analysis.plates;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in plates)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: FormaCheckbox(
                    value: _selected.contains(p.index),
                    label: p.name.isEmpty ? 'Placa ${p.index}' : p.name,
                    description:
                        '${Fmt.duration(p.hours, p.minutes)} · '
                        '${Fmt.grams(_plateGrams(p))}',
                    onChanged: (v) => setState(
                      () => v
                          ? _selected.add(p.index)
                          : _selected.remove(p.index),
                    ),
                  ),
                ),
                for (final f in p.filaments.take(6))
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: FilamentSwatch(colorHex: f.colorHex, size: 14),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              '${_selected.length} de ${plates.length} selecionadas',
              style: typo.caption12.copyWith(color: ext.textMuted),
            ),
            const Spacer(),
            FormaButton.secondary(
              label: 'Cancelar',
              small: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 8),
            FormaButton.primary(
              label: 'Importar',
              small: true,
              onPressed: _selected.isEmpty
                  ? null
                  : () => Navigator.of(context).pop([
                      for (final p in plates)
                        if (_selected.contains(p.index)) p,
                    ]),
            ),
          ],
        ),
      ],
    );
  }
}
