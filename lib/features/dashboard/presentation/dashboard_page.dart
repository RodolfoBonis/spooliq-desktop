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
import 'package:spooliq_desktop/features/auth/presentation/session_cubit.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_status.dart';
import 'package:spooliq_desktop/features/budgets/presentation/widgets/budget_status_style.dart';
import 'package:spooliq_desktop/features/catalog/presentation/widgets/filament_swatch.dart';
import 'package:spooliq_desktop/features/dashboard/domain/dashboard.dart';
import 'package:spooliq_desktop/features/dashboard/presentation/dashboard_cubit.dart';

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
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth > 1300;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Kpis(section: state.overview, insights: state.insights),
            const SizedBox(height: 16),
            _row(wide, [
              (
                3,
                _Card(
                  title: 'Receita, custo e lucro',
                  child: _TrendChart(section: state.trend),
                ),
              ),
              (
                2,
                _Card(
                  title: 'Funil de conversão',
                  child: _Funnel(section: state.funnel),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            _row(wide, [
              (
                1,
                _Card(
                  title: 'Melhores clientes',
                  child: _Ranked(
                    section: state.customers,
                    money: true,
                    onTap: (id) => context.go(Routes.customer(id)),
                  ),
                ),
              ),
              (
                1,
                _Card(
                  title: 'Filamentos mais usados',
                  child: _Ranked(section: state.filaments, swatch: true),
                ),
              ),
              (
                1,
                _Card(
                  title: 'Materiais',
                  child: _Materials(section: state.materials),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            _row(wide, [
              (
                1,
                _Card(
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
                _Card(
                  title: 'Metas e alertas',
                  child: _Goals(section: state.goals),
                ),
              ),
              (
                1,
                _Card(
                  title: 'Custos médios',
                  child: _Breakdown(section: state.insights),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            _Card(
              title: 'Atividade recente',
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

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) =>
      SectionCard(title: title, trailing: trailing, child: child);
}

/// Conteúdo padrão de uma seção: skeleton, erro ou dados.
Widget _section<T>(
  BuildContext context,
  Section<T> s,
  Widget Function(T data) builder, {
  double height = 180,
}) {
  final ext = Theme.of(context).extension<FormaThemeExtension>()!;
  final typo = context.formaTypography;
  if (s.loading) return FormaSkeleton.box(height: height);
  if (s.error != null) {
    return SizedBox(
      height: height,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 16, color: ext.textHint),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                s.error!,
                style: typo.caption12.copyWith(color: ext.textMuted),
              ),
            ),
            TextButton(
              onPressed: () => unawaited(context.read<DashboardCubit>().load()),
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
  return builder(s.data as T);
}

Widget _emptyText(BuildContext context, String text) {
  final ext = Theme.of(context).extension<FormaThemeExtension>()!;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Center(
      child: Text(
        text,
        style: context.formaTypography.body13.copyWith(color: ext.textHint),
      ),
    ),
  );
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.section, required this.insights});

  final Section<Overview> section;
  final Section<Insights> insights;

  @override
  Widget build(BuildContext context) {
    final o = section.data;
    final i = insights.data;
    final items = <(String, String, double?, IconData, bool)>[
      (
        'Receita',
        o == null ? '' : Fmt.cents(o.revenueCents),
        o?.revenueChange,
        Icons.trending_up_rounded,
        false,
      ),
      (
        'Orçamentos',
        o == null ? '' : '${o.budgets}',
        o?.budgetsChange,
        Icons.request_quote_outlined,
        false,
      ),
      (
        'Ticket médio',
        o == null ? '' : Fmt.cents(o.avgTicketCents),
        o?.avgTicketChange,
        Icons.sell_outlined,
        false,
      ),
      (
        'Aprovação',
        o == null ? '' : Fmt.percent(o.approvalRate),
        o?.approvalRateChange,
        Icons.verified_outlined,
        false,
      ),
      (
        'Margem média',
        o == null ? '' : Fmt.percent(o.profitMargin),
        o?.profitMarginChange,
        Icons.savings_outlined,
        false,
      ),
      (
        'Horas de impressão',
        i == null ? '' : Fmt.number(i.printHours),
        i?.printTimeChange,
        Icons.schedule_rounded,
        false,
      ),
    ];
    return Row(
      children: [
        for (final (idx, (label, value, change, icon, inverse))
            in items.indexed) ...[
          if (idx > 0) const SizedBox(width: 12),
          Expanded(
            child: _Kpi(
              label: label,
              value: value,
              change: change,
              icon: icon,
              inverse: inverse,
              loading: idx == 5 ? insights.loading : section.loading,
            ),
          ),
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
    required this.loading,
    this.inverse = false,
  });

  final String label;
  final String value;
  final double? change;
  final IconData icon;
  final bool loading;
  final bool inverse;

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
                    '${Fmt.percent(c.abs())} vs. período anterior',
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
    return _section(context, section, height: 260, (points) {
      if (points.isEmpty) {
        return SizedBox(
          height: 260,
          child: _emptyText(context, 'Sem dados no período.'),
        );
      }
      final series = [
        ('Receita', ext.primaryColor, (TrendPoint p) => p.revenueCents),
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
    return _section(context, section, height: 260, (steps) {
      if (steps.isEmpty) {
        return _emptyText(context, 'Sem orçamentos no período.');
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

class _Ranked extends StatelessWidget {
  const _Ranked({
    required this.section,
    this.money = false,
    this.swatch = false,
    this.onTap,
  });

  final Section<List<RankedItem>> section;
  final bool money;
  final bool swatch;
  final void Function(String id)? onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    return _section(context, section, (items) {
      if (items.isEmpty) return _emptyText(context, 'Sem dados no período.');
      final max = items.fold<num>(1, (m, i) => i.value > m ? i.value : m);
      return Column(
        children: [
          for (final (idx, i) in items.indexed)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap == null ? null : () => onTap!(i.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (swatch)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilamentSwatch(
                              colorHex: i.colorHex,
                            ),
                          )
                        else
                          SizedBox(
                            width: 22,
                            child: Text(
                              '${idx + 1}',
                              style: typo.caption12Med.copyWith(
                                color: ext.textHint,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            i.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: typo.body13.copyWith(color: ext.textPrimary),
                          ),
                        ),
                        Text(
                          money
                              ? Fmt.cents(i.value.toInt())
                              : Fmt.grams(i.value),
                          style: typo.body13.copyWith(
                            color: ext.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: i.value / max,
                        minHeight: 4,
                        backgroundColor: ext.appBackground,
                        color: ext.primaryColor.withValues(alpha: 0.75),
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

class _Materials extends StatelessWidget {
  const _Materials({required this.section});

  final Section<List<RankedItem>> section;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    return _section(context, section, (items) {
      final total = items.fold<num>(0, (s, i) => s + i.value);
      if (items.isEmpty || total == 0) {
        return _emptyText(context, 'Sem consumo no período.');
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
    return _section(context, section, (items) {
      if (items.isEmpty) return _emptyText(context, 'Tudo abastecido. 👌');
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

class _Goals extends StatelessWidget {
  const _Goals({required this.section});

  final Section<(List<Goal>, List<DashboardAlert>)> section;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    return _section(context, section, (data) {
      final (goals, alerts) = data;
      if (goals.isEmpty && alerts.isEmpty) {
        return _emptyText(context, 'Nada que exija atenção.');
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final g in goals)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          g.name,
                          style: typo.body13.copyWith(color: ext.textPrimary),
                        ),
                      ),
                      Text(
                        Fmt.percent(g.progress, decimals: 0),
                        style: typo.caption12Med.copyWith(color: ext.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: (g.progress / 100).clamp(0, 1),
                      minHeight: 6,
                      backgroundColor: ext.appBackground,
                      color: g.progress >= 100
                          ? ext.successColor
                          : ext.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          for (final a in alerts)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: a.severity == 'high' || a.severity == 'critical'
                    ? ext.errorSurface
                    : ext.warningSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: ext.warningText,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      a.message,
                      style: typo.caption12.copyWith(color: ext.textPrimary),
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

  final Section<Insights> section;

  static const _colors = [
    Color(0xFF3B82F6),
    Color(0xFFEF4444),
    Color(0xFFEAB308),
    Color(0xFFF97316),
    Color(0xFF8B5CF6),
    Color(0xFFA78BFA),
  ];

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    return _section(context, section, (insights) {
      final entries = insights.breakdown.entries
          .where((e) => e.value > 0)
          .toList();
      if (entries.isEmpty) return _emptyText(context, 'Sem custos no período.');
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
            'Taxa de rejeição: ${Fmt.percent(insights.rejectionRate)}',
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

  static String _verb(String action) => switch (action) {
    'created' => 'criou',
    'updated' => 'atualizou',
    'deleted' => 'excluiu',
    'status_changed' => 'mudou o status de',
    'approved' => 'aprovou',
    'rejected' => 'rejeitou',
    _ => action,
  };

  static String _noun(String entity) => switch (entity) {
    'budget' => 'orçamento',
    'customer' => 'cliente',
    'filament' => 'filamento',
    'material' => 'material',
    'brand' => 'marca',
    'preset' => 'preset',
    'model3d' => 'modelo 3D',
    'stock_movement' => 'estoque',
    _ => entity,
  };

  static IconData _icon(String entity) => switch (entity) {
    'budget' => Icons.request_quote_outlined,
    'customer' => Icons.person_outline,
    'filament' || 'stock_movement' => Icons.blur_circular_outlined,
    'model3d' => Icons.view_in_ar_outlined,
    _ => Icons.edit_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    return _section(context, section, (items) {
      if (items.isEmpty) return _emptyText(context, 'Nenhuma atividade ainda.');
      return Column(
        children: [
          for (final a in items)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: switch (a.entityType) {
                'budget' => () => context.go(Routes.budget(a.entityId)),
                'customer' => () => context.go(Routes.customer(a.entityId)),
                _ => null,
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: ext.appBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _icon(a.entityType),
                        size: 16,
                        color: ext.textMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: '${_verb(a.action)} ${_noun(a.entityType)} ',
                          style: typo.body13.copyWith(color: ext.textMuted),
                          children: [
                            TextSpan(
                              text: a.entityName,
                              style: typo.body13.copyWith(
                                color: ext.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      Fmt.relative(a.at),
                      style: typo.caption12.copyWith(color: ext.textHint),
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
