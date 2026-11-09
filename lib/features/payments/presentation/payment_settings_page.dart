import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/ui/feedback.dart';
import 'package:spooliq_desktop/core/ui/page_layout.dart';
import 'package:spooliq_desktop/features/payments/domain/payment_repository.dart';
import 'package:spooliq_desktop/features/payments/presentation/payment_settings_cubit.dart';

class PaymentSettingsPage extends StatelessWidget {
  const PaymentSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = PaymentSettingsCubit(di<PaymentRepository>());
        unawaited(cubit.load());
        return cubit;
      },
      child: const _PaymentSettingsView(),
    );
  }
}

class _PaymentSettingsView extends StatelessWidget {
  const _PaymentSettingsView();

  Future<void> _save(BuildContext context) async {
    final cubit = context.read<PaymentSettingsCubit>();
    final ok = await cubit.save();
    if (!context.mounted) return;
    if (ok) {
      Toasts.success(context, 'Configurações de pagamento salvas');
    } else if (cubit.state.saveError != null) {
      _showError(context, cubit.state.saveError);
    } else {
      Toasts.info(context, 'Revise os campos destacados');
    }
  }

  Future<void> _disconnect(BuildContext context) async {
    final cubit = context.read<PaymentSettingsCubit>();
    final pending = cubit.state.pendingLinks;
    const base =
        'Os links pendentes serão cancelados no SpoolIQ; se algum for pago '
        'antes de expirar, o pagamento será registrado para você reembolsar '
        'pela InfinitePay.';
    final prefix = pending > 0
        ? 'Há $pending ${pending == 1 ? 'link pendente' : 'links pendentes'}. '
        : '';
    final ok = await FormaConfirmDialog.show(
      context,
      title: 'Desconectar a InfinitePay?',
      message: '$prefix$base',
      confirmLabel: 'Desconectar',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final done = await cubit.disconnect();
    if (!context.mounted) return;
    if (done) {
      Toasts.success(context, 'InfinitePay desconectada');
    } else {
      _showError(context, cubit.state.saveError);
    }
  }

  void _showError(BuildContext context, String? message) {
    if (message == null) return;
    FormaToast.show(
      context,
      message: message,
      variant: FormaToastVariant.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PaymentSettingsCubit, PaymentSettingsState>(
      builder: (context, state) {
        final cubit = context.read<PaymentSettingsCubit>();
        if (state.status == PaymentSettingsStatus.loading) {
          return const LoadingView();
        }
        if (state.status == PaymentSettingsStatus.failure) {
          return ErrorView(
            message: state.loadError ?? 'Não foi possível carregar.',
            onRetry: () => unawaited(cubit.load()),
          );
        }
        final ext = Theme.of(context).extension<FormaThemeExtension>()!;
        final typo = context.formaTypography;
        final saving = state.saving;
        final errors = state.errors;

        return Column(
          children: [
            Expanded(
              child: PageLayout(
                title: 'Pagamentos · InfinitePay',
                subtitle:
                    'Receba pelo link do orçamento: o cliente paga no Pix ou '
                    'parcela no cartão.',
                maxWidth: 820,
                scrollable: true,
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state.saveError != null) ...[
                      FormaAlertBanner(
                        message: state.saveError!,
                        variant: FormaAlertVariant.error,
                      ),
                      const SizedBox(height: 16),
                    ],
                    _ConnectionCard(
                      // Reseta os controladores quando o servidor muda.
                      key: ObjectKey(state.original),
                      state: state,
                    ),
                    const SizedBox(height: 16),
                    SectionCard(
                      title: 'Preferências de cobrança',
                      subtitle: 'Aplicadas aos links gerados dos orçamentos.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 220,
                                child: FormaNumberField(
                                  key: const ValueKey('installments'),
                                  label: 'Parcelas sem juros',
                                  value: state.assuredInstallments,
                                  suffixText: 'x',
                                  enabled: !saving,
                                  errorText: errors['installments'],
                                  helperText: errors['installments'] == null
                                      ? 'De 1 a 12 (a empresa assume os juros)'
                                      : null,
                                  onChanged: (v) =>
                                      cubit.setInstallments((v ?? 0).round()),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 220,
                                child: FormaNumberField(
                                  key: const ValueKey('pix-discount'),
                                  label: 'Desconto no Pix',
                                  value: state.pixDiscountPercent,
                                  suffixText: '%',
                                  enabled: !saving,
                                  errorText: errors['pix_discount'],
                                  helperText: errors['pix_discount'] == null
                                      ? 'Inteiro, de 0 a 30%'
                                      : null,
                                  onChanged: (v) =>
                                      cubit.setPixDiscount((v ?? 0).round()),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 220,
                                child: FormaNumberField(
                                  key: const ValueKey('deposit'),
                                  label: 'Sinal padrão',
                                  value: state.defaultDepositPercent,
                                  decimals: 2,
                                  suffixText: '%',
                                  enabled: !saving,
                                  errorText: errors['deposit'],
                                  helperText: errors['deposit'] == null
                                      ? 'Vazio = pagamento integral'
                                      : null,
                                  onChanged: (v) =>
                                      cubit.setDefaultDeposit(v?.toDouble()),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (state.connected) ...[
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: ext.errorColor,
                          ),
                          onPressed: saving
                              ? null
                              : () => unawaited(_disconnect(context)),
                          icon: const Icon(Icons.link_off_rounded, size: 18),
                          label: const Text('Desconectar InfinitePay'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
            AnimatedSlide(
              offset: state.dirty ? Offset.zero : const Offset(0, 1),
              duration: const Duration(milliseconds: 180),
              child: AnimatedOpacity(
                opacity: state.dirty ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: ext.cardBackground,
                    border: Border(top: BorderSide(color: ext.border)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_note_rounded,
                        color: ext.textMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Você tem alterações não salvas',
                        style: typo.body14Medium.copyWith(
                          color: ext.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      FormaButton.primary(
                        label: 'Salvar alterações',
                        small: true,
                        isLoading: saving,
                        onPressed: saving
                            ? null
                            : () => unawaited(_save(context)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ConnectionCard extends StatefulWidget {
  const _ConnectionCard({required this.state, super.key});

  final PaymentSettingsState state;

  @override
  State<_ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends State<_ConnectionCard> {
  late final TextEditingController _handle = TextEditingController(
    text: widget.state.handle,
  );
  late final TextEditingController _apiKey = TextEditingController();

  @override
  void dispose() {
    _handle.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PaymentSettingsCubit>();
    final state = widget.state;
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final saving = state.saving;
    final errors = state.errors;

    return SectionCard(
      title: 'Conexão',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ext.infoSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: ext.infoText),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No app da InfinitePay, vá em Vendas → Checkout → '
                    'Configurações → Habilitar Checkout Integrado e gere uma '
                    'chave de API. Cole a chave aqui com o seu @handle.',
                    style: typo.body13.copyWith(color: ext.infoText),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FormaTextField(
            label: 'Handle (@)',
            hint: 'suaempresa',
            controller: _handle,
            enabled: !saving,
            prefix: Text('@', style: typo.body14.copyWith(color: ext.textHint)),
            onChanged: cubit.setHandle,
          ),
          _FieldError(message: errors['handle']),
          const SizedBox(height: 12),
          if (state.connected && !state.editingKey)
            _ConnectedKey(
              masked: state.maskedApiKey,
              onChange: saving ? null : cubit.startEditingKey,
            )
          else ...[
            FormaTextField(
              label: 'Chave de API',
              hint: 'Cole a chave gerada na InfinitePay',
              controller: _apiKey,
              enabled: !saving,
              obscureText: true,
              onChanged: cubit.setApiKey,
            ),
            _FieldError(message: errors['api_key']),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              FormaSwitch(
                value: state.enabled,
                onChanged: saving ? null : (v) => cubit.setEnabled(enabled: v),
                semanticLabel: 'Ativar pagamentos pelo link',
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pagamento pelo link ativo',
                      style: typo.body14Medium.copyWith(color: ext.textPrimary),
                    ),
                    Text(
                      'Quando desligado, os orçamentos não oferecem pagamento.',
                      style: typo.caption12.copyWith(color: ext.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Linha de erro por campo (para os campos de texto, que não têm `errorText`).
class _FieldError extends StatelessWidget {
  const _FieldError({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 2),
      child: Text(
        message!,
        style: typo.caption12.copyWith(color: ext.errorColor),
      ),
    );
  }
}

class _ConnectedKey extends StatelessWidget {
  const _ConnectedKey({required this.masked, required this.onChange});

  final String masked;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chave de API',
          style: typo.caption12.copyWith(color: ext.textHint),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          decoration: BoxDecoration(
            color: ext.appBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ext.border),
          ),
          child: Row(
            children: [
              Icon(Icons.key_rounded, size: 16, color: ext.successText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  masked.isEmpty ? 'Conectada' : masked,
                  style: typo.body14.copyWith(color: ext.textPrimary),
                ),
              ),
              FormaButton.secondary(
                label: 'Trocar chave',
                small: true,
                onPressed: onChange,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
