import 'package:flutter/services.dart';

/// Máscara baseada em padrão: `#` = dígito; demais caracteres são literais.
/// Escolhe o padrão pela quantidade de dígitos (ex.: CPF vs. CNPJ).
class PatternMask extends TextInputFormatter {
  PatternMask(this._patterns) : assert(_patterns.isNotEmpty, 'patterns');

  /// Padrões em ordem crescente de dígitos.
  final List<String> _patterns;

  static int _digitsOf(String pattern) => '#'.allMatches(pattern).length;

  int get maxDigits => _digitsOf(_patterns.last);

  String apply(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final clipped = digits.length > maxDigits
        ? digits.substring(0, maxDigits)
        : digits;
    final pattern = _patterns.firstWhere(
      (p) => clipped.length <= _digitsOf(p),
      orElse: () => _patterns.last,
    );
    final out = StringBuffer();
    var i = 0;
    for (final ch in pattern.split('')) {
      if (i >= clipped.length) break;
      if (ch == '#') {
        out.write(clipped[i++]);
      } else {
        out.write(ch);
      }
    }
    return out.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = apply(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Máscaras brasileiras usadas nos formulários.
abstract final class Masks {
  /// (82) 3142-2684 / (82) 99610-7412.
  static final phone = PatternMask(['(##) ####-####', '(##) #####-####']);

  /// 000.000.000-00 / 00.000.000/0000-00.
  static final document = PatternMask(['###.###.###-##', '##.###.###/####-##']);

  static final cnpj = PatternMask(['##.###.###/####-##']);

  /// 57035-180.
  static final cep = PatternMask(['#####-###']);

  /// Aplica a máscara a um valor vindo da API (só dígitos ou já formatado).
  static String? format(PatternMask mask, String? value) =>
      value == null || value.isEmpty ? value : mask.apply(value);

  static String digits(String value) => value.replaceAll(RegExp(r'\D'), '');
}
