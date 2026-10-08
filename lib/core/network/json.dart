/// Leitura tolerante de JSON da API.
///
/// A API mistura `null`, ausência de campo, números como `int`/`double` e
/// datas RFC3339. Estes helpers centralizam a conversão para que os modelos
/// fiquem declarativos e nunca lancem `TypeError` por um campo opcional.
typedef Json = Map<String, dynamic>;

extension JsonRead on Json {
  String str(String key, [String fallback = '']) {
    final v = this[key];
    if (v == null) return fallback;
    return v is String ? v : v.toString();
  }

  String? strOrNull(String key) {
    final v = this[key];
    if (v == null) return null;
    final s = v is String ? v : v.toString();
    return s.isEmpty ? null : s;
  }

  int integer(String key, [int fallback = 0]) => intOrNull(key) ?? fallback;

  int? intOrNull(String key) {
    final v = this[key];
    return switch (v) {
      final int i => i,
      final num n => n.round(),
      final String s => int.tryParse(s) ?? double.tryParse(s)?.round(),
      _ => null,
    };
  }

  double dbl(String key, [double fallback = 0]) => dblOrNull(key) ?? fallback;

  double? dblOrNull(String key) {
    final v = this[key];
    return switch (v) {
      final num n => n.toDouble(),
      final String s => double.tryParse(s),
      _ => null,
    };
  }

  bool boolean(String key, {bool fallback = false}) {
    final v = this[key];
    return switch (v) {
      final bool b => b,
      final String s => s == 'true',
      final num n => n != 0,
      _ => fallback,
    };
  }

  bool? boolOrNull(String key) => this[key] == null ? null : boolean(key);

  DateTime? date(String key) {
    final v = this[key];
    if (v is! String || v.isEmpty) return null;
    // A API às vezes devolve o zero-value do Go.
    if (v.startsWith('0001-01-01')) return null;
    return DateTime.tryParse(v)?.toLocal();
  }

  Json? obj(String key) {
    final v = this[key];
    return v is Map ? Map<String, dynamic>.from(v) : null;
  }

  List<T> list<T>(String key, T Function(Json json) parse) {
    final v = this[key];
    if (v is! List) return const [];
    return [
      for (final e in v)
        if (e is Map) parse(Map<String, dynamic>.from(e)),
    ];
  }

  List<String> strings(String key) {
    final v = this[key];
    if (v is! List) return const [];
    return [for (final e in v) e.toString()];
  }

  /// Desembrulha respostas `{data: {...}}` (ex.: GET /brands/{id}).
  Json unwrapData() {
    final inner = this['data'];
    return inner is Map ? Map<String, dynamic>.from(inner) : this;
  }
}

/// Remove chaves nulas antes de enviar à API.
Json compactJson(Json json) =>
    Map.fromEntries(json.entries.where((e) => e.value != null));
