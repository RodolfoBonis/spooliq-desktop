import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:spooliq_desktop/core/auth/permissions.dart';
import 'package:spooliq_desktop/core/auth/session_user.dart';
import 'package:spooliq_desktop/core/config/app_config.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/format/formatters.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/observability/app_logger.dart';
import 'package:spooliq_desktop/core/routing/routes.dart';
import 'package:spooliq_desktop/core/ui/feedback.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_repository.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget_status.dart';
import 'package:spooliq_desktop/features/budgets/presentation/widgets/budget_status_style.dart';
import 'package:url_launcher/url_launcher.dart';

/// Decisão do usuário antes de mudar o status.
class TransitionDecision {
  const TransitionDecision({this.notes});

  final String? notes;
}

/// Pede confirmação/motivo conforme a transição. `null` = cancelado.
Future<TransitionDecision?> confirmTransition(
  BuildContext context,
  Budget budget,
  BudgetStatus to,
) async {
  switch (to) {
    case BudgetStatus.completed:
      final ok = await FormaConfirmDialog.show(
        context,
        title: 'Concluir "${budget.name}"?',
        message:
            'Os filamentos usados serão baixados do estoque e o orçamento '
            'não poderá mais ser alterado.',
        confirmLabel: 'Concluir',
      );
      return ok ? const TransitionDecision() : null;
    case BudgetStatus.rejected || BudgetStatus.cancelled:
      return FormaDialog.show<TransitionDecision>(
        context,
        title: to == BudgetStatus.rejected
            ? 'Marcar como rejeitado'
            : 'Cancelar orçamento',
        description: budget.name,
        child: const _ReasonForm(),
      );
    case BudgetStatus.sent when budget.validUntil == null:
      final ok = await FormaConfirmDialog.show(
        context,
        title: 'Marcar como enviado?',
        message:
            'A validade será definida automaticamente pelo padrão da empresa. '
            'Para enviar o link de aprovação ao cliente, use "Compartilhar".',
        confirmLabel: 'Marcar como enviado',
      );
      return ok ? const TransitionDecision() : null;
    case _:
      return const TransitionDecision();
  }
}

class _ReasonForm extends StatefulWidget {
  const _ReasonForm();

  @override
  State<_ReasonForm> createState() => _ReasonFormState();
}

class _ReasonFormState extends State<_ReasonForm> {
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormaTextField(
          label: 'Motivo (opcional)',
          hint: 'Ex.: cliente achou o prazo longo',
          controller: _notes,
          autofocus: true,
          maxLines: 3,
          minLines: 2,
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FormaButton.secondary(
              label: 'Voltar',
              small: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 8),
            FormaButton.danger(
              label: 'Confirmar',
              small: true,
              onPressed: () => Navigator.of(
                context,
              ).pop(TransitionDecision(notes: _notes.text)),
            ),
          ],
        ),
      ],
    );
  }
}

/// Ações sobre um orçamento, compartilhadas por quadro, tabela e detalhe.
class BudgetActions {
  BudgetActions({
    required this.context,
    required this.user,
    required this.onChanged,
    required this.onDeleted,
    this.onMove,
  });

  final BuildContext context;
  final SessionUser user;

  /// Orçamento alterado/criado (ex.: duplicado, compartilhado).
  final void Function(Budget budget) onChanged;
  final void Function(String id) onDeleted;

  /// Mudança de status. Se nulo, chama a API diretamente.
  final Future<bool> Function(Budget budget, BudgetStatus to, String? notes)?
  onMove;

  BudgetRepository get _repo => di<BudgetRepository>();

  List<FormaMenuItem> menuFor(Budget b, {bool includeOpen = true}) {
    final transitions = b.status.allowedTransitions.toList()
      ..sort((a, z) => a.index.compareTo(z.index));
    return [
      if (includeOpen)
        FormaMenuItem(
          label: 'Abrir',
          icon: Icons.open_in_new_rounded,
          onTap: () => context.go(Routes.budget(b.id)),
        ),
      if (b.status.isEditable)
        FormaMenuItem(
          label: 'Editar',
          icon: Icons.edit_outlined,
          onTap: () => context.go(Routes.budgetEdit(b.id)),
        ),
      if (transitions.isNotEmpty) const FormaMenuItem.divider(),
      for (final to in transitions)
        FormaMenuItem(
          label: to.actionLabel,
          icon: BudgetStatusStyle.of(to, Theme.of(context).brightness).icon,
          destructive: to == BudgetStatus.cancelled,
          onTap: () => unawaited(move(b, to)),
        ),
      const FormaMenuItem.divider(),
      FormaMenuItem(
        label: 'Ver PDF',
        icon: Icons.picture_as_pdf_outlined,
        onTap: () => unawaited(openPdf(b)),
      ),
      FormaMenuItem(
        label: 'Regenerar PDF',
        icon: Icons.refresh_rounded,
        onTap: () => unawaited(openPdf(b, force: true)),
      ),
      if (b.status.isShareable)
        FormaMenuItem(
          label: b.isShared
              ? 'Link de aprovação'
              : 'Compartilhar com o cliente',
          icon: Icons.ios_share_rounded,
          onTap: () => unawaited(share(b)),
        ),
      if (b.status.isEditable)
        FormaMenuItem(
          label: 'Recalcular custos',
          icon: Icons.calculate_outlined,
          onTap: () => unawaited(recalculate(b)),
        ),
      FormaMenuItem(
        label: 'Duplicar',
        icon: Icons.copy_all_outlined,
        onTap: () => unawaited(duplicate(b)),
      ),
      if (user.canDeleteBudgets && b.status.isDeletable) ...[
        const FormaMenuItem.divider(),
        FormaMenuItem(
          label: 'Excluir',
          icon: Icons.delete_outline,
          destructive: true,
          onTap: () => unawaited(delete(b)),
        ),
      ],
    ];
  }

  Future<void> move(Budget b, BudgetStatus to) async {
    final decision = await confirmTransition(context, b, to);
    if (decision == null || !context.mounted) return;
    if (onMove != null) {
      final ok = await onMove!(b, to, decision.notes);
      if (ok && context.mounted) {
        Toasts.success(context, '"${b.name}" → ${to.label}');
      }
      return;
    }
    try {
      final updated = await _repo.changeStatus(b.id, to, notes: decision.notes);
      onChanged(updated);
      if (context.mounted) {
        Toasts.success(context, '"${b.name}" → ${to.label}');
      }
    } on ApiError catch (e) {
      if (context.mounted) Toasts.error(context, e);
    }
  }

  Future<void> duplicate(Budget b) async {
    try {
      final copy = await _repo.duplicate(b.id);
      onChanged(copy);
      if (!context.mounted) return;
      FormaToast.show(
        context,
        message: 'Orçamento duplicado',
        description: copy.name,
        variant: FormaToastVariant.success,
        actionLabel: 'Abrir',
        onAction: () => context.go(Routes.budget(copy.id)),
      );
    } on ApiError catch (e) {
      if (context.mounted) Toasts.error(context, e);
    }
  }

  /// Recalcula com os preços e presets atuais (só rascunhos).
  Future<void> recalculate(Budget b) async {
    try {
      final updated = await _repo.recalculate(b.id);
      onChanged(updated);
      if (!context.mounted) return;
      final before = Fmt.cents(b.totalCents);
      final after = Fmt.cents(updated.totalCents);
      Toasts.success(
        context,
        before == after ? 'Custos recalculados' : 'Total: $before → $after',
      );
    } on ApiError catch (e) {
      if (context.mounted) Toasts.error(context, e);
    } on Object catch (e, st) {
      _unexpected(e, st, 'recalculate');
    }
  }

  /// Para orçamentos que já saíram de rascunho: cria uma cópia (rascunho)
  /// recalculada e abre ela.
  Future<void> duplicateAndRecalculate(Budget b) async {
    final Budget copy;
    try {
      copy = await _repo.duplicate(b.id);
      onChanged(copy);
    } on ApiError catch (e) {
      if (context.mounted) Toasts.error(context, e);
      return;
    } on Object catch (e, st) {
      _unexpected(e, st, 'duplicate_recalculate');
      return;
    }
    try {
      final updated = await _repo.recalculate(copy.id);
      onChanged(updated);
      if (!context.mounted) return;
      Toasts.success(context, 'Cópia recalculada criada');
      context.go(Routes.budget(updated.id));
    } on Object catch (e, st) {
      // A cópia existe: avisa e deixa abrir para recalcular de lá.
      if (e is! ApiError) _unexpected(e, st, 'duplicate_recalculate');
      if (!context.mounted) return;
      FormaToast.show(
        context,
        message: 'Cópia criada, mas o recálculo falhou',
        description: e is ApiError ? e.message : null,
        variant: FormaToastVariant.warning,
        actionLabel: 'Abrir',
        onAction: () => context.go(Routes.budget(copy.id)),
      );
    }
  }

  void _unexpected(Object e, StackTrace st, String reason) {
    unawaited(AppLogger.error(e, st, reason: reason, category: 'budgets'));
    if (context.mounted) Toasts.error(context, e);
  }

  Future<void> delete(Budget b) async {
    final ok = await confirmDelete(
      context,
      what: 'o orçamento "${b.name}"',
      detail: 'O orçamento e seus itens serão removidos permanentemente.',
    );
    if (!ok || !context.mounted) return;
    try {
      await _repo.delete(b.id);
      onDeleted(b.id);
      if (context.mounted) Toasts.success(context, 'Orçamento excluído');
    } on ApiError catch (e) {
      if (context.mounted) Toasts.error(context, e);
    }
  }

  /// Gera (ou reaproveita) o PDF e abre no visualizador do sistema.
  Future<void> openPdf(Budget b, {bool force = false}) async {
    Toasts.info(context, 'Gerando PDF…');
    try {
      final pdf = await _repo.pdf(b.id, force: force);
      switch (pdf) {
        case BudgetPdfUrl(:final url):
          await launchUrl(Uri.parse(url));
        case BudgetPdfBytes(:final bytes):
          final dir = await getTemporaryDirectory();
          final name = 'orcamento-${b.quoteNumber ?? b.id}.pdf';
          final file = File(p.join(dir.path, name));
          await file.writeAsBytes(bytes, flush: true);
          await launchUrl(Uri.file(file.path));
      }
    } on ApiError catch (e) {
      if (context.mounted) Toasts.error(context, e);
    } on Object catch (e, st) {
      unawaited(
        AppLogger.error(e, st, reason: 'open_pdf', category: 'budgets'),
      );
      if (context.mounted) Toasts.error(context, e);
    }
  }

  /// Gera o link público e mostra opções de envio.
  Future<void> share(Budget b) async {
    try {
      final result = await _repo.share(b.id);
      final updated = await _repo.get(b.id);
      onChanged(updated);
      if (!context.mounted) return;
      await FormaDialog.show<void>(
        context,
        title: 'Link de aprovação',
        width: 600,
        description:
            'O cliente pode ver, baixar o PDF e aprovar ou recusar pelo link.',
        child: _ShareSheet(
          budget: updated,
          url: '${di<AppConfig>().publicBudgetBaseUrl}/${result.token}',
          validUntil: result.validUntil,
          onRevoke: () async {
            try {
              await _repo.revokeShare(b.id);
              onChanged(await _repo.get(b.id));
              return true;
            } on ApiError catch (e) {
              if (context.mounted) Toasts.error(context, e);
              return false;
            }
          },
        ),
      );
    } on ApiError catch (e) {
      if (context.mounted) Toasts.error(context, e);
    }
  }
}

class _ShareSheet extends StatelessWidget {
  const _ShareSheet({
    required this.budget,
    required this.url,
    required this.validUntil,
    required this.onRevoke,
  });

  final Budget budget;
  final String url;
  final DateTime? validUntil;
  final Future<bool> Function() onRevoke;

  String get _greeting => budget.customerName.isEmpty
      ? 'Olá!'
      : 'Olá, ${budget.customerName.split(' ').first}!';

  String get _message =>
      '$_greeting '
      'Segue o orçamento "${budget.name}" '
      '(${Fmt.cents(budget.totalCents)}). '
      'Você pode conferir e aprovar por aqui: $url';

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final phone = budget.customer?.phone?.replaceAll(RegExp(r'\D'), '');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          decoration: BoxDecoration(
            color: ext.appBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ext.border),
          ),
          child: Row(
            children: [
              Icon(Icons.link_rounded, size: 18, color: ext.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  url,
                  maxLines: 1,
                  style: typo.body14.copyWith(color: ext.textPrimary),
                ),
              ),
              FormaButton.secondary(
                label: 'Copiar',
                small: true,
                icon: const Icon(Icons.copy_rounded, size: 16),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: url));
                  if (context.mounted) Toasts.success(context, 'Link copiado');
                },
              ),
            ],
          ),
        ),
        if (validUntil != null) ...[
          const SizedBox(height: 8),
          Text(
            'Válido até ${Fmt.date(validUntil)}',
            style: typo.caption12.copyWith(color: ext.textMuted),
          ),
        ],
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: ext.errorColor),
              onPressed: () async {
                if (await onRevoke() && context.mounted) {
                  Navigator.of(context).pop();
                  Toasts.success(context, 'Link revogado');
                }
              },
              icon: const Icon(Icons.link_off_rounded, size: 18),
              label: const Text('Revogar link'),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FormaButton.secondary(
                  label: 'Copiar mensagem',
                  small: true,
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _message));
                    if (context.mounted) {
                      Toasts.success(context, 'Mensagem copiada');
                    }
                  },
                ),
                FormaButton.primary(
                  label: 'Enviar no WhatsApp',
                  small: true,
                  icon: const Icon(
                    Icons.chat_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  onPressed: () => unawaited(
                    launchUrl(
                      Uri.https(
                        'wa.me',
                        phone == null || phone.isEmpty
                            ? '/'
                            : '/${phone.length <= 11 ? '55$phone' : phone}',
                        {'text': _message},
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
