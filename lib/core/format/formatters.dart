import 'package:intl/intl.dart';

/// Formatação pt-BR usada em todo o app.
abstract final class Fmt {
  static final _brl = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
  static final _brlCompact = NumberFormat.compactCurrency(
    locale: 'pt_BR',
    symbol: r'R$',
    decimalDigits: 1,
  );
  static final _decimal = NumberFormat.decimalPattern('pt_BR');
  static final _date = DateFormat('dd/MM/yyyy', 'pt_BR');
  static final _dateTime = DateFormat("dd/MM/yyyy 'às' HH:mm", 'pt_BR');
  static final _dayMonth = DateFormat('d MMM', 'pt_BR');
  static final _long = DateFormat("d 'de' MMMM 'de' yyyy", 'pt_BR');

  /// Centavos (int) → "R$ 1.234,56".
  static String cents(int? cents) => _brl.format((cents ?? 0) / 100);

  /// Valor em reais (double) → "R$ 1.234,56".
  static String money(num? value) => _brl.format(value ?? 0);

  /// Centavos → "R$ 1,2 mil".
  static String centsCompact(int? cents) =>
      _brlCompact.format((cents ?? 0) / 100);

  static String number(num? value, {int decimals = 0}) {
    final f = NumberFormat.decimalPatternDigits(
      locale: 'pt_BR',
      decimalDigits: decimals,
    );
    return f.format(value ?? 0);
  }

  static String plain(num? value) => _decimal.format(value ?? 0);

  /// Quantidade com até [decimals] casas, sem zeros à direita ("10", "10,5").
  static String qty(num? value, {int decimals = 3}) {
    final text = number(value, decimals: decimals);
    if (!text.contains(',')) return text;
    final parts = text.split(',');
    final dec = parts[1].replaceAll(RegExp(r'0+$'), '');
    return dec.isEmpty ? parts[0] : '${parts[0]},$dec';
  }

  /// Custo por unidade em centavos (fracionários) → "R$ 0,1748" (2–4 casas,
  /// sem zeros supérfluos). Ex.: 17,475 centavos → "R$ 0,1748".
  static String unitPrice(num? centsPerUnit) {
    final reais = (centsPerUnit ?? 0) / 100;
    final text = number(reais, decimals: 4);
    if (!text.contains(',')) return 'R\$ $text';
    final parts = text.split(',');
    var dec = parts[1];
    while (dec.length > 2 && dec.endsWith('0')) {
      dec = dec.substring(0, dec.length - 1);
    }
    return 'R\$ ${parts[0]},$dec';
  }

  static String percent(num? value, {int decimals = 1}) =>
      '${number(value, decimals: decimals)}%';

  /// Gramas → "850 g" / "1,25 kg".
  static String grams(num? grams) {
    final g = grams ?? 0;
    if (g.abs() >= 1000) return '${number(g / 1000, decimals: 2)} kg';
    return '${number(g, decimals: g % 1 == 0 ? 0 : 1)} g';
  }

  static String date(DateTime? d) => d == null ? '—' : _date.format(d);
  static String dateTime(DateTime? d) => d == null ? '—' : _dateTime.format(d);
  static String dayMonth(DateTime? d) => d == null ? '—' : _dayMonth.format(d);
  static String longDate(DateTime? d) => d == null ? '—' : _long.format(d);

  /// "há 5 min", "há 2 h", "ontem", "12/03/2026".
  static String relative(DateTime? d, {DateTime? now}) {
    if (d == null) return '—';
    final diff = (now ?? DateTime.now()).difference(d);
    if (diff.isNegative) return date(d);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'há ${diff.inHours} h';
    if (diff.inDays == 1) return 'ontem';
    if (diff.inDays < 7) return 'há ${diff.inDays} dias';
    return date(d);
  }

  /// Horas + minutos → "5h30m".
  static String duration(int hours, int minutes) {
    final total = hours * 60 + minutes;
    final h = total ~/ 60;
    final m = total % 60;
    if (h == 0) return '${m}min';
    if (m == 0) return '${h}h';
    return '${h}h${m.toString().padLeft(2, '0')}m';
  }

  /// Minutos → "1h30m".
  static String minutes(int? minutes) => duration(0, minutes ?? 0);

  /// Número do orçamento → "#0042".
  static String quote(int? number) => number == null || number == 0
      ? ''
      : '#${number.toString().padLeft(4, '0')}';

  /// API: datas YYYY-MM-DD.
  static String apiDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
