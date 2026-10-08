import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forma_ui/forma_ui.dart';

/// Campo de busca com debounce.
class SearchField extends StatefulWidget {
  const SearchField({
    required this.onChanged,
    this.hint = 'Buscar…',
    this.initialValue,
    this.width = 320,
    this.debounce = const Duration(milliseconds: 300),
    super.key,
  });

  final ValueChanged<String> onChanged;
  final String hint;
  final String? initialValue;
  final double width;
  final Duration debounce;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final _controller = TextEditingController(text: widget.initialValue);
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _timer?.cancel();
    _timer = Timer(widget.debounce, () => widget.onChanged(value.trim()));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    return SizedBox(
      width: widget.width,
      child: FormaTextField(
        controller: _controller,
        hint: widget.hint,
        onChanged: _changed,
        prefix: Icon(Icons.search, size: 18, color: ext.textHint),
        suffix: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpar',
                iconSize: 16,
                icon: Icon(Icons.close, color: ext.textHint),
                onPressed: () {
                  _controller.clear();
                  _changed('');
                },
              ),
      ),
    );
  }
}
