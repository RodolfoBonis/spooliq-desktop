import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/observability/app_logger.dart';
import 'package:spooliq_desktop/features/subscription/domain/billing.dart';

/// Motivos de cancelamento (mesmos valores da web).
enum CancelReason {
  tooExpensive('too_expensive', 'Muito caro'),
  notUsing('not_using', 'Não estou usando o suficiente'),
  missingFeatures('missing_features', 'Faltam recursos importantes'),
  technicalIssues('technical_issues', 'Problemas técnicos'),
  switchingCompetitors('switching_competitors', 'Mudando para um concorrente'),
  businessClosure('business_closure', 'Fechando o negócio'),
  other('other', 'Outro motivo');

  const CancelReason(this.value, this.label);

  final String value;
  final String label;
}

/// Cancelamento em dois passos: impacto e depois motivo/feedback.
/// Retorna true quando a assinatura foi cancelada.
Future<bool> showCancelSubscriptionDialog(
  BuildContext context, {
  required BillingRepository repository,
}) async {
  final cancelled = await FormaDialog.show<bool>(
    context,
    title: 'Cancelar assinatura',
    width: 520,
    // Fechar com o request em voo esconderia um cancelamento já feito.
    barrierDismissible: false,
    child: _CancelBody(repository: repository),
  );
  return cancelled ?? false;
}

class _CancelBody extends StatefulWidget {
  const _CancelBody({required this.repository});

  final BillingRepository repository;

  @override
  State<_CancelBody> createState() => _CancelBodyState();
}

class _CancelBodyState extends State<_CancelBody> {
  bool _reasonStep = false;
  CancelReason? _reason;
  final _feedback = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _feedback.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final reason = _reason;
    if (reason == null) {
      setState(() => _error = 'Selecione um motivo.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.cancel(
        reason: reason.value,
        feedback: _feedback.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } on Object catch (e, st) {
      unawaited(
        AppLogger.error(e, st, reason: 'cancel_subscription'),
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Não foi possível cancelar. Tente novamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;

    final content = _reasonStep
        ? <Widget>[
            Text(
              'Conte o motivo: isso nos ajuda a melhorar o SpoolIQ.',
              style: typo.body14.copyWith(color: ext.textMuted),
            ),
            const SizedBox(height: 14),
            FormaSelect<CancelReason>(
              label: 'Motivo',
              hint: 'Selecione',
              value: _reason,
              options: [
                for (final r in CancelReason.values)
                  FormaSelectOption(value: r, label: r.label),
              ],
              onChanged: (v) => setState(() {
                _reason = v;
                _error = null;
              }),
            ),
            const SizedBox(height: 14),
            FormaTextField(
              label: 'Comentário (opcional)',
              controller: _feedback,
              maxLines: 3,
            ),
          ]
        : <Widget>[
            Text(
              'O cancelamento é imediato: o acesso ao SpoolIQ é bloqueado na '
              'hora, mesmo que ainda reste período pago.',
              style: typo.body14.copyWith(color: ext.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Para reativar depois, é preciso falar com o suporte.',
              style: typo.body14.copyWith(color: ext.textMuted),
            ),
          ];

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...content,
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: typo.caption12.copyWith(color: ext.errorColor)),
        ],
        const SizedBox(height: 24),
        OverflowBar(
          alignment: MainAxisAlignment.end,
          spacing: 8,
          overflowSpacing: 8,
          overflowAlignment: OverflowBarAlignment.end,
          children: [
            FormaButton.secondary(
              label: 'Manter assinatura',
              small: true,
              onPressed: _saving
                  ? null
                  : () => Navigator.of(context).pop(false),
            ),
            if (_reasonStep)
              FormaButton.danger(
                label: 'Confirmar cancelamento',
                small: true,
                isLoading: _saving,
                onPressed: () => unawaited(_confirm()),
              )
            else
              FormaButton.danger(
                label: 'Continuar',
                small: true,
                onPressed: () => setState(() => _reasonStep = true),
              ),
          ],
        ),
      ],
    );
    // Esc não fecha enquanto o cancelamento está em andamento.
    return PopScope(canPop: !_saving, child: body);
  }
}
