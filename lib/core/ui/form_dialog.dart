import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';

String? requiredValidator(String? v) =>
    (v == null || v.trim().isEmpty) ? 'Obrigatório' : null;

/// Abre um [FormaDialog] com formulário padrão (validação, salvar com
/// loading, erro da API inline). Retorna o resultado de [onSubmit].
Future<T?> showFormDialog<T>(
  BuildContext context, {
  required String title,
  required List<Widget> Function(StateSetter setState) fields,
  required Future<T> Function() onSubmit,
  String? description,
  String submitLabel = 'Salvar',
  double width = 520,
}) => FormaDialog.show<T>(
  context,
  title: title,
  description: description,
  width: width,
  child: _FormBody<T>(
    fields: fields,
    onSubmit: onSubmit,
    submitLabel: submitLabel,
  ),
);

class _FormBody<T> extends StatefulWidget {
  const _FormBody({
    required this.fields,
    required this.onSubmit,
    required this.submitLabel,
  });

  final List<Widget> Function(StateSetter setState) fields;
  final Future<T> Function() onSubmit;
  final String submitLabel;

  @override
  State<_FormBody<T>> createState() => _FormBodyState<T>();
}

class _FormBodyState<T> extends State<_FormBody<T>> {
  final _form = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.onSubmit();
      if (mounted) Navigator.of(context).pop(result);
    } on ValidationError catch (e) {
      setState(() {
        _saving = false;
        _error = [e.message, ...e.fields.values].join('\n');
      });
    } on ApiError catch (e) {
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final children = widget.fields(setState);
    return Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, f) in children.indexed) ...[
            if (i > 0) const SizedBox(height: 14),
            f,
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: typo.caption12.copyWith(color: ext.errorColor),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FormaButton.secondary(
                label: 'Cancelar',
                small: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),
              FormaButton.primary(
                label: widget.submitLabel,
                small: true,
                isLoading: _saving,
                onPressed: () => unawaited(_submit()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
