import 'package:flutter/material.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/core/format/formatters.dart';
import 'package:spooliq_desktop/features/catalog/presentation/widgets/filament_swatch.dart';
import 'package:spooliq_desktop/features/models3d/domain/model3d.dart';

/// Exibe placas, tempos e filamentos de uma análise do fatiador.
class SliceAnalysisView extends StatelessWidget {
  const SliceAnalysisView({required this.analysis, super.key});

  final SliceAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (analysis.slicer != null)
          Text(
            'Fatiado com ${analysis.slicer}',
            style: typo.caption12.copyWith(color: ext.textHint),
          ),
        for (final w in analysis.warnings)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: ext.warningColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    w,
                    style: typo.caption12.copyWith(color: ext.warningText),
                  ),
                ),
              ],
            ),
          ),
        for (final p in analysis.plates)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ext.appBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ext.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.name.isEmpty ? 'Placa ${p.index}' : p.name,
                        style: typo.body14Medium.copyWith(
                          color: ext.textPrimary,
                        ),
                      ),
                    ),
                    Icon(Icons.schedule_rounded, size: 14, color: ext.textHint),
                    const SizedBox(width: 4),
                    Text(
                      '${Fmt.duration(p.hours, p.minutes)}${p.estimated ? ' (estimado)' : ''}',
                      style: typo.caption12.copyWith(color: ext.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final f in p.filaments)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Text(
                          '#${f.slot}',
                          style: typo.caption12.copyWith(color: ext.textHint),
                        ),
                        const SizedBox(width: 8),
                        FilamentSwatch(colorHex: f.colorHex, size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            f.suggestedName ?? f.material ?? 'Filamento',
                            style: typo.body13.copyWith(color: ext.textPrimary),
                          ),
                        ),
                        Text(
                          Fmt.grams(f.grams),
                          style: typo.body13.copyWith(color: ext.textMuted),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
