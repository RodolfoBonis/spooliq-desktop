import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:spooliq_desktop/core/auth/session_user.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/format/formatters.dart';
import 'package:spooliq_desktop/core/observability/app_logger.dart';
import 'package:spooliq_desktop/core/routing/routes.dart';
import 'package:spooliq_desktop/core/ui/feedback.dart';
import 'package:spooliq_desktop/core/ui/page_layout.dart';
import 'package:spooliq_desktop/features/activity/presentation/activity_tile.dart';
import 'package:spooliq_desktop/features/auth/presentation/session_cubit.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_status.dart';
import 'package:spooliq_desktop/features/budgets/presentation/widgets/budget_status_style.dart';
import 'package:spooliq_desktop/features/catalog/presentation/widgets/filament_swatch.dart';
import 'package:spooliq_desktop/features/dashboard/domain/dashboard.dart';
import 'package:spooliq_desktop/features/dashboard/presentation/dashboard_cubit.dart';
import 'package:spooliq_desktop/features/dashboard/presentation/widgets/dashboard_section.dart';
import 'package:spooliq_desktop/features/dashboard/presentation/widgets/goals_card.dart';
import 'package:spooliq_desktop/features/dashboard/presentation/widgets/insights_panel.dart';
import 'package:spooliq_desktop/features/dashboard/presentation/widgets/profitability_card.dart';
import 'package:spooliq_desktop/features/dashboard/presentation/widgets/response_times_card.dart';

const _materialColors = {
  'PLA': Color(0xFF3B82F6),
  'PETG': Color(0xFF8B5CF6),
  'ABS': Color(0xFFEF4444),
  'TPU': Color(0xFFF97316),
  'ASA': Color(0xFFEAB308),
  'NYLON': Color(0xFF22C55E),
  'PC': Color(0xFF06B6D4),
  'HIPS': Color(0xFF84CC16),
  'PVA': Color(0xFFEC4899),
};

/// Cor do material pelo nome ("PLA Premium" → PLA, "PETG HF" → PETG).
Color? _materialColor(String name) {
  final upper = name.toUpperCase();
  final words = upper.split(RegExp('[^A-Z0-9]+'));
  for (final e in _materialColors.entries) {
    if (words.contains(e.key)) return e.value;
  }
  return null;
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.select<SessionCubit, SessionUser?>(
      (c) => c.state.user,
    );
    if (user != null && !user.hasOrganizationAccess) {
      return PageLayout(
        title: 'Visão geral',
        body: Center(
          child: FormaEmptyState(
            icon: Icons.admin_panel_settings_outlined,
            title: 'Você é administrador da plataforma',
            message: 'Os indicadores das empresas ficam no painel admin.',
            action: FormaButton.primary(
              label: 'Abrir painel admin',
              small: true,
              onPressed: () => context.go(Routes.admin),
            ),
          ),
        ),
      );
    }
    return BlocProvider(
      create: (_) {
        final cubit = DashboardCubit(di());
        unawaited(cubit.load());
        return cubit;
      },
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatefulWidget {
  const _DashboardView();

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  final GlobalKey _captureKey = GlobalKey();

  /// Durante a exportação o cabeçalho (período e data) entra na imagem.
  bool _exporting = false;
  DateTime? _exportedAt;

  Future<void> _export(DashboardPeriod period) async {
    final now = DateTime.now();
    setState(() => _exportedAt = now);
    try {
      final location = await getSaveLocation(
        suggestedName:
            'dashboard-${period.value}-${DateFormat('yyyy-MM-dd').format(now)}'
            '.png',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Imagem PNG', extensions: ['png']),
        ],
      );
      if (location == null || !mounted) return;
      // O diálogo do sistema nem sempre acrescenta a extensão.
      final path = location.path.toLowerCase().endsWith('.png')
          ? location.path
          : '${location.path}.png';

      setState(() => _exporting = true);
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _captureKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) {
        throw StateError('Área do dashboard não encontrada para captura.');
      }
      final image = await boundary.toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (png == null) throw StateError('Falha ao codificar o PNG.');
      await File(path).writeAsBytes(png.buffer.asUint8List(), flush: true);
      if (mounted) Toasts.success(context, 'Dashboard exportado');
    } on Object catch (e, st) {
      unawaited(AppLogger.error(e, st, reason: 'dashboard_export'));
      if (mounted) Toasts.error(context, e);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final state = context.watch<DashboardCubit>().state;
    final cubit = context.read<DashboardCubit>();
    final name = context.select<SessionCubit, String>(
      (c) => c.state.user?.name.split(' ').first ?? '',
    );
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Bom dia'
        : hour < 18
        ? 'Boa tarde'
        : 'Boa noite';

    return PageLayout(
      title: '$greeting${name.isEmpty ? '' : ', $name'}',
      subtitle:
          'Como está o seu negócio nos últimos '
          '${state.period.label.toLowerCase()}.',
      actions: [
        _PeriodPicker(value: state.period, onChanged: cubit.load),
        Tooltip(
          message: 'Exportar como imagem (PNG)',
          child: FormaIconButton(
            icon: const Icon(Icons.ios_share_rounded, size: 18),
            onPressed: _exporting || state.anyLoading
                ? null
                : () => unawaited(_export(state.period)),
          ),
        ),
      ],
      scrollable: true,
      body: RepaintBoundary(
        key: _captureKey,
        child: ColoredBox(
          // Fundo opaco: sem ele o PNG sai transparente.
          color: ext.appBackground,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_exporting)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'SpoolIQ · últimos ${state.period.label.toLowerCase()} · '
                    'gerado em ${Fmt.dateTime(_exportedAt)}',
                    style: typo.body14Medium.copyWith(color: ext.textMuted),
                  ),
                ),
              _body(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(DashboardState state) {
    final canManage = context.select<SessionCubit, bool>(
      (c) => c.state.user?.canManage ?? false,
    );
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth > 1300;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Kpis(section: state.overview),
            const SizedBox(height: 16),
            InsightsPanel(
              section: state.insights,
              onOpenGoals: () => openGoalsDialog(context),
            ),
            const SizedBox(height: 16),
            _row(wide, [
              (
                3,
                DashCard(
                  title: 'Receita líquida, custo e lucro',
                  child: _TrendChart(section: state.trend),
                ),
              ),
              (
                2,
                GoalsCard(
                  section: state.goals,
                  canManage: canManage,
                  onEdit: () => openGoalsDialog(context),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            ProfitabilityCard(section: state.profitability),
            const SizedBox(height: 16),
            _row(wide, [
              (
                1,
                DashCard(
                  title: 'Funil de conversão',
                  child: _Funnel(section: state.funnel),
                ),
              ),
              (1, ResponseTimesCard(section: state.responseTimes)),
            ]),
            const SizedBox(height: 16),
            _row(wide, [
              (
                1,
                DashCard(
                  title: 'Estoque baixo',
                  trailing: TextButton(
                    onPressed: () =>
                        context.go('${Routes.filaments}?low_stock=1'),
                    child: const Text('Ver todos'),
                  ),
                  child: _LowStock(section: state.lowStock),
                ),
              ),
              (
                1,
                DashCard(
                  title: 'Consumo por material',
                  child: _Materials(section: state.materials),
                ),
              ),
              (
                1,
                DashCard(
                  title: 'Composição dos custos',
                  child: _Breakdown(section: state.operations),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            DashCard(
              title: 'Atividade recente',
              trailing: TextButton(
                onPressed: () => context.go(Routes.activities),
                child: const Text('Ver tudo'),
              ),
              child: _ActivityFeed(section: state.activity),
            ),
          ],
        );
      },
    );
  }

  static Widget _row(bool wide, List<(int, Widget)> items) {
    if (!wide && items.length > 2) {
      return Column(
        children: [
          _row(true, items.take(2).toList()),
          const SizedBox(height: 16),
          for (final i in items.skip(2)) i.$2,
        ],
      );
    }
    // Sem IntrinsicHeight: gráficos e LayoutBuilder não suportam medidas
    // intrínsecas. Cards alinham pelo topo.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, (flex, w)) in items.indexed) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(flex: flex, child: w),
        ],
      ],
    );
  }
}

class _PeriodPicker extends StatelessWidget {
  const _PeriodPicker({required this.value, required this.onChanged});

  final DashboardPeriod value;
  final Future<void> Function(DashboardPeriod) onChanged;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: ext.appBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ext.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final p in DashboardPeriod.values)
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => unawaited(onChanged(p)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: p == value ? ext.cardBackground : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: p == value
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  p.label,
                  style: typo.caption12Med.copyWith(
                    color: p == value ? ext.textPrimary : ext.textMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.section});

  final Section<Overview> section;

  @override
  Widget build(BuildContext context) {
    final o = section.data;
    String money(int Function(Overview) f) => o == null ? '' : Fmt.cents(f(o));
    final items = [
      _Kpi(
        label: 'Receita líquida',
        value: money((o) => o.netRevenueCents),
        change: o?.netRevenueChange,
        icon: Icons.trending_up_rounded,
        tooltip: 'Vendas aprovadas no período, sem imposto e frete.',
      ),
      _Kpi(
        label: 'Lucro',
        value: money((o) => o.profitCents),
        change: o?.profitChange,
        icon: Icons.savings_outlined,
        detail: o == null
            ? null
            : '${Fmt.cents(o.profitRealizedCents)} realizado · '
                  '${Fmt.cents(o.profitForecastCents)} previsto',
        tooltip:
            'Margem dos orçamentos aprovados menos descontos. Realizado = '
            'concluídos; previsto = aprovados e em impressão.',
      ),
      _Kpi(
        label: 'Margem',
        value: o == null ? '' : Fmt.percent(o.profitMargin),
        change: o?.marginPointsChange,
        points: true,
        icon: Icons.percent_rounded,
        tooltip: 'Lucro ÷ receita líquida (ponderada pelo valor).',
      ),
      _Kpi(
        label: 'Ticket médio',
        value: money((o) => o.avgTicketCents),
        change: o?.avgTicketChange,
        icon: Icons.sell_outlined,
      ),
      _Kpi(
        label: 'Aprovação',
        value: o == null ? '' : Fmt.percent(o.approvalRate),
        change: o?.approvalRateChange,
        icon: Icons.verified_outlined,
        tooltip: 'Aprovados ÷ (aprovados + recusados + expirados).',
      ),
      _Kpi(
        label: 'Lucro por hora',
        value: o == null ? '' : '${Fmt.cents(o.profitPerHourCents)}/h',
        change: o?.profitPerHourChange,
        icon: Icons.schedule_rounded,
        detail: o == null
            ? null
            : '${Fmt.number(o.printHours, decimals: 1)} h de impressão',
        tooltip: 'Lucro ÷ horas de impressão das vendas.',
      ),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (idx, kpi) in items.indexed) ...[
          if (idx > 0) const SizedBox(width: 12),
          Expanded(child: kpi.withLoading(loading: section.loading)),
        ],
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.label,
    required this.value,
    required this.change,
    required this.icon,
    this.loading = false,
    this.inverse = false,
    this.points = false,
    this.detail,
    this.tooltip,
  });

  final String label;
  final String value;
  final double? change;
  final IconData icon;
  final bool loading;

  /// Queda é boa (ex.: custo).
  final bool inverse;

  /// A variação está em pontos percentuais, não em %.
  final bool points;

  /// Linha extra abaixo da variação.
  final String? detail;
  final String? tooltip;

  _Kpi withLoading({required bool loading}) => _Kpi(
    label: label,
    value: value,
    change: change,
    icon: icon,
    loading: loading,
    inverse: inverse,
    points: points,
    detail: detail,
    tooltip: tooltip,
  );

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final c = change;
    final positive = c != null && (inverse ? c < 0 : c > 0);
    final negative = c != null && (inverse ? c > 0 : c < 0);
    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: ext.textHint),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typo.caption12.copyWith(color: ext.textMuted),
                ),
              ),
              if (tooltip != null)
                Tooltip(
                  message: tooltip,
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 13,
                    color: ext.textHint,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (loading)
            const FormaSkeleton.line(height: 24, width: 110)
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value.isEmpty ? '—' : value,
                style: typo.h4.copyWith(
                  color: ext.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          const SizedBox(height: 6),
          if (loading)
            const FormaSkeleton.line(height: 12, width: 140)
          else if (c == null)
            const SizedBox(height: 17)
          else
            Row(
              children: [
                Icon(
                  c == 0
                      ? Icons.remove_rounded
                      : c > 0
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 13,
                  color: positive
                      ? ext.successColor
                      : negative
                      ? ext.errorColor
                      : ext.textHint,
                ),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    points
                        ? '${Fmt.number(c.abs(), decimals: 1)} p.p. '
                              'vs. período anterior'
                        : '${Fmt.percent(c.abs())} vs. período anterior',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typo.caption12.copyWith(
                      color: positive
                          ? ext.successText
                          : negative
                          ? ext.errorText
                          : ext.textHint,
                    ),
                  ),
                ),
              ],
            ),
          if (!loading && detail != null) ...[
            const SizedBox(height: 2),
            Text(
              detail!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typo.caption12.copyWith(color: ext.textHint),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.section});

  final Section<List<TrendPoint>> section;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    return dashSection(context, section, height: 260, (points) {
      if (points.isEmpty) {
        return SizedBox(
          height: 260,
          child: dashEmpty(context, 'Sem dados no período.'),
        );
      }
      final series = [
        ('Receita líquida', ext.primaryColor, (TrendPoint p) => p.revenueCents),
        ('Custo', ext.textHint, (TrendPoint p) => p.costCents),
        ('Lucro', ext.successColor, (TrendPoint p) => p.profitCents),
      ];
      final maxY = points
          .expand((p) => [p.revenueCents, p.costCents, p.profitCents])
          .fold<int>(0, (m, v) => v > m ? v : m);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final (label, color, _) in series) ...[
                Container(
                  width: 10,
                  height: 3,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: typo.caption12.copyWith(color: ext.textMuted),
                ),
                const SizedBox(width: 16),
              ],
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY == 0 ? 100 : maxY * 1.15,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: ext.border, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 64,
                      getTitlesWidget: (v, meta) => v == meta.max
                          ? const SizedBox.shrink()
                          : Text(
                              Fmt.centsCompact(v.round()),
                              style: typo.caption12.copyWith(
                                color: ext.textHint,
                              ),
                            ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (points.length / 6).ceilToDouble().clamp(
                        1,
                        1000,
                      ),
                      getTitlesWidget: (v, _) {
                        final i = v.round();
                        if (i < 0 || i >= points.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            Fmt.dayMonth(points[i].date),
                            style: typo.caption12.copyWith(color: ext.textHint),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) =>
                        ext.surfaceElevated ?? ext.cardBackground,
                    tooltipBorder: BorderSide(color: ext.border),
                    getTooltipItems: (spots) => [
                      for (final s in spots)
                        LineTooltipItem(
                          '${series[s.barIndex].$1}: ${Fmt.cents(s.y.round())}',
                          typo.caption12Med.copyWith(
                            color: series[s.barIndex].$2,
                          ),
                        ),
                    ],
                  ),
                ),
                lineBarsData: [
                  for (final (i, (_, color, value)) in series.indexed)
                    LineChartBarData(
                      spots: [
                        for (final (x, p) in points.indexed)
                          FlSpot(x.toDouble(), value(p).toDouble()),
                      ],
                      isCurved: true,
                      preventCurveOverShooting: true,
                      color: color,
                      barWidth: i == 0 ? 2.5 : 1.8,
                      dotData: FlDotData(show: points.length == 1),
                      belowBarData: BarAreaData(
                        show: i == 0,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            color.withValues(alpha: 0.22),
                            color.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _Funnel extends StatelessWidget {
  const _Funnel({required this.section});

  final Section<List<FunnelStep>> section;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final brightness = Theme.of(context).brightness;
    return dashSection(context, section, height: 260, (steps) {
      if (steps.isEmpty) {
        return dashEmpty(context, 'Sem orçamentos no período.');
      }
      final max = steps.fold<int>(1, (m, s) => s.count > m ? s.count : m);
      return Column(
        children: [
          for (final s in steps)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      s.status.label,
                      style: typo.body13.copyWith(color: ext.textMuted),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) => Align(
                        alignment: Alignment.centerLeft,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                          height: 26,
                          width: (c.maxWidth * s.count / max).clamp(
                            6,
                            c.maxWidth,
                          ),
                          decoration: BoxDecoration(
                            color: BudgetStatusStyle.of(
                              s.status,
                              brightness,
                            ).color.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 84,
                    child: Text.rich(
                      TextSpan(
                        text: '${s.count}',
                        style: typo.body14Medium.copyWith(
                          color: ext.textPrimary,
                        ),
                        children: [
                          if (s.status != BudgetStatus.draft)
                            TextSpan(
                              text: '  ${Fmt.percent(s.rate, decimals: 0)}',
                              style: typo.caption12.copyWith(
                                color: ext.textHint,
                              ),
                            ),
                        ],
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    });
  }
}

class _Materials extends StatelessWidget {
  const _Materials({required this.section});

  final Section<List<RankedItem>> section;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    return dashSection(context, section, (items) {
      final total = items.fold<num>(0, (s, i) => s + i.value);
      if (items.isEmpty || total == 0) {
        return dashEmpty(context, 'Sem consumo no período.');
      }
      Color colorOf(RankedItem i) => _materialColor(i.name) ?? ext.textHint;
      return Row(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 34,
                sections: [
                  for (final i in items)
                    PieChartSectionData(
                      value: i.value.toDouble(),
                      color: colorOf(i),
                      radius: 22,
                      showTitle: false,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                for (final i in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colorOf(i),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            i.name,
                            style: typo.body13.copyWith(color: ext.textPrimary),
                          ),
                        ),
                        Text(
                          Fmt.percent(i.value * 100 / total, decimals: 0),
                          style: typo.caption12.copyWith(color: ext.textMuted),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

class _LowStock extends StatelessWidget {
  const _LowStock({required this.section});

  final Section<List<RankedItem>> section;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    return dashSection(context, section, (items) {
      if (items.isEmpty) return dashEmpty(context, 'Tudo abastecido. 👌');
      return Column(
        children: [
          for (final i in items.take(6))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  FilamentSwatch(colorHex: i.colorHex, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          i.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typo.body13.copyWith(color: ext.textPrimary),
                        ),
                        if (i.subtitle != null && i.subtitle!.isNotEmpty)
                          Text(
                            i.subtitle!,
                            style: typo.caption12.copyWith(color: ext.textHint),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    Fmt.grams(i.value),
                    style: typo.body13.copyWith(
                      color: ext.warningText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    });
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.section});

  final Section<Operations> section;

  static const _colors = [
    Color(0xFF3B82F6),
    Color(0xFFEF4444),
    Color(0xFFEAB308),
    Color(0xFFF97316),
    Color(0xFF8B5CF6),
    Color(0xFFA78BFA),
    Color(0xFF22C55E),
    Color(0xFF06B6D4),
    Color(0xFFEC4899),
    Color(0xFF84CC16),
    Color(0xFF64748B),
  ];

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    return dashSection(context, section, (ops) {
      final entries = ops.breakdown.entries.where((e) => e.value > 0).toList();
      if (entries.isEmpty) return dashEmpty(context, 'Sem custos no período.');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  for (final (i, e) in entries.indexed)
                    Expanded(
                      flex: (e.value * 10).round().clamp(1, 10000),
                      child: Container(color: _colors[i % _colors.length]),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final (i, e) in entries.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _colors[i % _colors.length],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      e.key,
                      style: typo.body13.copyWith(color: ext.textMuted),
                    ),
                  ),
                  Text(
                    Fmt.percent(e.value, decimals: 0),
                    style: typo.body13.copyWith(color: ext.textPrimary),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Taxa de recusa: ${Fmt.percent(ops.rejectionRate)}',
            style: typo.caption12.copyWith(color: ext.textHint),
          ),
        ],
      );
    });
  }
}

class _ActivityFeed extends StatelessWidget {
  const _ActivityFeed({required this.section});

  final Section<List<Activity>> section;

  @override
  Widget build(BuildContext context) {
    return dashSection(context, section, (items) {
      if (items.isEmpty) return dashEmpty(context, 'Nenhuma atividade ainda.');
      return Column(
        children: [for (final a in items) ActivityTile(a)],
      );
    });
  }
}
