import 'package:flutter/material.dart';
import 'package:forma_ui/forma_ui.dart';

/// Cabeçalho + corpo padrão das páginas.
class PageLayout extends StatelessWidget {
  const PageLayout({
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
    this.toolbar,
    this.leading,
    this.scrollable = false,
    this.maxWidth,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  /// Linha abaixo do título (busca, filtros, abas…).
  final Widget? toolbar;
  final Widget? leading;
  final Widget body;
  final bool scrollable;
  final double? maxWidth;

  static const padding = EdgeInsets.fromLTRB(28, 24, 28, 24);

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: typo.h4.copyWith(
                        color: ext.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: typo.body14.copyWith(color: ext.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              for (final (i, a) in actions.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                a,
              ],
            ],
          ),
          if (toolbar != null) ...[const SizedBox(height: 20), toolbar!],
        ],
      ),
    );

    Widget constrain(Widget child) => maxWidth == null
        ? child
        : Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth!),
              child: child,
            ),
          );

    // Rolagem da página inteira: o scrollbar fica na borda da janela e o
    // cabeçalho rola junto; a largura máxima é aplicada só ao conteúdo.
    if (scrollable) {
      return Scrollbar(
        child: SingleChildScrollView(
          primary: true,
          child: constrain(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
                  child: body,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return constrain(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

/// Card de seção com título opcional.
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.all(20),
    super.key,
  });

  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    // Material (e não DecoratedBox) para que ListTile/InkWell internos
    // desenhem hover e ripple corretamente.
    return Material(
      color: ext.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.formaShape.cardRadius),
        side: BorderSide(color: ext.border),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title!,
                          style: typo.title15.copyWith(color: ext.textPrimary),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: typo.caption12.copyWith(
                              color: ext.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 16),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
