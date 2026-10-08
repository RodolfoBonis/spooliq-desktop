// Diagnóstico: `dart run tool/mesh_bench.dart arquivo.3mf|.stl`
import 'dart:io';

import 'package:spooliq_desktop/features/models3d/viewer/mesh.dart';

void main(List<String> args) {
  final sw = Stopwatch()..start();
  final bytes = File(args.single).readAsBytesSync();
  final mesh = parseMesh(bytes, fileName: args.single).placedOnPlate();
  final colors = <int, int>{};
  for (final c in mesh.triangleColors ?? <int>[]) {
    colors[c] = (colors[c] ?? 0) + 1;
  }
  stdout
    ..writeln('triângulos: ${mesh.triangleCount}')
    ..writeln(
      'tamanho: ${mesh.sizeX.toStringAsFixed(1)} × '
      '${mesh.sizeY.toStringAsFixed(1)} × ${mesh.sizeZ.toStringAsFixed(1)} mm',
    )
    ..writeln(
      'cores: ${colors.map((k, v) => MapEntry(k.toRadixString(16), v))}',
    )
    ..writeln('tempo: ${sw.elapsedMilliseconds} ms');
  final sw2 = Stopwatch()..start();
  final lod = mesh.simplified();
  stdout.writeln(
    'LOD: ${lod.triangleCount} triângulos em ${sw2.elapsedMilliseconds} ms',
  );
}
