import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/core/auth/permissions.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/format/masks.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/ui/feedback.dart';
import 'package:spooliq_desktop/core/ui/page_layout.dart';
import 'package:spooliq_desktop/features/auth/presentation/session_cubit.dart';
import 'package:spooliq_desktop/features/company/domain/company.dart';
import 'package:spooliq_desktop/features/company/domain/company_repository.dart';
import 'package:spooliq_desktop/features/company/presentation/current_company_cubit.dart';

class CompanySettingsPage extends StatefulWidget {
  const CompanySettingsPage({super.key});

  @override
  State<CompanySettingsPage> createState() => _CompanySettingsPageState();
}

class _CompanySettingsPageState extends State<CompanySettingsPage> {
  final CompanyRepository _repo = di<CompanyRepository>();
  Company? _original;
  Company? _company;
  String? _error;
  bool _saving = false;
  bool _uploading = false;
  int _formVersion = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final c = await _repo.get();
      if (mounted) {
        setState(() {
          _original = c;
          _company = c;
          _formVersion++;
        });
      }
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  bool get _dirty => _company != _original;

  void _set(Company Function(Company) change) =>
      setState(() => _company = change(_company!));

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final saved = await _repo.update(_company!);
      if (!mounted) return;
      context.read<CurrentCompanyCubit>().replace(saved);
      setState(() {
        _original = saved;
        _company = saved;
        _saving = false;
      });
      Toasts.success(context, 'Dados da empresa salvos');
    } on ApiError catch (e) {
      setState(() => _saving = false);
      if (mounted) Toasts.error(context, e);
    }
  }

  Future<void> _uploadLogo() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Imagens',
          extensions: ['png', 'jpg', 'jpeg', 'webp', 'svg'],
        ),
      ],
    );
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final url = await _repo.uploadLogo(file.path);
      if (!mounted) return;
      final updated = _original!.copyWith(logoUrl: () => url);
      context.read<CurrentCompanyCubit>().replace(updated);
      setState(() {
        _original = updated;
        _company = _company!.copyWith(logoUrl: () => url);
        _uploading = false;
      });
      Toasts.success(context, 'Logo atualizado');
    } on ApiError catch (e) {
      setState(() => _uploading = false);
      if (mounted) Toasts.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _company;
    if (c == null) {
      return _error != null
          ? ErrorView(message: _error!, onRetry: () => unawaited(_load()))
          : const LoadingView();
    }
    final canEdit = context.select<SessionCubit, bool>(
      (s) => s.state.user?.canSeeCompanySettings ?? false,
    );
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;

    Widget text(
      String label,
      String? value,
      Company Function(Company, String?) apply, {
      String? hint,
      int lines = 1,
      PatternMask? mask,
    }) => _Field(
      key: ValueKey('$label-$_formVersion'),
      label: label,
      hint: hint,
      mask: mask,
      value: (mask == null ? value : Masks.format(mask, value)) ?? '',
      lines: lines,
      enabled: canEdit,
      onChanged: (v) => _set((c) => apply(c, v.trim().isEmpty ? null : v)),
    );

    return Column(
      children: [
        Expanded(
          child: PageLayout(
            title: 'Empresa',
            subtitle: 'Dados que aparecem nos seus orçamentos e PDFs.',
            maxWidth: 1000,
            scrollable: true,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionCard(
                  title: 'Identidade',
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: ext.appBackground,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: ext.border),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: c.logoUrl == null
                                ? Icon(
                                    Icons.storefront_outlined,
                                    size: 36,
                                    color: ext.textHint,
                                  )
                                : Image.network(
                                    c.logoUrl!,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) => Icon(
                                      Icons.broken_image_outlined,
                                      color: ext.textHint,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 10),
                          if (canEdit)
                            FormaButton.secondary(
                              label: 'Trocar logo',
                              small: true,
                              isLoading: _uploading,
                              onPressed: () => unawaited(_uploadLogo()),
                            ),
                        ],
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: text(
                                    'Razão social',
                                    c.name,
                                    (c, v) => c.copyWith(name: v ?? ''),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: text(
                                    'Nome fantasia',
                                    c.tradeName,
                                    (c, v) => c.copyWith(tradeName: () => v),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            text(
                              'CNPJ',
                              c.document,
                              (c, v) => c.copyWith(document: () => v),
                              mask: Masks.cnpj,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Contato',
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: text(
                              'E-mail',
                              c.email,
                              (c, v) => c.copyWith(email: () => v),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: text(
                              'Telefone',
                              c.phone,
                              (c, v) => c.copyWith(phone: () => v),
                              mask: Masks.phone,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: text(
                              'WhatsApp',
                              c.whatsapp,
                              (c, v) => c.copyWith(whatsapp: () => v),
                              mask: Masks.phone,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: text(
                              'Instagram',
                              c.instagram,
                              (c, v) => c.copyWith(instagram: () => v),
                              hint: '@suaempresa',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: text(
                              'Site',
                              c.website,
                              (c, v) => c.copyWith(website: () => v),
                              hint: 'https://',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Endereço',
                  child: Column(
                    children: [
                      text(
                        'Endereço',
                        c.address,
                        (c, v) => c.copyWith(address: () => v),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: text(
                              'Cidade',
                              c.city,
                              (c, v) => c.copyWith(city: () => v),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 90,
                            child: text(
                              'UF',
                              c.state,
                              (c, v) => c.copyWith(state: () => v),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 160,
                            child: text(
                              'CEP',
                              c.zipCode,
                              (c, v) => c.copyWith(zipCode: () => v),
                              mask: Masks.cep,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Padrões de orçamento',
                  subtitle: 'Aplicados automaticamente em novos orçamentos.',
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 220,
                            child: FormaNumberField(
                              key: ValueKey('validity-$_formVersion'),
                              label: 'Validade padrão',
                              value: c.defaultQuoteValidityDays,
                              min: 1,
                              max: 365,
                              suffixText: 'dias',
                              enabled: canEdit,
                              helperText: 'Usada ao enviar sem data',
                              onChanged: (v) => _set(
                                (c) => c.copyWith(
                                  defaultQuoteValidityDays: () => v?.toInt(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 220,
                            child: FormaNumberField(
                              key: ValueKey('tax-$_formVersion'),
                              label: 'Alíquota padrão',
                              value: c.defaultTaxRate,
                              decimals: 2,
                              min: 0,
                              max: 99.99,
                              suffixText: '%',
                              enabled: canEdit,
                              helperText: 'Imposto embutido no preço',
                              onChanged: (v) => _set(
                                (c) => c.copyWith(
                                  defaultTaxRate: () => v?.toDouble(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      text(
                        'Condições de pagamento padrão',
                        c.defaultPaymentTerms,
                        (c, v) => c.copyWith(defaultPaymentTerms: () => v),
                        lines: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
        AnimatedSlide(
          offset: _dirty ? Offset.zero : const Offset(0, 1),
          duration: const Duration(milliseconds: 180),
          child: AnimatedOpacity(
            opacity: _dirty ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              decoration: BoxDecoration(
                color: ext.cardBackground,
                border: Border(top: BorderSide(color: ext.border)),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit_note_rounded, color: ext.textMuted, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Você tem alterações não salvas',
                    style: typo.body14Medium.copyWith(color: ext.textPrimary),
                  ),
                  const Spacer(),
                  FormaButton.secondary(
                    label: 'Descartar',
                    small: true,
                    onPressed: () => setState(() {
                      _company = _original;
                      _formVersion++;
                    }),
                  ),
                  const SizedBox(width: 8),
                  FormaButton.primary(
                    label: 'Salvar alterações',
                    small: true,
                    isLoading: _saving,
                    onPressed: () => unawaited(_save()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Field extends StatefulWidget {
  const _Field({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.enabled,
    this.hint,
    this.lines = 1,
    this.mask,
    super.key,
  });

  final PatternMask? mask;
  final String label;
  final String value;
  final String? hint;
  final int lines;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  late final _c = TextEditingController(text: widget.value);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FormaTextField(
    label: widget.label,
    hint: widget.hint,
    controller: _c,
    enabled: widget.enabled,
    maxLines: widget.lines,
    inputFormatters: widget.mask == null ? null : [widget.mask!],
    onChanged: widget.onChanged,
  );
}
