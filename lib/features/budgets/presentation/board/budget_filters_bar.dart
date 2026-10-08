import 'package:flutter/material.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/core/ui/search_field.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_repository.dart';
import 'package:spooliq_desktop/features/customers/domain/customer_repository.dart';

/// Períodos rápidos (filtro `from`).
enum BudgetPeriod {
  all('Todo o período', null),
  d7('Últimos 7 dias', 7),
  d30('Últimos 30 dias', 30),
  d90('Últimos 90 dias', 90),
  y1('Últimos 12 meses', 365);

  const BudgetPeriod(this.label, this.days);

  final String label;
  final int? days;

  DateTime? get from {
    final d = days;
    if (d == null) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).subtract(Duration(days: d));
  }

  static BudgetPeriod of(DateTime? from) {
    if (from == null) return all;
    final days = DateTime.now().difference(from).inDays;
    return values.lastWhere(
      (p) => p.days != null && p.days! <= days + 1,
      orElse: () => all,
    );
  }
}

/// Barra de filtros comum ao quadro e à lista.
class BudgetFiltersBar extends StatelessWidget {
  const BudgetFiltersBar({
    required this.filter,
    required this.onChanged,
    this.trailing = const [],
    super.key,
  });

  final BudgetFilter filter;
  final ValueChanged<BudgetFilter> onChanged;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final customers = di<CustomerRepository>();
    return Row(
      children: [
        SearchField(
          hint: 'Buscar por nome ou nº…',
          initialValue: filter.search,
          width: 280,
          onChanged: (q) =>
              onChanged(filter.copyWith(search: () => q.isEmpty ? null : q)),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 240,
          child: FormaCombobox<String>(
            hint: 'Todos os clientes',
            value: filter.customerId == null
                ? null
                : FormaSelectOption(
                    value: filter.customerId!,
                    label: filter.customerName ?? '',
                  ),
            search: (q) async {
              final page = await customers.list(
                page: PageQuery(pageSize: 8, search: q.isEmpty ? null : q),
              );
              return [
                for (final c in page.items)
                  FormaSelectOption(
                    value: c.id,
                    label: c.name,
                    subtitle: c.email,
                  ),
              ];
            },
            onChanged: (opt) => onChanged(
              filter.copyWith(
                customerId: () => opt?.value,
                customerName: () => opt?.label,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 200,
          child: FormaSelect<BudgetPeriod>(
            value: BudgetPeriod.of(filter.from),
            options: [
              for (final p in BudgetPeriod.values)
                FormaSelectOption(value: p, label: p.label),
            ],
            onChanged: (p) => onChanged(filter.copyWith(from: () => p?.from)),
          ),
        ),
        const Spacer(),
        ...trailing,
      ],
    );
  }
}
