import 'package:flutter/material.dart';
import 'package:forma_ui/forma_ui.dart';

/// [FormaTextField] com controller próprio, inicializado uma vez a partir de
/// [value] e reportando cada edição. Útil em formulários guiados por estado
/// imutável (o valor externo só é reaplicado quando a [key] muda).
class DraftTextField extends StatefulWidget {
  const DraftTextField({
    required this.value,
    required this.onChanged,
    this.label,
    this.hint,
    this.errorText,
    this.maxLines = 1,
    this.minLines,
    this.autofocus = false,
    super.key,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String? label;
  final String? hint;
  final String? errorText;
  final int maxLines;
  final int? minLines;
  final bool autofocus;

  @override
  State<DraftTextField> createState() => _DraftTextFieldState();
}

class _DraftTextFieldState extends State<DraftTextField> {
  late final _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(DraftTextField old) {
    super.didUpdateWidget(old);
    // Mudança externa (ex.: importação do fatiador) sem foco no campo.
    if (widget.value != _controller.text && widget.value != old.value) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        FormaTextField(
          label: widget.label,
          hint: widget.hint,
          controller: _controller,
          onChanged: widget.onChanged,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          autofocus: widget.autofocus,
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.errorText!,
            style: typo.caption12.copyWith(color: ext.errorColor),
          ),
        ],
      ],
    );
  }
}
