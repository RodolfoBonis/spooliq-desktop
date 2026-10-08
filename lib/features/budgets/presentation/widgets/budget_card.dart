import 'package:flutter/material.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/core/format/formatters.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_status.dart';
import 'package:spooliq_desktop/features/budgets/presentation/widgets/budget_status_style.dart';

/// Card do orçamento no quadro kanban.
class BudgetCard extends StatefulWidget {
  const BudgetCard({
    required this.budget,
    required this.onOpen,
    required this.menuItems,
    this.busy = false,
    super.key,
  });

  final Budget budget;
  final VoidCallback onOpen;
  final List<FormaMenuItem> menuItems;

  /// Mudança de status em andamento.
  final bool busy;

  @override
  State<BudgetCard> createState() => _BudgetCardState();
}

class _BudgetCardState extends State<BudgetCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final b = widget.budget;
    final style = BudgetStatusStyle.of(b.status, Theme.of(context).brightness);
    final quote = Fmt.quote(b.quoteNumber);

    return Semantics(
      button: true,
      label:
          'Orçamento ${b.name}, ${b.customerName}, ${Fmt.cents(b.totalCents)}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: ext.cardBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hover ? ext.borderStrong : ext.border,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hover ? 0.08 : 0.03),
                blurRadius: _hover ? 14 : 4,
                offset: Offset(0, _hover ? 4 : 1),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: widget.onOpen,
              child: Stack(
                children: [
                  // Faixa lateral com a cor do status.
                  Positioned(
                    left: 0,
                    top: 10,
                    bottom: 10,
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: style.color,
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (quote.isNotEmpty)
                              Text(
                                quote,
                                style: typo.caption12Med.copyWith(
                                  color: ext.textHint,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            const Spacer(),
                            if (widget.busy)
                              const Padding(
                                padding: EdgeInsets.all(6),
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            else
                              SizedBox(
                                height: 26,
                                child: AnimatedOpacity(
                                  opacity: _hover ? 1 : 0.35,
                                  duration: const Duration(milliseconds: 120),
                                  child: FormaMenuButton(
                                    tooltip: 'Ações',
                                    items: widget.menuItems,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            b.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: typo.body14Medium.copyWith(
                              color: ext.textPrimary,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (b.customerName.isNotEmpty)
                          Row(
                            children: [
                              _Initials(name: b.customerName),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  b.customerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: typo.caption12.copyWith(
                                    color: ext.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Text(
                                  Fmt.cents(b.totalCents),
                                  style: typo.title16.copyWith(
                                    color: ext.textPrimary,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                              ..._signals(context, b),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _footer(b),
                          style: typo.caption12.copyWith(color: ext.textHint),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _footer(Budget b) {
    final parts = <String>[
      if (b.itemCount > 0)
        '${b.itemCount} ${b.itemCount == 1 ? 'item' : 'itens'}',
      if (b.validUntil != null && b.status == BudgetStatus.sent)
        'válido até ${Fmt.dayMonth(b.validUntil)}'
      else
        Fmt.relative(b.updatedAt ?? b.createdAt),
    ];
    return parts.join(' · ');
  }

  List<Widget> _signals(BuildContext context, Budget b) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    Widget signal(IconData icon, Color color, String tip) => Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Tooltip(
        message: tip,
        child: Icon(icon, size: 16, color: color),
      ),
    );
    return [
      if (b.isShared)
        signal(Icons.link_rounded, ext.textMuted, 'Link de aprovação ativo'),
      if (b.customerResponseAt != null && b.status == BudgetStatus.approved)
        signal(
          Icons.verified_rounded,
          ext.successColor,
          b.customerResponseName == null
              ? 'Aprovado pelo cliente'
              : 'Aprovado pelo cliente (${b.customerResponseName})',
        ),
      if (b.isExpiringSoon)
        signal(
          Icons.timer_outlined,
          ext.warningColor,
          'Validade próxima do fim',
        ),
      if (b.stockWarnings.isNotEmpty)
        signal(
          Icons.inventory_2_outlined,
          ext.warningColor,
          'Estoque insuficiente',
        ),
    ];
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = (parts.first[0] + (parts.length > 1 ? parts.last[0] : ''))
        .toUpperCase();
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ext.primarySurface,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          color: ext.primaryColor,
        ),
      ),
    );
  }
}
