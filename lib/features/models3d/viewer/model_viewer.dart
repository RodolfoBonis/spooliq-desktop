// Matemática vetorial densa: várias variáveis por linha deixam o código
// mais legível que uma declaração por linha.
// ignore_for_file: avoid_multiple_declarations_per_line

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/features/models3d/viewer/mesh.dart';

/// Visualizador 3D (estilo fatiador): mesa de impressão + modelo sombreado.
///
/// Arrastar gira, scroll aproxima, shift/botão direito + arrastar move,
/// duplo clique restaura a vista.
class ModelViewer extends StatefulWidget {
  const ModelViewer({
    required this.mesh,
    this.preview,
    this.color,
    this.plateSize = 256,
    super.key,
  });

  /// Malha já apoiada na mesa (veja [Mesh.placedOnPlate]).
  final Mesh mesh;

  /// Versão simplificada usada durante a interação (veja [Mesh.simplified]).
  final Mesh? preview;
  final Color? color;

  /// Lado da mesa em mm (P1S/X1 = 256).
  final double plateSize;

  @override
  State<ModelViewer> createState() => _ModelViewerState();
}

class _Camera {
  _Camera({
    required this.yaw,
    required this.pitch,
    required this.distance,
    required this.target,
  });

  double yaw;
  double pitch;
  double distance;
  List<double> target;

  _Camera copy() => _Camera(
    yaw: yaw,
    pitch: pitch,
    distance: distance,
    target: [...target],
  );
}

class _ModelViewerState extends State<ModelViewer> {
  late _Camera _home = _homeFor(widget.mesh);
  late _Camera _cam = _home.copy();
  Offset? _last;
  bool _panning = false;

  /// Enquanto interage, desenha uma versão reduzida para manter a fluidez.
  bool _interacting = false;
  Timer? _settle;

  void _touch() {
    _settle?.cancel();
    if (!_interacting) _interacting = true;
    _settle = Timer(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _interacting = false);
    });
  }

  @override
  void dispose() {
    _settle?.cancel();
    super.dispose();
  }

  static _Camera _homeFor(Mesh m) => _Camera(
    yaw: -math.pi / 4,
    pitch: 0.62,
    distance: math.max(m.radius * 2.3, 90),
    target: [0, 0, m.sizeZ / 2],
  );

  @override
  void didUpdateWidget(ModelViewer old) {
    super.didUpdateWidget(old);
    if (old.mesh != widget.mesh) {
      _home = _homeFor(widget.mesh);
      _cam = _home.copy();
    }
  }

  void _onPan(Offset delta) {
    _touch();
    setState(() {
      if (_panning) {
        final scale = _cam.distance / 600;
        final cy = math.cos(_cam.yaw);
        final sy = math.sin(_cam.yaw);
        _cam.target[0] -= (delta.dx * cy) * scale;
        _cam.target[1] -= (delta.dx * -sy) * scale;
        _cam.target[2] += delta.dy * scale;
      } else {
        _cam
          ..yaw -= delta.dx * 0.008
          ..pitch = (_cam.pitch + delta.dy * 0.008).clamp(
            -0.1,
            math.pi / 2 - 0.02,
          );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Listener(
      onPointerSignal: (e) {
        if (e is PointerScrollEvent) {
          _touch();
          setState(() {
            final f = math.exp(e.scrollDelta.dy * 0.0015);
            _cam.distance = (_cam.distance * f).clamp(20, 4000);
          });
        }
      },
      onPointerDown: (e) {
        _last = e.position;
        _panning =
            e.buttons == kSecondaryMouseButton ||
            HardwareKeyboard.instance.isShiftPressed;
      },
      onPointerMove: (e) {
        final last = _last;
        if (last == null) return;
        _onPan(e.position - last);
        _last = e.position;
      },
      onPointerUp: (_) => _last = null,
      child: GestureDetector(
        onDoubleTap: () => setState(() => _cam = _home.copy()),
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _ScenePainter(
                mesh: _interacting
                    ? (widget.preview ?? widget.mesh)
                    : widget.mesh,
                cam: _cam.copy(),
                modelColor: widget.color ?? ext.accentColor,
                background: dark
                    ? const Color(0xFF1B1D21)
                    : const Color(0xFFE9ECEF),
                plateColor: dark
                    ? const Color(0xFF2A2D33)
                    : const Color(0xFFD5DADF),
                gridColor: dark
                    ? const Color(0xFF3A3E46)
                    : const Color(0xFFB9C0C7),
                plateSize: widget.plateSize,
              ),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter({
    required this.mesh,
    required this.cam,
    required this.modelColor,
    required this.background,
    required this.plateColor,
    required this.gridColor,
    required this.plateSize,
  });

  final Mesh mesh;
  final _Camera cam;
  final Color modelColor;
  final Color background;
  final Color plateColor;
  final Color gridColor;
  final double plateSize;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    if (size.isEmpty) return;

    // Base da câmera (Z para cima).
    final cy = math.cos(cam.yaw), sy = math.sin(cam.yaw);
    final cp = math.cos(cam.pitch);
    final sp = math.sin(cam.pitch);
    // Posição do olho.
    final ex = cam.target[0] + cam.distance * cp * cy;
    final ey = cam.target[1] + cam.distance * cp * sy;
    final ez = cam.target[2] + cam.distance * sp;
    // Vetores: forward (olho→alvo), right, up.
    var fx = cam.target[0] - ex,
        fy = cam.target[1] - ey,
        fz = cam.target[2] - ez;
    final fl = math.sqrt(fx * fx + fy * fy + fz * fz);
    fx /= fl;
    fy /= fl;
    fz /= fl;
    var rx = fy;
    var ry = -fx;
    const rz = 0.0; // forward × Z
    final rl = math.sqrt(rx * rx + ry * ry) + 1e-9;
    rx /= rl;
    ry /= rl;
    final ux = ry * fz - rz * fy;
    final uy = rz * fx - rx * fz;
    final uz = rx * fy - ry * fx;

    final focal = size.shortestSide * 1.1;
    final cx = size.width / 2;
    final cyy = size.height / 2;

    // Projeta um ponto: retorna (sx, sy, depth); depth <= 0 → atrás.
    (double, double, double) project(double x, double y, double z) {
      final dx = x - ex;
      final dy = y - ey;
      final dz = z - ez;
      final d = dx * fx + dy * fy + dz * fz;
      final px = dx * rx + dy * ry + dz * rz;
      final py = dx * ux + dy * uy + dz * uz;
      if (d <= 1) return (0, 0, -1);
      return (cx + px / d * focal, cyy - py / d * focal, d);
    }

    _paintPlate(canvas, project);
    _paintMesh(canvas, project, (fx, fy, fz));
  }

  void _paintPlate(
    Canvas canvas,
    (double, double, double) Function(double, double, double) project,
  ) {
    final h = plateSize / 2;
    final corners = [
      project(-h, -h, 0),
      project(h, -h, 0),
      project(h, h, 0),
      project(-h, h, 0),
    ];
    if (corners.any((c) => c.$3 <= 0)) return;
    final path = Path()..moveTo(corners[0].$1, corners[0].$2);
    for (final c in corners.skip(1)) {
      path.lineTo(c.$1, c.$2);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = plateColor);

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final major = Paint()
      ..color = gridColor.withValues(alpha: 1)
      ..strokeWidth = 1.6;
    for (var v = -h; v <= h + 0.01; v += 10) {
      final isMajor = (v.round() % 50) == 0;
      final a = project(v, -h, 0);
      final b = project(v, h, 0);
      final c = project(-h, v, 0);
      final d = project(h, v, 0);
      canvas
        ..drawLine(
          Offset(a.$1, a.$2),
          Offset(b.$1, b.$2),
          isMajor ? major : grid,
        )
        ..drawLine(
          Offset(c.$1, c.$2),
          Offset(d.$1, d.$2),
          isMajor ? major : grid,
        );
    }
  }

  void _paintMesh(
    Canvas canvas,
    (double, double, double) Function(double, double, double) project,
    (double, double, double) forward,
  ) {
    final p = mesh.positions;
    final n = mesh.triangleCount;
    if (n == 0) return;

    final screen = Float32List(n * 6);
    final depth = Float32List(n);
    final shade = Float32List(n);
    final visible = Uint8List(n);
    var minD = double.infinity;
    var maxD = 0.0;

    // Luz: vinda do observador, um pouco de cima.
    const lx = 0.3, ly = 0.4, lz = 0.866;

    final perTri = mesh.triangleColors;
    for (var t = 0; t < n; t++) {
      final o = t * 9;
      final ax = p[o];
      final ay = p[o + 1];
      final az = p[o + 2];
      final bx = p[o + 3];
      final by = p[o + 4];
      final bz = p[o + 5];
      final qx = p[o + 6];
      final qy = p[o + 7];
      final qz = p[o + 8];
      // Normal da face.
      final e1x = bx - ax, e1y = by - ay, e1z = bz - az;
      final e2x = qx - ax;
      final e2y = qy - ay;
      final e2z = qz - az;
      var nx = e1y * e2z - e1z * e2y;
      var ny = e1z * e2x - e1x * e2z;
      var nz = e1x * e2y - e1y * e2x;
      final nl = math.sqrt(nx * nx + ny * ny + nz * nz);
      if (nl == 0) continue;
      nx /= nl;
      ny /= nl;
      nz /= nl;
      // Sem back-face culling: STLs com orientação inconsistente ficariam
      // com buracos; a ordenação por profundidade resolve a oclusão.

      final pa = project(ax, ay, az);
      final pb = project(bx, by, bz);
      final pc = project(qx, qy, qz);
      if (pa.$3 <= 0 || pb.$3 <= 0 || pc.$3 <= 0) continue;

      final s = t * 6;
      screen[s] = pa.$1;
      screen[s + 1] = pa.$2;
      screen[s + 2] = pb.$1;
      screen[s + 3] = pb.$2;
      screen[s + 4] = pc.$1;
      screen[s + 5] = pc.$2;
      final d = (pa.$3 + pb.$3 + pc.$3) / 3;
      depth[t] = d;
      if (d < minD) minD = d;
      if (d > maxD) maxD = d;
      // Iluminação: lambert + rim leve vindo da câmera.
      final lambert = (nx * lx + ny * ly + nz * lz).abs();
      final facing = (nx * forward.$1 + ny * forward.$2 + nz * forward.$3)
          .abs();
      shade[t] = (0.28 + 0.52 * lambert + 0.25 * facing).clamp(0.15, 1.0);
      visible[t] = 1;
    }

    // Ordenação de trás para frente em O(n) por baldes de profundidade.
    const buckets = 4096;
    final range = (maxD - minD).abs() < 1e-6 ? 1.0 : maxD - minD;
    final counts = Int32List(buckets + 1);
    for (var t = 0; t < n; t++) {
      if (visible[t] == 0) continue;
      final b = ((maxD - depth[t]) / range * (buckets - 1)).toInt();
      counts[b + 1]++;
    }
    for (var i = 1; i <= buckets; i++) {
      counts[i] += counts[i - 1];
    }
    final total = counts[buckets];
    final order = Int32List(total);
    final cursor = Int32List.fromList(counts.sublist(0, buckets));
    for (var t = 0; t < n; t++) {
      if (visible[t] == 0) continue;
      final b = ((maxD - depth[t]) / range * (buckets - 1)).toInt();
      order[cursor[b]++] = t;
    }

    final positions = Float32List(total * 6);
    final colors = Int32List(total * 3);
    final baseR = (modelColor.r * 255).round();
    final baseG = (modelColor.g * 255).round();
    final baseB = (modelColor.b * 255).round();
    for (var i = 0; i < total; i++) {
      final t = order[i];
      final s = t * 6;
      positions.setRange(i * 6, i * 6 + 6, screen, s);
      final k = shade[t];
      final tc = perTri?[t];
      final r = tc == null ? baseR : (tc >> 16) & 0xFF;
      final g = tc == null ? baseG : (tc >> 8) & 0xFF;
      final bl = tc == null ? baseB : tc & 0xFF;
      final c =
          0xFF000000 |
          ((r * k).round().clamp(0, 255) << 16) |
          ((g * k).round().clamp(0, 255) << 8) |
          (bl * k).round().clamp(0, 255);
      colors[i * 3] = c;
      colors[i * 3 + 1] = c;
      colors[i * 3 + 2] = c;
    }
    final vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      positions,
      colors: colors,
    );
    canvas.drawVertices(vertices, BlendMode.dst, Paint());
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.mesh != mesh ||
      old.cam.yaw != cam.yaw ||
      old.cam.pitch != cam.pitch ||
      old.cam.distance != cam.distance ||
      old.cam.target.join() != cam.target.join() ||
      old.modelColor != modelColor ||
      old.background != background;
}
