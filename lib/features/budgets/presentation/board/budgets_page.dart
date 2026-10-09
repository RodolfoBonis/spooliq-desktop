import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spooliq_desktop/core/auth/session_user.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/format/formatters.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/core/routing/routes.dart';
import 'package:spooliq_desktop/core/state/paged_list_cubit.dart';
import 'package:spooliq_desktop/core/ui/feedback.dart';
import 'package:spooliq_desktop/core/ui/page_layout.dart';
import 'package:spooliq_desktop/core/ui/paged_table.dart';
import 'package:spooliq_desktop/core/ui/save_file.dart';
import 'package:spooliq_desktop/features/auth/presentation/session_cubit.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_repository.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_status.dart';
import 'package:spooliq_desktop/features/budgets/presentation/board/board_cubit.dart';
import 'package:spooliq_desktop/features/budgets/presentation/board/budget_filters_bar.dart';
import 'package:spooliq_desktop/features/budgets/presentation/budget_actions.dart';
import 'package:spooliq_desktop/features/budgets/presentation/widgets/budget_card.dart';
import 'package:spooliq_desktop/features/budgets/presentation/widgets/budget_status_badge.dart';
import 'package:spooliq_desktop/features/budgets/presentation/widgets/budget_status_style.dart';

enum BudgetsView { board, table }

/// Orçamentos: quadro kanban (padrão) ou lista.
class BudgetsPage extends StatefulWidget {
  const BudgetsPage({super.key});

  @override
  State<BudgetsPage> createState() => _BudgetsPageState();
}

class _BudgetsPageState extends State<BudgetsPage> {
  static const _prefKey = 'budgets.view';
  late BudgetsView _view = BudgetsView.values.firstWhere(
    (v) => v.name == di<SharedPreferences>().getString(_prefKey),
    orElse: () => BudgetsView.board,
  );

  late final BoardCubit _board = BoardCubit(di());
  late final PagedListCubit<Budget> _table = PagedListCubit<Budget>(
    (q) => di<BudgetRepository>().list(filter: _filter, page: q),
    idOf: (b) => b.id,
    initialQuery: const PageQuery(sortBy: 'created_at'),
  );
  BudgetFilter _filter = const BudgetFilter();
  BudgetStatus? _tableStatus;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  @override
  void dispose() {
    unawaited(_board.close());
    unawaited(_table.close());
    super.dispose();
  }

  Future<void> _reload() => _view == BudgetsView.board
      ? _board.load(filter: _filter)
      : _table.load(_table.state.query.copyWith(page: 1));

  void _setView(BudgetsView view) {
    if (view == _view) return;
    setState(() => _view = view);
    unawaited(di<SharedPreferences>().setString(_prefKey, view.name));
    unawaited(_reload());
  }

  Future<void> _exportCsv() async {
    try {
      final bytes = await di<BudgetRepository>().exportCsv(_filter);
      final path = await saveBytesAs(
        bytes,
        suggestedName: 'orcamentos.csv',
        typeLabel: 'Planilha CSV',
        extension: 'csv',
      );
      if (path != null && mounted) Toasts.success(context, 'CSV exportado');
    } on ApiError catch (e) {
      if (mounted) Toasts.error(context, e);
    }
  }

  void _setFilter(BudgetFilter filter) {
    setState(() => _filter = filter.copyWith(status: () => _tableStatus));
    unawaited(_reload());
  }

  void _setTableStatus(BudgetStatus? status) {
    setState(() {
      _tableStatus = status;
      _filter = _filter.copyWith(status: () => status);
    });
    unawaited(_reload());
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _board),
        BlocProvider.value(value: _table),
      ],
      child: BlocBuilder<BoardCubit, BoardState>(
        buildWhen: (a, b) =>
            a.totalCount != b.totalCount || a.showArchived != b.showArchived,
        builder: (context, board) => PageLayout(
          title: 'Orçamentos',
          subtitle: _view == BudgetsView.board && !board.isInitialLoading
              ? '${board.totalCount} orçamentos · '
                    'arraste os cards para mudar o status'
              : 'Do rascunho à entrega, tudo em um só lugar.',
          actions: [
            _ViewToggle(value: _view, onChanged: _setView),
            Tooltip(
              message: 'Atualizar',
              child: FormaIconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                onPressed: () => unawaited(_reload()),
              ),
            ),
            Tooltip(
              message: 'Exportar CSV (com os filtros atuais)',
              child: FormaIconButton(
                icon: const Icon(Icons.download_rounded, size: 20),
                onPressed: () => unawaited(_exportCsv()),
              ),
            ),
            FormaButton.primary(
              label: 'Novo orçamento',
              small: true,
              icon: const Icon(Icons.add, size: 18, color: Colors.white),
              onPressed: () => context.go(Routes.budgetNew),
            ),
          ],
          toolbar: BudgetFiltersBar(
            filter: _filter,
            onChanged: _setFilter,
            trailing: [
              if (_view == BudgetsView.board)
                FormaCheckbox(
                  value: board.showArchived,
                  label: 'Mostrar finalizados sem venda',
                  onChanged: (_) => _board.toggleArchived(),
                )
              else
                SizedBox(
                  width: 190,
                  child: FormaSelect<BudgetStatus>(
                    hint: 'Todos os status',
                    clearable: true,
                    value: _tableStatus,
                    options: [
                      for (final s in BudgetStatus.values)
                        FormaSelectOption(value: s, label: s.label),
                    ],
                    onChanged: _setTableStatus,
                  ),
                ),
            ],
          ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _view == BudgetsView.board
                ? const _BoardView(key: ValueKey('board'))
                : const _TableView(key: ValueKey('table')),
          ),
        ),
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.value, required this.onChanged});

  final BudgetsView value;
  final ValueChanged<BudgetsView> onChanged;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    Widget option(BudgetsView v, IconData icon, String label) {
      final active = v == value;
      return Semantics(
        selected: active,
        button: true,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => onChanged(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: active ? ext.cardBackground : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: active ? ext.textPrimary : ext.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: typo.caption12Med.copyWith(
                    color: active ? ext.textPrimary : ext.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
          option(BudgetsView.board, Icons.view_kanban_outlined, 'Quadro'),
          option(BudgetsView.table, Icons.table_rows_outlined, 'Lista'),
        ],
      ),
    );
  }
}

class _BoardView extends StatelessWidget {
  const _BoardView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.select<SessionCubit, SessionUser?>(
      (c) => c.state.user,
    );
    if (user == null) return const SizedBox.shrink();
    final cubit = context.read<BoardCubit>();
    final brightness = Theme.of(context).brightness;
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;

    final actions = BudgetActions(
      context: context,
      user: user,
      onChanged: cubit.upsert,
      onDeleted: cubit.remove,
      onMove: (b, to, notes) => _move(context, b, to, notes),
    );

    return BlocBuilder<BoardCubit, BoardState>(
      builder: (context, state) {
        final errors = state.columns.values.where((c) => c.error != null);
        if (!state.isInitialLoading &&
            errors.length == state.columns.length &&
            errors.isNotEmpty) {
          return ErrorView(
            message: errors.first.error!,
            onRetry: cubit.refresh,
          );
        }

        FormaKanbanColumn<Budget> column(
          BudgetStatus s, {
          bool archived = false,
        }) {
          final col = state.column(s);
          return FormaKanbanColumn<Budget>(
            id: s.value,
            title: s.label,
            items: col.items,
            color: BudgetStatusStyle.of(s, brightness).color,
            totalCount: col.total,
            hasMore: col.hasMore,
            loadingMore: col.loadingMore,
            onLoadMore: () => unawaited(cubit.loadMore(s)),
            collapsed: archived && !state.showArchived,
            onToggleCollapsed: archived ? cubit.toggleArchived : null,
            emptyText: _emptyText(s),
            headerTrailing: col.items.isEmpty
                ? null
                : Tooltip(
                    message: 'Soma dos orçamentos carregados',
                    child: Text(
                      Fmt.centsCompact(col.loadedValueCents),
                      style: typo.caption12.copyWith(color: ext.textMuted),
                    ),
                  ),
          );
        }

        return FormaKanbanBoard<Budget>(
          loading: state.isInitialLoading,
          columnWidth: 296,
          columns: [
            for (final s in BudgetStatus.board) column(s),
            for (final s in BudgetStatus.archived) column(s, archived: true),
          ],
          itemKey: (b) => b.id,
          canMove: (b, from, to) => BudgetStatus.fromValue(
            from,
          ).canTransitionTo(BudgetStatus.fromValue(to)),
          onMove: (b, from, to) => unawaited(
            actions.move(b, BudgetStatus.fromValue(to)),
          ),
          cardBuilder: (context, b) => BudgetCard(
            budget: b,
            busy: state.moving.contains(b.id),
            onOpen: () => context.go(Routes.budget(b.id)),
            menuItems: actions.menuFor(b),
          ),
        );
      },
    );
  }

  static String _emptyText(BudgetStatus s) => switch (s) {
    BudgetStatus.draft => 'Crie um orçamento para começar',
    BudgetStatus.sent => 'Arraste rascunhos prontos para cá',
    BudgetStatus.approved => 'Nenhum aprovado ainda',
    BudgetStatus.printing => 'Nada na impressora',
    BudgetStatus.completed => 'Nenhum concluído no período',
    _ => 'Nenhum orçamento',
  };

  static Future<bool> _move(
    BuildContext context,
    Budget b,
    BudgetStatus to,
    String? notes,
  ) async {
    final result = await context.read<BoardCubit>().move(b, to, notes: notes);
    switch (result) {
      case MoveSucceeded():
        return true;
      case MoveFailed(:final error):
        if (context.mounted) Toasts.error(context, error);
        return false;
    }
  }
}

class _TableView extends StatelessWidget {
  const _TableView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.select<SessionCubit, SessionUser?>(
      (c) => c.state.user,
    );
    if (user == null) return const SizedBox.shrink();
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final cubit = context.read<PagedListCubit<Budget>>();
    final muted = typo.body14.copyWith(color: ext.textMuted);
    final actions = BudgetActions(
      context: context,
      user: user,
      onChanged: (b) => unawaited(cubit.refresh()),
      onDeleted: cubit.remove,
    );

    return PagedTable<Budget>(
      itemLabel: 'orçamentos',
      onRowTap: (b) => context.go(Routes.budget(b.id)),
      trailingBuilder: (context, b) =>
          FormaMenuButton(items: actions.menuFor(b)),
      columns: [
        FormaColumn(
          id: 'quote',
          label: 'Nº',
          width: 72,
          cellBuilder: (_, b) => Text(Fmt.quote(b.quoteNumber), style: muted),
        ),
        FormaColumn(
          id: 'name',
          label: 'Orçamento',
          flex: 3,
          sortable: true,
          cellBuilder: (_, b) => Text(
            b.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typo.body14Medium.copyWith(color: ext.textPrimary),
          ),
        ),
        FormaColumn(
          id: 'customer',
          label: 'Cliente',
          flex: 2,
          cellBuilder: (_, b) => Text(
            b.customerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: muted,
          ),
        ),
        FormaColumn(
          id: 'status',
          label: 'Status',
          width: 140,
          sortable: true,
          cellBuilder: (_, b) => Align(
            alignment: Alignment.centerLeft,
            child: BudgetStatusBadge(b.status, dense: true),
          ),
        ),
        FormaColumn(
          id: 'total_cost',
          label: 'Total',
          width: 140,
          sortable: true,
          alignment: Alignment.centerRight,
          cellBuilder: (_, b) => Text(
            Fmt.cents(b.totalCents),
            style: typo.body14Medium.copyWith(
              color: ext.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        FormaColumn(
          id: 'valid_until',
          label: 'Validade',
          width: 110,
          cellBuilder: (_, b) => Text(Fmt.date(b.validUntil), style: muted),
        ),
        FormaColumn(
          id: 'created_at',
          label: 'Criado em',
          width: 120,
          sortable: true,
          cellBuilder: (_, b) => Text(Fmt.date(b.createdAt), style: muted),
        ),
      ],
      empty: FormaEmptyState(
        icon: Icons.request_quote_outlined,
        title: 'Nenhum orçamento por aqui',
        message:
            'Crie seu primeiro orçamento e acompanhe do rascunho à entrega.',
        action: FormaButton.primary(
          label: 'Novo orçamento',
          small: true,
          onPressed: () => context.go(Routes.budgetNew),
        ),
      ),
    );
  }
}
