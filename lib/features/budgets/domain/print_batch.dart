/// Lote de impressão de um arquivo fatiado que produz [unitsPerPrint] peças
/// por impressão, escalado para [quantity] peças.
///
/// Material, tempo e trabalho escalam proporcionalmente (25 peças com um
/// arquivo de 10 = 2,5×); o setup é por impressão e arredonda para cima
/// (3 impressões).
class PrintBatch {
  const PrintBatch({required this.quantity, required this.unitsPerPrint})
    : assert(unitsPerPrint > 0, 'unitsPerPrint must be positive');

  final int quantity;
  final int unitsPerPrint;

  /// Fator proporcional entre a quantidade e uma impressão.
  double get factor => quantity / unitsPerPrint;

  /// Impressões necessárias (para o setup).
  int get runs => quantity <= 0 ? 0 : (quantity / unitsPerPrint).ceil();

  /// Minutos de uma impressão → total para a quantidade.
  int scaleMinutes(int perRun) => (perRun * factor).round();

  /// Total salvo → minutos de uma impressão.
  int unscaleMinutes(int total) =>
      factor == 0 ? total : (total / factor).round();

  /// Gramas de uma impressão → total (0,1 g).
  double scaleGrams(double perRun) => _round1(perRun * factor);

  /// Total salvo → gramas de uma impressão (0,1 g).
  double unscaleGrams(double total) =>
      factor == 0 ? total : _round1(total / factor);

  /// Setup de uma impressão → total (por impressão).
  int scaleSetup(int perRun) => perRun * runs;

  /// Setup total salvo → setup de uma impressão.
  int unscaleSetup(int total) => runs == 0 ? total : (total / runs).round();

  static double _round1(double v) => (v * 10).roundToDouble() / 10;
}
