import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/core/state/paged_list_cubit.dart';
import 'package:spooliq_desktop/core/ui/feedback.dart';

/// Tabela + paginação ligadas a um [PagedListCubit].
class PagedTable<T> extends StatelessWidget {
  const PagedTable({
    required this.columns,
    required this.empty,
    this.onRowTap,
    this.trailingBuilder,
    this.itemLabel = 'registros',
    this.rowHeight = 56,
    super.key,
  });

  final List<FormaColumn<T>> columns;
  final Widget empty;
  final void Function(T row)? onRowTap;
  final Widget Function(BuildContext, T row)? trailingBuilder;
  final String itemLabel;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PagedListCubit<T>, PagedListState<T>>(
      builder: (context, state) {
        final cubit = context.read<PagedListCubit<T>>();
        if (state.error != null && state.items.isEmpty) {
          return ErrorView(message: state.error!, onRetry: cubit.refresh);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: FormaDataTable<T>(
                columns: columns,
                rows: state.items,
                loading: state.loading && state.items.isEmpty,
                rowHeight: rowHeight,
                sortColumnId: state.query.sortBy,
                sortAscending: state.query.sortAscending,
                onSort: cubit.sort,
                onRowTap: onRowTap,
                trailingBuilder: trailingBuilder,
                empty: state.isSearching
                    ? const FormaEmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'Nada encontrado',
                        message: 'Tente outros termos de busca.',
                      )
                    : empty,
              ),
            ),
            if (state.page.totalPages > 1) ...[
              const SizedBox(height: 12),
              FormaPagination(
                page: state.page.page,
                totalPages: state.page.totalPages,
                total: state.page.total,
                pageSize: state.page.pageSize,
                itemLabel: itemLabel,
                onPageChanged: cubit.goToPage,
              ),
            ],
          ],
        );
      },
    );
  }
}
