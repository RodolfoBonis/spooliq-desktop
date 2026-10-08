import 'package:flutter/material.dart';
import 'package:forma_ui/forma_ui.dart';

/// Moldura das telas públicas: painel de marca + formulário.
class AuthLayout extends StatelessWidget {
  const AuthLayout({required this.child, this.formWidth = 400, super.key});

  final Widget child;
  final double formWidth;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    return Scaffold(
      backgroundColor: ext.cardBackground,
      body: Row(
        children: [
          const Expanded(flex: 5, child: _BrandPanel()),
          Expanded(
            flex: 6,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  vertical: 48,
                  horizontal: 32,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: formWidth),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    const white = Colors.white;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ext.primaryColor,
            ext.primaryPress ?? ext.primaryColor,
            Color.lerp(
              ext.primaryPress ?? ext.primaryColor,
              Colors.black,
              0.35,
            )!,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Anéis concêntricos sugerindo um carretel de filamento.
          Positioned(
            right: -160,
            bottom: -160,
            child: CustomPaint(
              size: const Size(560, 560),
              painter: _SpoolPainter(white.withValues(alpha: 0.10)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'S',
                        style: typo.title18.copyWith(color: ext.primaryColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('SpoolIQ', style: typo.title18.copyWith(color: white)),
                  ],
                ),
                const Spacer(),
                Text(
                  'O preço real de cada\nimpressão 3D.',
                  style: typo.h2.copyWith(
                    color: white,
                    height: 1.15,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Filamento multicor, energia, desgaste, mão de obra e '
                  'margem — calculados com precisão, do orçamento à '
                  'entrega.',
                  style: typo.body16.copyWith(
                    color: white.withValues(alpha: 0.85),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                for (final (icon, text) in const [
                  (
                    Icons.view_kanban_outlined,
                    'Quadro kanban do orçamento à entrega',
                  ),
                  (
                    Icons.picture_as_pdf_outlined,
                    'Propostas em PDF e link de aprovação',
                  ),
                  (
                    Icons.inventory_2_outlined,
                    'Estoque de filamentos sempre em dia',
                  ),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, size: 18, color: white),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          text,
                          style: typo.body14Medium.copyWith(color: white),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                Text(
                  '© ${DateTime.now().year} SpoolIQ',
                  style: typo.caption12.copyWith(
                    color: white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpoolPainter extends CustomPainter {
  const _SpoolPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke;
    for (var r = size.width / 2; r > 40; r -= 18) {
      paint.strokeWidth = r > size.width / 3 ? 1.2 : 2;
      canvas.drawCircle(center, r, paint);
    }
    canvas.drawCircle(center, 40, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SpoolPainter old) => old.color != color;
}
