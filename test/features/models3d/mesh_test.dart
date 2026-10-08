import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spooliq_desktop/features/models3d/viewer/mesh.dart';

/// STL binário com [tris] triângulos (9 floats cada).
Uint8List binaryStl(List<List<double>> tris) {
  final data = ByteData(84 + tris.length * 50)
    ..setUint32(80, tris.length, Endian.little);
  for (final (t, tri) in tris.indexed) {
    final base = 84 + t * 50 + 12;
    for (var k = 0; k < 9; k++) {
      data.setFloat32(base + k * 4, tri[k], Endian.little);
    }
  }
  return data.buffer.asUint8List();
}

Uint8List zip(Map<String, String> files) {
  final archive = Archive();
  for (final e in files.entries) {
    final bytes = utf8.encode(e.value);
    archive.addFile(ArchiveFile(e.key, bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  const tri = <double>[0, 0, 0, 10, 0, 0, 0, 10, 5];

  group('STL', () {
    test('parses binary STL and computes bounds', () {
      final mesh = parseMesh(binaryStl([tri, tri]), fileName: 'a.stl');
      expect(mesh.triangleCount, 2);
      expect(mesh.sizeX, 10);
      expect(mesh.sizeZ, 5);
      expect(mesh.triangleColors, isNull);
    });

    test('parses ASCII STL', () {
      const ascii = '''
solid test
 facet normal 0 0 1
  outer loop
   vertex 0 0 0
   vertex 1 0 0
   vertex 0 1 0
  endloop
 endfacet
endsolid''';
      final mesh = parseMesh(Uint8List.fromList(utf8.encode(ascii)));
      expect(mesh.triangleCount, 1);
    });

    test('rejects garbage', () {
      expect(
        () => parseMesh(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<MeshFormatException>()),
      );
    });

    test('placedOnPlate centers XY and rests on z = 0', () {
      final mesh = Mesh(
        Float32List.fromList([10, 10, 3, 20, 10, 3, 10, 20, 8]),
      ).placedOnPlate();
      expect(mesh.minZ, 0);
      expect(mesh.minX, -5);
      expect(mesh.maxX, 5);
    });
  });

  group('3MF', () {
    const root = '''
<model unit="millimeter" xmlns:p="http://schemas.microsoft.com/3dmanufacturing/production/2015/06">
 <resources>
  <object id="2" type="model">
   <components>
    <component p:path="/3D/Objects/object_1.model" objectid="1" transform="1 0 0 0 1 0 0 0 1 0 0 0"/>
   </components>
  </object>
 </resources>
 <build>
  <item objectid="2" transform="2 0 0 0 2 0 0 0 2 100 0 0"/>
 </build>
</model>''';
    const object = '''
<model>
 <resources>
  <object id="1" type="model">
   <mesh>
    <vertices>
     <vertex x="0" y="0" z="0"/>
     <vertex x="1" y="0" z="0"/>
     <vertex x="0" y="1" z="0"/>
     <vertex x="0" y="0" z="1"/>
    </vertices>
    <triangles>
     <triangle v1="0" v2="1" v3="2" paint_color="8"/>
     <triangle v1="0" v2="1" v3="3" paint_color="0C"/>
     <triangle v1="0" v2="2" v3="3"/>
    </triangles>
   </mesh>
  </object>
 </resources>
</model>''';
    final settings = jsonEncode({
      'filament_colour': ['#000000', '#0ACC38', '#5E43B7'],
    });

    test('follows components and applies the build transform', () {
      final mesh = parse3mf(
        zip({
          '3D/3dmodel.model': root,
          '3D/Objects/object_1.model': object,
        }),
      );
      expect(mesh.triangleCount, 3);
      expect(mesh.minX, 100);
      expect(mesh.maxX, 102); // escala 2 + translação 100
    });

    test('maps paint_color to the project filament palette', () {
      final mesh = parse3mf(
        zip({
          '3D/3dmodel.model': root,
          '3D/Objects/object_1.model': object,
          'Metadata/project_settings.config': settings,
        }),
      );
      expect(
        mesh.triangleColors,
        [
          0xFF0ACC38, // "8"  → filamento 2
          0xFF5E43B7, // "0C" → filamento 3
          0xFF000000, // sem pintura → filamento padrão 1
        ].map((c) => c.toSigned(32)).toList(),
      );
    });

    test('simplified keeps a closed, smaller mesh', () {
      // Grade densa de triângulos num plano.
      final values = <double>[];
      for (var i = 0; i < 200; i++) {
        for (var j = 0; j < 200; j++) {
          values.addAll([
            i.toDouble(),
            j.toDouble(),
            0,
            i + 1.0,
            j.toDouble(),
            0,
            i.toDouble(),
            j + 1.0,
            0,
          ]);
        }
      }
      final mesh = Mesh(Float32List.fromList(values));
      final lod = mesh.simplified(targetTriangles: 5000);
      expect(lod.triangleCount, lessThan(mesh.triangleCount));
      expect(lod.triangleCount, greaterThan(0));
      expect(lod.sizeX, closeTo(mesh.sizeX, 3));
    });
  });
}
