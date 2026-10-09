import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/format/formatters.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/ui/feedback.dart';
import 'package:spooliq_desktop/features/catalog/domain/catalog.dart';
import 'package:spooliq_desktop/features/catalog/domain/catalog_repository.dart';
import 'package:spooliq_desktop/features/catalog/presentation/widgets/filament_swatch.dart';

/// Saldo, nova movimentação e histórico de estoque de um filamento.
class FilamentStockSheet extends StatefulWidget {
  const FilamentStockSheet({
    required this.filament,
    required this.onChanged,
    super.key,
  });

  final Filament filament;
  final VoidCallback onChanged;

  @override
  State<FilamentStockSheet> createState() => _FilamentStockSheetState();
}

class _FilamentStockSheetState extends State<FilamentStockSheet> {
  final CatalogRepository _repo = di<CatalogRepository>();
  late Filament _filament = widget.filament;
  List<StockMovement> _movements = const [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  int _totalPages = 1;

  /// Filtro do histórico (null = todos).
  StockMovementType? _filter;

  StockMovementType _type = StockMovementType.purchase;
  num? _grams;
  num? _price;

  /// Ajuda de compra: carretéis × peso do carretel preenche as gramas.
  num? _spools;
  late num? _spoolWeight = widget.filament.weight ?? 1000;
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// Volta ao estado de carregamento e busca tudo de novo.
  Future<void> _reload() {
    setState(() {
      _loading = true;
      _error = null;
    });
    return _load();
  }

  /// Carrega o filamento (saldo) e a primeira página do histórico.
  Future<void> _load() async {
    try {
      final pageFuture = _repo.stockMovements(_filament.id, type: _filter);
      final freshFuture = _repo.filament(_filament.id);
      await Future.wait([pageFuture, freshFuture]);
      final page = await pageFuture;
      final fresh = await freshFuture;
      if (!mounted) return;
      setState(() {
        _movements = page.items;
        _page = page.page;
        _totalPages = page.totalPages;
        _filament = fresh;
        _loading = false;
      });
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final page = await _repo.stockMovements(
        _filament.id,
        page: _page + 1,
        type: _filter,
      );
      if (!mounted) return;
      setState(() {
        _movements = [..._movements, ...page.items];
        _page = page.page;
        _totalPages = page.totalPages;
        _loadingMore = false;
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      Toasts.error(context, e);
    }
  }

  void _setFilter(StockMovementType? type) {
    _filter = type;
    unawaited(_reload());
  }

  void _applySpools() {
    final spools = _spools;
    final weight = _spoolWeight;
    if (spools == null || weight == null || spools <= 0 || weight <= 0) return;
    setState(() => _grams = (spools * weight).round());
  }

  Future<void> _add() async {
    final grams = _grams;
    if (grams == null || grams == 0) {
      Toasts.info(context, 'Informe a quantidade em gramas.');
      return;
    }
    setState(() => _saving = true);
    try {
      final signed = switch (_type) {
        StockMovementType.waste => -grams.abs(),
        StockMovementType.purchase => grams.abs(),
        _ => grams,
      };
      await _repo.addStockMovement(
        _filament.id,
        type: _type,
        grams: signed.toDouble(),
        unitPricePerKgCents:
            _type == StockMovementType.purchase && _price != null
            ? (_price! * 100).round()
            : null,
        note: _note.text,
      );
      _note.clear();
      setState(() {
        _grams = null;
        _price = null;
        _spools = null;
        _saving = false;
      });
      widget.onChanged();
      if (mounted) Toasts.success(context, 'Movimentação registrada');
      await _load();
    } on ApiError catch (e) {
      setState(() => _saving = false);
      if (mounted) Toasts.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final f = _filament;

    return FormaSideSheetScaffold(
      title: 'Estoque',
      subtitle: f.displayName,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: f.isLowStock ? ext.warningSurface : ext.appBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                FilamentSwatch.of(f, size: 36),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.trackStock ? Fmt.grams(f.stockGrams) : 'Sem controle',
                        style: typo.h4.copyWith(color: ext.textPrimary),
                      ),
                      Text(
                        f.lowStockThresholdGrams == null
                            ? 'em estoque'
                            : 'alerta abaixo de '
                                  '${Fmt.grams(f.lowStockThresholdGrams)}',
                        style: typo.caption12.copyWith(color: ext.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Nova movimentação',
            style: typo.title15.copyWith(color: ext.textPrimary),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 150,
                child: FormaSelect<StockMovementType>(
                  label: 'Tipo',
                  value: _type,
                  options: [
                    for (final t in StockMovementType.values.where(
                      (t) => t != StockMovementType.consumption,
                    ))
                      FormaSelectOption(value: t, label: t.label),
                  ],
                  onChanged: (v) => setState(
                    () => _type = v ?? StockMovementType.purchase,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FormaNumberField(
                  label: _type == StockMovementType.adjustment
                      ? 'Gramas (±)'
                      : 'Gramas',
                  value: _grams,
                  decimals: 1,
                  min: _type == StockMovementType.adjustment ? null : 0,
                  suffixText: 'g',
                  onChanged: (v) => _grams = v,
                ),
              ),
              if (_type == StockMovementType.purchase) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FormaNumberField(
                    label: 'Preço/kg pago',
                    value: _price,
                    decimals: 2,
                    min: 0,
                    prefixText: r'R$',
                    onChanged: (v) => _price = v,
                  ),
                ),
              ],
            ],
          ),
          if (_type == StockMovementType.purchase) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FormaNumberField(
                    label: 'Carretéis',
                    value: _spools,
                    min: 0,
                    helperText: 'preenche as gramas',
                    onChanged: (v) {
                      _spools = v;
                      _applySpools();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FormaNumberField(
                    label: 'Peso do carretel',
                    value: _spoolWeight,
                    min: 0,
                    suffixText: 'g',
                    onChanged: (v) {
                      _spoolWeight = v;
                      _applySpools();
                    },
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          FormaTextField(label: 'Observação', controller: _note),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FormaButton.primary(
              label: 'Registrar',
              small: true,
              isLoading: _saving,
              onPressed: () => unawaited(_add()),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Histórico',
                  style: typo.title15.copyWith(color: ext.textPrimary),
                ),
              ),
              SizedBox(
                width: 170,
                child: FormaSelect<StockMovementType?>(
                  value: _filter,
                  options: [
                    const FormaSelectOption(
                      value: null,
                      label: 'Todos os tipos',
                    ),
                    for (final t in StockMovementType.values)
                      FormaSelectOption(value: t, label: t.label),
                  ],
                  onChanged: _setFilter,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            const LoadingView()
          else if (_error != null)
            ErrorView(message: _error!, onRetry: () => unawaited(_reload()))
          else if (_movements.isEmpty)
            Text(
              _filter == null
                  ? 'Nenhuma movimentação ainda.'
                  : 'Nenhuma movimentação deste tipo.',
              style: typo.body13.copyWith(color: ext.textMuted),
            )
          else
            for (final m in _movements)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      m.grams >= 0
                          ? Icons.south_west_rounded
                          : Icons.north_east_rounded,
                      size: 16,
                      color: m.grams >= 0 ? ext.successColor : ext.errorColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            [
                              m.type.label,
                              if (m.budgetQuoteNumber != null)
                                'orçamento ${Fmt.quote(m.budgetQuoteNumber)}',
                            ].join(' · '),
                            style: typo.body13.copyWith(color: ext.textPrimary),
                          ),
                          Text(
                            [
                              Fmt.dateTime(m.createdAt),
                              if (m.unitPricePerKgCents != null)
                                '${Fmt.cents(m.unitPricePerKgCents)}/kg',
                              ?m.note,
                            ].join(' · '),
                            style: typo.caption12.copyWith(color: ext.textHint),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${m.grams >= 0 ? '+' : '−'}${Fmt.grams(m.grams.abs())}',
                      style: typo.body14Medium.copyWith(
                        color: m.grams >= 0 ? ext.successText : ext.errorText,
                      ),
                    ),
                  ],
                ),
              ),
          if (!_loading && _error == null && _page < _totalPages)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: FormaButton.ghost(
                  label: 'Carregar mais',
                  small: true,
                  isLoading: _loadingMore,
                  onPressed: () => unawaited(_loadMore()),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
