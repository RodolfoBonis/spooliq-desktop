import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Malha triangular "sopa de triângulos": 9 floats por triângulo.
class Mesh {
  Mesh(this.positions, {this.triangleColors})
    : assert(positions.length % 9 == 0, 'positions must be xyz × 3 per tri') {
    _computeBounds();
  }

  final Float32List positions;

  /// Cor ARGB por triângulo (ex.: pintura multicolor do Bambu Studio).
  /// `null` = usar a cor padrão do visualizador.
  final Int32List? triangleColors;
  late final double minX, minY, minZ, maxX, maxY, maxZ;

  int get triangleCount => positions.length ~/ 9;

  double get sizeX => maxX - minX;
  double get sizeY => maxY - minY;
  double get sizeZ => maxZ - minZ;
  double get radius =>
      math.sqrt(sizeX * sizeX + sizeY * sizeY + sizeZ * sizeZ) / 2;

  void _computeBounds() {
    var x0 = double.infinity, y0 = double.infinity, z0 = double.infinity;
    var x1 = -double.infinity, y1 = -double.infinity, z1 = -double.infinity;
    final p = positions;
    for (var i = 0; i < p.length; i += 3) {
      final x = p[i], y = p[i + 1], z = p[i + 2];
      if (x < x0) x0 = x;
      if (y < y0) y0 = y;
      if (z < z0) z0 = z;
      if (x > x1) x1 = x;
      if (y > y1) y1 = y;
      if (z > z1) z1 = z;
    }
    if (p.isEmpty) x0 = y0 = z0 = x1 = y1 = z1 = 0;
    minX = x0;
    minY = y0;
    minZ = z0;
    maxX = x1;
    maxY = y1;
    maxZ = z1;
  }

  /// Versão simplificada (LOD) por agrupamento de vértices numa grade 3D:
  /// vértices na mesma célula são fundidos e triângulos degenerados somem.
  /// A malha continua fechada (sem "furos"), só com menos detalhe.
  Mesh simplified({int targetTriangles = 120000}) {
    if (triangleCount <= targetTriangles) return this;
    // Triângulos de superfície ~ resolução²: ajusta a grade até o alvo.
    var res = 160.0;
    var result = _cluster(res.toInt());
    for (var i = 0; i < 3; i++) {
      final count = result.triangleCount;
      if (count <= targetTriangles * 1.15) break;
      res *= math.sqrt(targetTriangles / count);
      result = _cluster(res.toInt());
    }
    return result;
  }

  Mesh _cluster(int gridResolution) {
    final n = triangleCount;
    var res = gridResolution.clamp(16, 1024);
    final maxSide = math.max(sizeX, math.max(sizeY, sizeZ));
    if (maxSide <= 0) return this;
    final cell = maxSide / res;
    res += 2;

    final colors = triangleColors;
    // Soma das posições por célula para usar o centroide.
    final sums = <int, List<double>>{};
    int key(double x, double y, double z) {
      final ix = ((x - minX) / cell).floor();
      final iy = ((y - minY) / cell).floor();
      final iz = ((z - minZ) / cell).floor();
      return (ix * res + iy) * res + iz;
    }

    final keys = Int64List(n * 3);
    final p = positions;
    for (var v = 0; v < n * 3; v++) {
      final x = p[v * 3], y = p[v * 3 + 1], z = p[v * 3 + 2];
      final k = key(x, y, z);
      keys[v] = k;
      final acc = sums.putIfAbsent(k, () => [0, 0, 0, 0]);
      acc[0] += x;
      acc[1] += y;
      acc[2] += z;
      acc[3] += 1;
    }

    final out = <double>[];
    final outColors = <int>[];
    final seen = <String>{};
    for (var t = 0; t < n; t++) {
      final a = keys[t * 3], b = keys[t * 3 + 1], c = keys[t * 3 + 2];
      if (a == b || b == c || a == c) continue;
      // Ordena para deduplicar o mesmo triângulo colapsado.
      final sorted = [a, b, c]..sort();
      if (!seen.add(sorted.join(','))) continue;
      for (final k in [a, b, c]) {
        final acc = sums[k]!;
        out
          ..add(acc[0] / acc[3])
          ..add(acc[1] / acc[3])
          ..add(acc[2] / acc[3]);
      }
      if (colors != null) outColors.add(colors[t]);
    }
    return Mesh(
      Float32List.fromList(out),
      triangleColors: colors == null ? null : Int32List.fromList(outColors),
    );
  }

  /// Centraliza em XY e apoia na mesa (z mínimo = 0).
  Mesh placedOnPlate() {
    final cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
    final out = Float32List(positions.length);
    for (var i = 0; i < positions.length; i += 3) {
      out[i] = positions[i] - cx;
      out[i + 1] = positions[i + 1] - cy;
      out[i + 2] = positions[i + 2] - minZ;
    }
    return Mesh(out, triangleColors: triangleColors);
  }
}

class MeshFormatException implements Exception {
  const MeshFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Lê STL (binário/ASCII) ou 3MF a partir dos bytes do arquivo.
Mesh parseMesh(Uint8List bytes, {String? fileName}) {
  final name = (fileName ?? '').toLowerCase();
  final isZip = bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B;
  if (name.endsWith('.3mf') || isZip) return parse3mf(bytes);
  return parseStl(bytes);
}

Mesh parseStl(Uint8List bytes) {
  if (bytes.length >= 84) {
    final data = ByteData.sublistView(bytes);
    final count = data.getUint32(80, Endian.little);
    if (84 + count * 50 == bytes.length) {
      final out = Float32List(count * 9);
      var o = 0;
      for (var t = 0; t < count; t++) {
        final base = 84 + t * 50 + 12; // pula a normal
        for (var k = 0; k < 9; k++) {
          out[o++] = data.getFloat32(base + k * 4, Endian.little);
        }
      }
      return Mesh(out);
    }
  }
  // ASCII.
  final text = latin1.decode(bytes, allowInvalid: true);
  final values = <double>[];
  for (final m in RegExp(
    r'vertex\s+([-+0-9.eE]+)\s+([-+0-9.eE]+)\s+([-+0-9.eE]+)',
  ).allMatches(text)) {
    values
      ..add(double.parse(m[1]!))
      ..add(double.parse(m[2]!))
      ..add(double.parse(m[3]!));
  }
  if (values.isEmpty || values.length % 9 != 0) {
    throw const MeshFormatException('Arquivo STL inválido ou vazio.');
  }
  return Mesh(Float32List.fromList(values));
}

/// 3MF: lê os objetos de malha (inclusive componentes em outros arquivos do
/// pacote, como nos projetos do Bambu Studio), aplica as transformações do
/// `<build>` e, quando houver, as cores de pintura (`paint_color`) por
/// filamento do projeto.
///
/// Usa um scanner manual em vez de um parser XML: arquivos do Bambu chegam a
/// 70 MB de XML só de malha.
Mesh parse3mf(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final models = <String, String>{};
  String? projectSettings;
  String? modelSettings;
  for (final f in archive.files) {
    if (!f.isFile) continue;
    final name = f.name.replaceAll(r'\', '/');
    final lower = name.toLowerCase();
    if (lower.endsWith('.model')) {
      models['/$name'] = utf8.decode(
        f.content as List<int>,
        allowMalformed: true,
      );
    } else if (lower == 'metadata/project_settings.config') {
      projectSettings = utf8.decode(
        f.content as List<int>,
        allowMalformed: true,
      );
    } else if (lower == 'metadata/model_settings.config') {
      modelSettings = utf8.decode(f.content as List<int>, allowMalformed: true);
    }
  }
  if (models.isEmpty) throw const MeshFormatException('3MF sem modelo 3D.');
  final rootPath = models.keys.firstWhere(
    (p) => p.toLowerCase() == '/3d/3dmodel.model',
    orElse: () => models.keys.first,
  );

  final palette = _filamentPalette(projectSettings);
  final defaultExtruders = _objectExtruders(modelSettings);

  final out = <double>[];
  final colors = <int>[];
  var anyColor = false;

  void emitObject(String path, String id, List<double> m, int depth, int ext) {
    if (depth > 8) return;
    final xml = models[path];
    if (xml == null) return;
    final obj = _findObject(xml, id);
    if (obj == null) return;
    // IDs se repetem entre arquivos: o padrão vale só para o modelo raiz.
    final extruder = path == rootPath ? (defaultExtruders[id] ?? ext) : ext;

    final meshStart = obj.indexOf('<mesh');
    if (meshStart >= 0) {
      final verts = <double>[];
      var pos = obj.indexOf('<vertex', meshStart);
      while (pos >= 0) {
        final end = obj.indexOf('>', pos);
        verts
          ..add(_attrNum(obj, pos, end, 'x'))
          ..add(_attrNum(obj, pos, end, 'y'))
          ..add(_attrNum(obj, pos, end, 'z'));
        pos = obj.indexOf('<vertex', end);
      }
      pos = obj.indexOf('<triangle', meshStart);
      while (pos >= 0) {
        final end = obj.indexOf('>', pos);
        final a = _attrNum(obj, pos, end, 'v1').toInt() * 3;
        final b = _attrNum(obj, pos, end, 'v2').toInt() * 3;
        final c = _attrNum(obj, pos, end, 'v3').toInt() * 3;
        if (a + 2 < verts.length &&
            b + 2 < verts.length &&
            c + 2 < verts.length) {
          for (final i in [a, b, c]) {
            final x = verts[i], y = verts[i + 1], z = verts[i + 2];
            out
              ..add(m[0] * x + m[3] * y + m[6] * z + m[9])
              ..add(m[1] * x + m[4] * y + m[7] * z + m[10])
              ..add(m[2] * x + m[5] * y + m[8] * z + m[11]);
          }
          final paint = _attr(obj, pos, end, 'paint_color');
          final filament = paint == null
              ? extruder
              : _decodePaint(paint) ?? extruder;
          if (paint != null) anyColor = true;
          colors.add(
            filament >= 1 && filament <= palette.length
                ? palette[filament - 1]
                : 0,
          );
        }
        pos = obj.indexOf('<triangle', end);
      }
    }

    var c = obj.indexOf('<component');
    while (c >= 0) {
      final end = obj.indexOf('>', c);
      if (obj.startsWith('<components', c)) {
        c = obj.indexOf('<component', end);
        continue;
      }
      final childPath =
          _attr(obj, c, end, 'p:path') ?? _attr(obj, c, end, 'path') ?? path;
      emitObject(
        childPath,
        _attr(obj, c, end, 'objectid') ?? '',
        _mul(m, _parseTransform(_attr(obj, c, end, 'transform'))),
        depth + 1,
        extruder,
      );
      c = obj.indexOf('<component', end);
    }
  }

  final root = models[rootPath]!;
  final buildStart = root.indexOf('<build');
  var item = buildStart < 0 ? -1 : root.indexOf('<item', buildStart);
  if (item < 0) {
    var o = root.indexOf('<object');
    while (o >= 0) {
      final end = root.indexOf('>', o);
      emitObject(rootPath, _attr(root, o, end, 'id') ?? '', _identity, 0, 1);
      o = root.indexOf('<object', end);
    }
  }
  while (item >= 0) {
    final end = root.indexOf('>', item);
    emitObject(
      _attr(root, item, end, 'p:path') ??
          _attr(root, item, end, 'path') ??
          rootPath,
      _attr(root, item, end, 'objectid') ?? '',
      _parseTransform(_attr(root, item, end, 'transform')),
      0,
      1,
    );
    item = root.indexOf('<item', end);
  }

  if (out.isEmpty) throw const MeshFormatException('O 3MF não contém malhas.');
  final hasPalette =
      palette.isNotEmpty && (anyColor || defaultExtruders.isNotEmpty);
  return Mesh(
    Float32List.fromList(out),
    triangleColors: hasPalette && colors.every((c) => c != 0)
        ? Int32List.fromList(colors)
        : null,
  );
}

/// Recorta o elemento `<object id="…">…</object>` do XML.
String? _findObject(String xml, String id) {
  var pos = xml.indexOf('<object');
  while (pos >= 0) {
    final end = xml.indexOf('>', pos);
    if (_attr(xml, pos, end, 'id') == id) {
      final close = xml.indexOf('</object>', end);
      return xml.substring(pos, close < 0 ? xml.length : close);
    }
    pos = xml.indexOf('<object', end);
  }
  return null;
}

/// Valor do atributo `name="…"` dentro da tag `[start, end)`.
///
/// A busca é limitada à tag: procurar no texto inteiro tornaria o parse
/// quadrático quando o atributo não existe.
String? _attr(String s, int start, int end, String name) {
  final limit = end < 0 ? s.length : end;
  var i = start;
  while (true) {
    i = s.indexOf(name, i);
    if (i < 0 || i >= limit) return null;
    final before = s.codeUnitAt(i - 1);
    final after = i + name.length;
    if ((before == 0x20 || before == 0x09 || before == 0x0A) &&
        after + 1 < s.length &&
        s.codeUnitAt(after) == 0x3D && // =
        s.codeUnitAt(after + 1) == 0x22) {
      final v = after + 2;
      final close = s.indexOf('"', v);
      return close < 0 || close > limit ? null : s.substring(v, close);
    }
    i = after;
  }
}

double _attrNum(String s, int start, int end, String name) =>
    double.tryParse(_attr(s, start, end, name) ?? '') ?? 0;

/// Decodifica `paint_color` do Bambu/Orca (TriangleSelector serializado em
/// hexa, do fim para o início): "4"→1, "8"→2, "0C"→3, "1C"→4, "2C"→5…
/// Para triângulos subdivididos usa a primeira folha.
int? _decodePaint(String code) {
  for (var i = code.length - 1; i >= 0; i--) {
    final nibble = int.tryParse(code[i], radix: 16);
    if (nibble == null) return null;
    final split = nibble & 0x3;
    if (split != 0) continue; // nó subdividido: desce para os filhos
    final state = nibble >> 2;
    if (state == 3) {
      if (i == 0) return null;
      final next = int.tryParse(code[i - 1], radix: 16);
      return next == null ? null : next + 3;
    }
    return state == 0 ? null : state;
  }
  return null;
}

/// Cores dos filamentos do projeto (`filament_colour`), em ARGB.
List<int> _filamentPalette(String? config) {
  if (config == null) return const [];
  try {
    final json = jsonDecode(config);
    final raw = json is Map ? json['filament_colour'] : null;
    if (raw is! List) return const [];
    return [
      for (final c in raw)
        0xFF000000 |
            (int.tryParse(
                  c
                      .toString()
                      .replaceAll('#', '')
                      .padRight(6, '0')
                      .substring(0, 6),
                  radix: 16,
                ) ??
                0x9D9D9D),
    ];
  } on FormatException {
    return const [];
  }
}

/// Extrusora padrão de cada objeto (`model_settings.config`).
Map<String, int> _objectExtruders(String? config) {
  if (config == null) return const {};
  final result = <String, int>{};
  final re = RegExp(
    r'<object id="(\d+)">\s*(?:<metadata[^>]*>\s*)*?<metadata key="extruder" value="(\d+)"',
  );
  for (final m in re.allMatches(config)) {
    result[m[1]!] = int.parse(m[2]!);
  }
  return result;
}

const _identity = <double>[1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0];

/// Transform 3MF: "m00 m01 m02 m10 m11 m12 m20 m21 m22 m30 m31 m32".
List<double> _parseTransform(String? raw) {
  if (raw == null || raw.trim().isEmpty) return _identity;
  final v = raw.trim().split(RegExp(r'\s+')).map(double.parse).toList();
  return v.length == 12 ? v : _identity;
}

/// Compõe `outer ∘ inner` (aplica inner primeiro).
List<double> _mul(List<double> outer, List<double> inner) {
  double m(List<double> a, int r, int c) => a[r * 3 + c];
  final r = List<double>.filled(12, 0);
  for (var row = 0; row < 3; row++) {
    for (var col = 0; col < 3; col++) {
      r[row * 3 + col] =
          m(inner, row, 0) * m(outer, 0, col) +
          m(inner, row, 1) * m(outer, 1, col) +
          m(inner, row, 2) * m(outer, 2, col);
    }
  }
  for (var col = 0; col < 3; col++) {
    r[9 + col] =
        inner[9] * outer[col] +
        inner[10] * outer[3 + col] +
        inner[11] * outer[6 + col] +
        outer[9 + col];
  }
  return r;
}
