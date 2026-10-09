import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/format/formatters.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/core/state/paged_list_cubit.dart';
import 'package:spooliq_desktop/core/ui/page_layout.dart';
import 'package:spooliq_desktop/core/ui/paged_table.dart';
import 'package:spooliq_desktop/features/activity/domain/activity_repository.dart';
import 'package:spooliq_desktop/features/activity/presentation/activity_tile.dart';
import 'package:spooliq_desktop/features/dashboard/domain/dashboard.dart';

/// Log completo de atividades da organização, com filtros.
class ActivitiesPage extends StatefulWidget {
  const ActivitiesPage({super.key});

  @override
  State<ActivitiesPage> createState() => _ActivitiesPageState();
}

class _ActivitiesPageState extends State<ActivitiesPage> {
  ActivityEntity? _entity;
  ActivityAction? _action;

  late final PagedListCubit<Activity> _cubit = PagedListCubit<Activity>(
    (q) => di<ActivityRepository>().list(
      page: q,
      entity: _entity,
      action: _action,
    ),
    idOf: (a) => a.id,
    initialQuery: const PageQuery(pageSize: 50),
  );

  @override
  void initState() {
    super.initState();
    unawaited(_cubit.load());
  }

  @override
  void dispose() {
    unawaited(_cubit.close());
    super.dispose();
  }

  void _reload() =>
      unawaited(_cubit.load(_cubit.state.query.copyWith(page: 1)));

  void _open(Activity a) {
    final route = ActivityTile.routeFor(a);
    if (route != null) context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    return BlocProvider.value(
      value: _cubit,
      child: PageLayout(
        title: 'Atividades',
        subtitle: 'Tudo o que foi criado, alterado ou aprovado na empresa.',
        toolbar: Row(
          children: [
            SizedBox(
              width: 200,
              child: FormaSelect<ActivityEntity>(
                hint: 'Todas as áreas',
                clearable: true,
                value: _entity,
                options: [
                  for (final e in ActivityEntity.values)
                    FormaSelectOption(value: e, label: e.label),
                ],
                onChanged: (v) {
                  setState(() => _entity = v);
                  _reload();
                },
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 200,
              child: FormaSelect<ActivityAction>(
                hint: 'Todas as ações',
                clearable: true,
                value: _action,
                options: [
                  for (final a in ActivityAction.values)
                    FormaSelectOption(value: a, label: a.label),
                ],
                onChanged: (v) {
                  setState(() => _action = v);
                  _reload();
                },
              ),
            ),
          ],
        ),
        body: PagedTable<Activity>(
          itemLabel: 'atividades',
          onRowTap: _open,
          columns: [
            FormaColumn(
              id: 'activity',
              label: 'Atividade',
              flex: 4,
              cellBuilder: (_, a) => Row(
                children: [
                  Icon(
                    ActivityTile.icon(a.entityType),
                    size: 16,
                    color: ext.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text:
                            '${ActivityTile.verb(a.action)} '
                            '${ActivityTile.noun(a.entityType)} ',
                        style: typo.body14.copyWith(color: ext.textMuted),
                        children: [
                          TextSpan(
                            text: a.entityName,
                            style: typo.body14Medium.copyWith(
                              color: ext.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            FormaColumn(
              id: 'description',
              label: 'Detalhe',
              flex: 3,
              cellBuilder: (_, a) => Text(
                a.description ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typo.body14.copyWith(color: ext.textMuted),
              ),
            ),
            FormaColumn(
              id: 'created_at',
              label: 'Quando',
              width: 150,
              cellBuilder: (_, a) => Text(
                Fmt.dateTime(a.at),
                style: typo.body14.copyWith(color: ext.textMuted),
              ),
            ),
          ],
          empty: FormaEmptyState(
            icon: Icons.history_rounded,
            title: _entity == null && _action == null
                ? 'Nenhuma atividade ainda'
                : 'Nada com esses filtros',
          ),
        ),
      ),
    );
  }
}
