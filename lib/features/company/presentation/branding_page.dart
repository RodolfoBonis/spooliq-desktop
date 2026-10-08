import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/ui/feedback.dart';
import 'package:spooliq_desktop/core/ui/page_layout.dart';
import 'package:spooliq_desktop/features/catalog/presentation/widgets/filament_swatch.dart';
import 'package:spooliq_desktop/features/company/domain/company.dart';
import 'package:spooliq_desktop/features/company/domain/company_repository.dart';

/// Cores do PDF do orçamento, com prévia ao vivo.
class BrandingPage extends StatefulWidget {
  const BrandingPage({super.key});

  @override
  State<BrandingPage> createState() => _BrandingPageState();
}

class _BrandingPageState extends State<BrandingPage> {
  final CompanyRepository _repo = di<CompanyRepository>();
  CompanyBranding? _original;
  CompanyBranding? _branding;
  List<BrandingTemplate> _templates = const [];
  String? _error;
  bool _saving = false;
  int _version = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final b = await _repo.branding();
      List<BrandingTemplate> templates;
      try {
        templates = await _repo.brandingTemplates();
      } on ApiError {
        templates = const [];
      }
      if (!mounted) return;
      setState(() {
        _original = b;
        _branding = b;
        _templates = templates;
        _version++;
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final saved = await _repo.updateBranding(_branding!);
      if (!mounted) return;
      setState(() {
        _original = saved;
        _branding = saved;
        _saving = false;
      });
      Toasts.success(context, 'Identidade do PDF salva');
    } on ApiError catch (e) {
      setState(() => _saving = false);
      if (mounted) Toasts.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _branding;
    if (b == null) {
      return _error != null
          ? ErrorView(message: _error!, onRetry: () => unawaited(_load()))
          : const LoadingView();
    }
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final dirty = b != _original;

    return PageLayout(
      title: 'Identidade do PDF',
      subtitle: 'Cores usadas nas propostas enviadas aos clientes.',
      actions: [
        if (dirty)
          FormaButton.secondary(
            label: 'Descartar',
            small: true,
            onPressed: () => setState(() {
              _branding = _original;
              _version++;
            }),
          ),
        FormaButton.primary(
          label: 'Salvar',
          small: true,
          isLoading: _saving,
          onPressed: dirty ? () => unawaited(_save()) : null,
        ),
      ],
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_templates.isNotEmpty) ...[
                    Text(
                      'Templates',
                      style: typo.title15.copyWith(color: ext.textPrimary),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final t in _templates)
                          _TemplateCard(
                            template: t,
                            selected: b.templateName == t.name,
                            onTap: () => setState(() {
                              _branding = CompanyBranding(
                                templateName: t.name,
                                colors: {...b.colors, ...t.branding.colors},
                              );
                              _version++;
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                  SectionCard(
                    title: 'Cores',
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 14,
                      children: [
                        for (final key in CompanyBranding.keys)
                          SizedBox(
                            width: 250,
                            child: _ColorInput(
                              key: ValueKey('$key-$_version'),
                              label: CompanyBranding.labels[key]!,
                              value: b.colors[key] ?? '#000000',
                              onChanged: (hex) => setState(
                                () =>
                                    _branding = _branding!.withColor(key, hex),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),
          SizedBox(width: 380, child: _PdfPreview(branding: b)),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.selected,
    required this.onTap,
  });

  final BrandingTemplate template;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final c = template.branding.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: ext.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? ext.primaryColor : ext.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  for (final k in const [
                    'header_bg_color',
                    'primary_color',
                    'secondary_color',
                    'accent_color',
                    'table_header_bg_color',
                  ])
                    Expanded(
                      child: Container(
                        height: 22,
                        color: parseHex(c[k]) ?? ext.border,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              template.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typo.body13.copyWith(color: ext.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorInput extends StatefulWidget {
  const _ColorInput({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_ColorInput> createState() => _ColorInputState();
}

class _ColorInputState extends State<_ColorInput> {
  late final _c = TextEditingController(text: widget.value.toUpperCase());

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    return FormaTextField(
      label: widget.label,
      controller: _c,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp('[#0-9a-fA-F]')),
        LengthLimitingTextInputFormatter(7),
      ],
      onChanged: (v) {
        setState(() {});
        final hex = v.startsWith('#') ? v : '#$v';
        if (parseHex(hex) != null) widget.onChanged(hex.toUpperCase());
      },
      prefix: Padding(
        padding: const EdgeInsets.all(9),
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: parseHex(_c.text) ?? Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: ext.border),
          ),
        ),
      ),
    );
  }
}

/// Miniatura de um orçamento em PDF com as cores escolhidas.
class _PdfPreview extends StatelessWidget {
  const _PdfPreview({required this.branding});

  final CompanyBranding branding;

  Color _c(String key, Color fallback) =>
      parseHex(branding.colors[key]) ?? fallback;

  @override
  Widget build(BuildContext context) {
    final bg = _c('background_color', Colors.white);
    final headerBg = _c('header_bg_color', const Color(0xFFFF6B6B));
    final headerText = _c('header_text_color', Colors.white);
    final title = _c('title_color', const Color(0xFF222222));
    final body = _c('body_text_color', const Color(0xFF555555));
    final border = _c('border_color', const Color(0xFFE8E8E8));
    final tableHeader = _c('table_header_bg_color', const Color(0xFFF7F7F7));
    final altRow = _c('table_row_alt_bg_color', const Color(0xFFFAFAFA));
    final primary = _c('primary_color', const Color(0xFFFF6B6B));
    final primaryText = _c('primary_text_color', Colors.white);
    final accent = _c('accent_color', const Color(0xFF26C5C5));

    TextStyle t(double size, Color color, [FontWeight w = FontWeight.w400]) =>
        TextStyle(
          fontFamily: 'Inter',
          fontSize: size,
          color: color,
          fontWeight: w,
        );

    Widget line(String a, String b, {bool alt = false}) => Container(
      color: alt ? altRow : bg,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(a, style: t(9, body))),
          Text(b, style: t(9, title, FontWeight.w600)),
        ],
      ),
    );

    return AspectRatio(
      aspectRatio: 1 / 1.414,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: headerBg,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Sua Empresa',
                    style: t(13, headerText, FontWeight.w700),
                  ),
                  const Spacer(),
                  Text('Orçamento #0042', style: t(9, headerText)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kit organizadores de mesa',
                    style: t(14, title, FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cliente: Ana Souza · válido até 30/10',
                    style: t(9, body),
                  ),
                  const SizedBox(height: 4),
                  Container(width: 40, height: 3, color: accent),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(border: Border.all(color: border)),
              child: Column(
                children: [
                  Container(
                    color: tableHeader,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Item',
                            style: t(9, title, FontWeight.w600),
                          ),
                        ),
                        Text('Total', style: t(9, title, FontWeight.w600)),
                      ],
                    ),
                  ),
                  line('Gaveteiro modular × 2', r'R$ 129,90'),
                  line('Porta-canetas × 4', r'R$ 86,00', alt: true),
                  line('Suporte de headset × 1', r'R$ 44,00'),
                ],
              ),
            ),
            const Spacer(),
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Text('Total', style: t(11, primaryText, FontWeight.w600)),
                  const Spacer(),
                  Text(
                    r'R$ 259,90',
                    style: t(15, primaryText, FontWeight.w800),
                  ),
                ],
              ),
            ),
            Container(
              color: _c('secondary_color', const Color(0xFF26C5C5)),
              padding: const EdgeInsets.symmetric(vertical: 6),
              alignment: Alignment.center,
              child: Text(
                'contato@suaempresa.com · (11) 99999-0000',
                style: t(8, _c('secondary_text_color', Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
