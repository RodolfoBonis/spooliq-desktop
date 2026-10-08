import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/format/formatters.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/routing/routes.dart';
import 'package:spooliq_desktop/core/ui/feedback.dart';
import 'package:spooliq_desktop/core/ui/page_layout.dart';
import 'package:spooliq_desktop/features/admin/domain/admin.dart';
import 'package:spooliq_desktop/features/admin/presentation/admin_widgets.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  AdminStats? _stats;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final s = await di<AdminRepository>().stats();
      if (mounted) setState(() => _stats = s);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    if (s == null) {
      return _error != null
          ? ErrorView(message: _error!, onRetry: () => unawaited(_load()))
          : const LoadingView();
    }
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final cancelledOrOther = (s.companies - s.active - s.trial - s.overdue)
        .clamp(0, 1 << 30);
    final slices = [
      ('Ativas', s.active, ext.successColor),
      ('Em teste', s.trial, const Color(0xFF0288D1)),
      ('Inadimplentes', s.overdue, ext.warningColor),
      ('Outras', cancelledOrOther, ext.textHint),
    ].where((x) => x.$2 > 0).toList();

    return PageLayout(
      title: 'Painel da plataforma',
      subtitle: 'Saúde do SpoolIQ como negócio.',
      actions: [
        Tooltip(
          message: 'Atualizar',
          child: FormaIconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: () => unawaited(_load()),
          ),
        ),
      ],
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'MRR',
                  value: Fmt.cents(s.mrrCents),
                  icon: Icons.trending_up_rounded,
                  tone: ext.successColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: 'Empresas',
                  value: '${s.companies}',
                  icon: Icons.domain_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: 'Assinaturas ativas',
                  value: '${s.active}',
                  icon: Icons.verified_outlined,
                  tone: ext.successColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: 'Em teste',
                  value: '${s.trial}',
                  icon: Icons.hourglass_bottom_rounded,
                  tone: const Color(0xFF0288D1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: 'Churn',
                  value: Fmt.percent(s.churnRate),
                  icon: Icons.trending_down_rounded,
                  tone: ext.errorColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SectionCard(
                  title: 'Distribuição das empresas',
                  child: slices.isEmpty
                      ? Text(
                          'Sem empresas ainda.',
                          style: typo.body13.copyWith(color: ext.textMuted),
                        )
                      : Row(
                          children: [
                            SizedBox(
                              width: 180,
                              height: 180,
                              child: PieChart(
                                PieChartData(
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 52,
                                  sections: [
                                    for (final (_, v, c) in slices)
                                      PieChartSectionData(
                                        value: v.toDouble(),
                                        color: c,
                                        radius: 28,
                                        showTitle: false,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Column(
                                children: [
                                  for (final (l, v, c) in slices)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: c,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              l,
                                              style: typo.body14.copyWith(
                                                color: ext.textMuted,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '$v',
                                            style: typo.body14Medium.copyWith(
                                              color: ext.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SectionCard(
                  title: 'Atalhos',
                  child: Column(
                    children: [
                      for (final (icon, label, sub, path) in [
                        (
                          Icons.domain_outlined,
                          'Empresas',
                          'Status, planos e trials',
                          Routes.adminCompanies,
                        ),
                        (
                          Icons.receipt_long_outlined,
                          'Assinaturas',
                          'Cobranças e inadimplência',
                          Routes.adminSubscriptions,
                        ),
                        (
                          Icons.layers_outlined,
                          'Planos',
                          'Preços, recursos e templates',
                          Routes.adminPlans,
                        ),
                      ])
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(icon, color: ext.textMuted),
                          title: Text(label),
                          subtitle: Text(sub),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.go(path),
                        ),
                    ],
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
