import 'package:flutter_test/flutter_test.dart';
import 'package:spooliq_desktop/core/format/masks.dart';

void main() {
  String type(PatternMask mask, String text) => mask
      .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text))
      .text;

  test('phone switches between landline and mobile', () {
    expect(type(Masks.phone, '8231422684'), '(82) 3142-2684');
    expect(type(Masks.phone, '82996107412'), '(82) 99610-7412');
    expect(type(Masks.phone, '829961074129999'), '(82) 99610-7412');
  });

  test('document switches between CPF and CNPJ', () {
    expect(type(Masks.document, '12345678909'), '123.456.789-09');
    expect(type(Masks.document, '12345678000195'), '12.345.678/0001-95');
  });

  test('partial input keeps only the typed prefix', () {
    expect(type(Masks.cep, '570'), '570');
    expect(type(Masks.cep, '57035180'), '57035-180');
    expect(type(Masks.phone, '82'), '(82');
  });

  test('format accepts already-formatted values from the API', () {
    expect(Masks.format(Masks.cep, '57035-180'), '57035-180');
    expect(Masks.format(Masks.cep, null), isNull);
    expect(Masks.digits('(82) 3142-2684'), '8231422684');
  });
}
