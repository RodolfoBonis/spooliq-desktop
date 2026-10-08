import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:spooliq_desktop/core/network/json.dart';
import 'package:spooliq_desktop/features/catalog/domain/catalog.dart';

/// Amostra circular da cor do filamento, por tipo de cor.
class FilamentSwatch extends StatelessWidget {
  const FilamentSwatch({
    this.colorHex,
    this.colorType = ColorType.solid,
    this.colorData,
    this.size = 16,
    super.key,
  });

  factory FilamentSwatch.of(Filament f, {double size = 16}) => FilamentSwatch(
    colorHex: f.colorHex,
    colorType: f.colorType,
    colorData: f.colorData,
    size: size,
  );

  final String? colorHex;
  final ColorType colorType;
  final Json? colorData;
  final double size;

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).dividerColor;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: border),
      ),
      child: ClipOval(
        child: CustomPaint(
          painter: _SwatchPainter(
            base: parseHex(colorHex) ?? parseHex(colorData?.strOrNull('color')),
            type: colorType,
            data: colorData,
          ),
        ),
      ),
    );
  }
}

/// `#RRGGBB` / `RRGGBB` → [Color].
Color? parseHex(String? hex) {
  if (hex == null) return null;
  final h = hex.replaceAll('#', '').trim();
  if (h.length != 6) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

class _SwatchPainter extends CustomPainter {
  const _SwatchPainter({required this.base, required this.type, this.data});

  final Color? base;
  final ColorType type;
  final Json? data;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final c = base ?? const Color(0xFF9D9D9D);
    final paint = Paint();

    switch (type) {
      case ColorType.gradient:
        final stops = data?.list('colors', (j) => parseHex(j.str('color')));
        final colors = stops?.whereType<Color>().toList() ?? const <Color>[];
        paint.shader = LinearGradient(
          colors: colors.length >= 2 ? colors : [c, c.withValues(alpha: 0.4)],
        ).createShader(rect);
        canvas.drawRect(rect, paint);
      case ColorType.duo:
        final a = parseHex(data?.strOrNull('primary')) ?? c;
        final b = parseHex(data?.strOrNull('secondary')) ?? Colors.white;
        canvas
          ..drawRect(rect, paint..color = a)
          ..drawPath(
            Path()
              ..moveTo(size.width, 0)
              ..lineTo(size.width, size.height)
              ..lineTo(0, size.height)
              ..close(),
            Paint()..color = b,
          );
      case ColorType.rainbow:
        paint.shader = const SweepGradient(
          colors: [
            Color(0xFFEF4444),
            Color(0xFFF59E0B),
            Color(0xFF22C55E),
            Color(0xFF3B82F6),
            Color(0xFF8B5CF6),
            Color(0xFFEF4444),
          ],
        ).createShader(rect);
        canvas.drawRect(rect, paint);
      case ColorType.metallic:
        final m = parseHex(data?.strOrNull('base_color')) ?? c;
        paint.shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(m, Colors.white, 0.55)!,
            m,
            Color.lerp(m, Colors.black, 0.35)!,
          ],
        ).createShader(rect);
        canvas.drawRect(rect, paint);
      case ColorType.transparent:
        final t = parseHex(data?.strOrNull('base_color')) ?? c;
        final cell = math.max(size.width / 4, 2).toDouble();
        for (var x = 0.0; x < size.width; x += cell) {
          for (var y = 0.0; y < size.height; y += cell) {
            final dark = ((x / cell).floor() + (y / cell).floor()).isEven;
            canvas.drawRect(
              Rect.fromLTWH(x, y, cell, cell),
              Paint()..color = dark ? const Color(0xFFD9D9D9) : Colors.white,
            );
          }
        }
        canvas.drawRect(rect, Paint()..color = t.withValues(alpha: 0.55));
      case ColorType.woodFill:
        canvas.drawRect(rect, paint..color = c);
        final grain = Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..strokeWidth = math.max(size.width / 16, 0.8)
          ..style = PaintingStyle.stroke;
        for (var i = 1; i < 4; i++) {
          canvas.drawLine(
            Offset(0, size.height * i / 4),
            Offset(size.width, size.height * i / 4 + 1),
            grain,
          );
        }
      case ColorType.carbonFiber:
        canvas.drawRect(rect, paint..color = const Color(0xFF2B2B2B));
        final weave = Paint()..color = Colors.white.withValues(alpha: 0.12);
        final cell = math.max(size.width / 4, 2).toDouble();
        for (var x = 0.0; x < size.width; x += cell) {
          for (var y = 0.0; y < size.height; y += cell) {
            if (((x / cell).floor() + (y / cell).floor()).isEven) {
              canvas.drawRect(Rect.fromLTWH(x, y, cell, cell / 2), weave);
            }
          }
        }
      case ColorType.solid:
        canvas.drawRect(rect, paint..color = c);
    }
  }

  @override
  bool shouldRepaint(_SwatchPainter old) =>
      old.base != base || old.type != type || old.data != data;
}
