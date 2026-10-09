import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/format/formatters.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/ui/feedback.dart';
import 'package:spooliq_desktop/core/ui/form_dialog.dart';
import 'package:spooliq_desktop/core/ui/page_layout.dart';
import 'package:spooliq_desktop/features/auth/presentation/session_cubit.dart';
import 'package:spooliq_desktop/features/company/domain/company.dart';
import 'package:spooliq_desktop/features/company/presentation/current_company_cubit.dart';
import 'package:spooliq_desktop/features/subscription/domain/billing.dart';
import 'package:spooliq_desktop/features/subscription/presentation/cancel_subscription_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final BillingRepository _repo = di<BillingRepository>();
  List<Plan>? _plans;
  SubscriptionInfo? _status;
  List<PaymentMethod> _methods = const [];
  List<Payment> _payments = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final plans = await _repo.plans();
      final status = await _repo.status();
      List<PaymentMethod> methods;
      List<Payment> payments;
      try {
        methods = await _repo.paymentMethods();
      } on ApiError {
        methods = const [];
      }
      try {
        payments = await _repo.payments();
      } on ApiError {
        payments = const [];
      }
      if (!mounted) return;
      setState(() {
        _plans = plans.where((p) => p.isActive).toList();
        _status = status;
        _methods = methods;
        _payments = payments;
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = _plans;
    if (plans == null) {
      return _error != null
          ? ErrorView(message: _error!, onRetry: () => unawaited(_load()))
          : const LoadingView();
    }
    final company = context.select<CurrentCompanyCubit, Company?>(
      (c) => c.state.company,
    );
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final status = _status;
    final current = company?.currentPlan ?? status?.planName;

    return PageLayout(
      title: 'Assinatura',
      subtitle: 'Seu plano, formas de pagamento e cobranças.',
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ext.primarySurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.workspace_premium_outlined,
                    color: ext.primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        current == null ? 'Sem plano ativo' : 'Plano $current',
                        style: typo.title16.copyWith(color: ext.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          company?.subscriptionStatus.label ??
                              status?.status ??
                              '',
                          if (company?.trialDaysLeft != null)
                            '${company!.trialDaysLeft} dias restantes de teste',
                          if (status?.nextDueDate != null) _nextCharge(status!),
                          if (status?.value != null) Fmt.money(status!.value),
                        ].where((s) => s.isNotEmpty).join(' · '),
                        style: typo.body13.copyWith(color: ext.textMuted),
                      ),
                    ],
                  ),
                ),
                if (company?.subscriptionStatus == SubscriptionStatus.active)
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: ext.errorColor,
                    ),
                    onPressed: () => unawaited(_cancel()),
                    child: const Text('Cancelar assinatura'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Planos', style: typo.title16.copyWith(color: ext.textPrimary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final p in plans)
                _PlanCard(
                  plan: p,
                  current:
                      current != null &&
                      current.toLowerCase() == p.name.toLowerCase(),
                  onSubscribe: () => unawaited(_subscribe(p)),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SectionCard(
                  title: 'Cartões',
                  trailing: TextButton.icon(
                    onPressed: () => unawaited(_addCard()),
                    icon: const Icon(Icons.add_card_outlined, size: 18),
                    label: const Text('Adicionar'),
                  ),
                  child: _methods.isEmpty
                      ? Text(
                          'Nenhum cartão salvo.',
                          style: typo.body13.copyWith(color: ext.textMuted),
                        )
                      : Column(
                          children: [
                            for (final m in _methods)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  Icons.credit_card_rounded,
                                  color: ext.textMuted,
                                ),
                                title: Text(
                                  '${m.brand.toUpperCase()} •••• ${m.last4}',
                                ),
                                subtitle: Text(
                                  '${m.holderName} · validade ${m.expiry}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (m.isPrimary)
                                      const FormaBadge(
                                        label: 'Principal',
                                        variant: FormaBadgeVariant.primary,
                                      ),
                                    FormaMenuButton(
                                      items: [
                                        if (!m.isPrimary)
                                          FormaMenuItem(
                                            label: 'Tornar principal',
                                            icon: Icons.star_outline_rounded,
                                            onTap: () => unawaited(
                                              _run(
                                                'Cartão principal atualizado',
                                                () => _repo.setPrimary(m.id),
                                              ),
                                            ),
                                          ),
                                        FormaMenuItem(
                                          label: 'Remover',
                                          icon: Icons.delete_outline,
                                          destructive: true,
                                          onTap: () async {
                                            if (!await confirmDelete(
                                              context,
                                              what: 'o cartão final ${m.last4}',
                                            )) {
                                              return;
                                            }
                                            await _run(
                                              'Cartão removido',
                                              () => _repo.removeCard(m.id),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SectionCard(
                  title: 'Cobranças',
                  child: _payments.isEmpty
                      ? Text(
                          'Nenhuma cobrança ainda.',
                          style: typo.body13.copyWith(color: ext.textMuted),
                        )
                      : Column(
                          children: [
                            for (final p in _payments)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            Fmt.money(p.amount),
                                            style: typo.body14Medium.copyWith(
                                              color: ext.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            _paymentDates(p),
                                            style: typo.caption12.copyWith(
                                              color: ext.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    FormaBadge(
                                      label: p.statusLabel,
                                      variant: p.isPaid
                                          ? FormaBadgeVariant.success
                                          : p.statusLabel == 'Vencido'
                                          ? FormaBadgeVariant.error
                                          : FormaBadgeVariant.warning,
                                    ),
                                    if (p.invoiceUrl != null)
                                      IconButton(
                                        tooltip: 'Abrir fatura',
                                        icon: const Icon(
                                          Icons.open_in_new_rounded,
                                          size: 18,
                                        ),
                                        onPressed: () => unawaited(
                                          launchUrl(Uri.parse(p.invoiceUrl!)),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _run(String success, Future<void> Function() action) async {
    try {
      await action();
      await _load();
      if (mounted) Toasts.success(context, success);
    } on ApiError catch (e) {
      if (mounted) Toasts.error(context, e);
    }
  }

  Future<PaymentMethod?> _addCard() {
    final holder = TextEditingController();
    final number = TextEditingController();
    final month = TextEditingController();
    final year = TextEditingController();
    final ccv = TextEditingController();
    final digits = FilteringTextInputFormatter.digitsOnly;
    return showFormDialog<PaymentMethod>(
      context,
      title: 'Adicionar cartão',
      description: 'Os dados vão direto ao processador de pagamentos (Asaas).',
      fields: (_) => [
        FormaTextField(
          label: 'Nome impresso no cartão',
          controller: holder,
          autofocus: true,
          validator: requiredValidator,
        ),
        FormaTextField(
          label: 'Número',
          controller: number,
          inputFormatters: [digits, LengthLimitingTextInputFormatter(19)],
          validator: (v) => (v ?? '').length < 13 ? 'Número inválido' : null,
        ),
        Row(
          children: [
            Expanded(
              child: FormaTextField(
                label: 'Mês',
                hint: 'MM',
                controller: month,
                inputFormatters: [digits, LengthLimitingTextInputFormatter(2)],
                validator: (v) {
                  final m = int.tryParse(v ?? '') ?? 0;
                  return m >= 1 && m <= 12 ? null : 'Inválido';
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FormaTextField(
                label: 'Ano',
                hint: 'AAAA',
                controller: year,
                inputFormatters: [digits, LengthLimitingTextInputFormatter(4)],
                validator: (v) => (v ?? '').length == 4 ? null : 'AAAA',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FormaTextField(
                label: 'CVV',
                controller: ccv,
                obscureText: true,
                inputFormatters: [digits, LengthLimitingTextInputFormatter(4)],
                validator: (v) => (v ?? '').length >= 3 ? null : 'Inválido',
              ),
            ),
          ],
        ),
      ],
      onSubmit: () async {
        final card = await _repo.addCard(
          NewCard(
            holderName: holder.text,
            number: number.text,
            expiryMonth: month.text.padLeft(2, '0'),
            expiryYear: year.text,
            ccv: ccv.text,
          ),
        );
        await _load();
        return card;
      },
    );
  }

  Future<void> _subscribe(Plan plan) async {
    var type = BillingType.creditCard;
    var methodId =
        _methods.where((m) => m.isPrimary).firstOrNull?.id ??
        _methods.firstOrNull?.id;
    final result = await showFormDialog<SubscriptionInfo>(
      context,
      title: 'Assinar ${plan.name}',
      description: '${Fmt.money(plan.price)}${plan.cycleLabel}',
      submitLabel: 'Confirmar assinatura',
      fields: (setState) => [
        FormaSelect<BillingType>(
          label: 'Forma de pagamento',
          value: type,
          options: [
            for (final t in BillingType.values)
              FormaSelectOption(value: t, label: t.label),
          ],
          onChanged: (v) => setState(() => type = v ?? BillingType.creditCard),
        ),
        if (type == BillingType.creditCard)
          // Cartão: oferecer cadastro quando não há cartão salvo.
          // ignore: prefer_if_elements_to_conditional_expressions
          _methods.isEmpty
              ? Row(
                  children: [
                    const Expanded(child: Text('Nenhum cartão salvo.')),
                    TextButton(
                      onPressed: () async {
                        final card = await _addCard();
                        if (card != null) setState(() => methodId = card.id);
                      },
                      child: const Text('Adicionar cartão'),
                    ),
                  ],
                )
              : FormaSelect<String>(
                  label: 'Cartão',
                  value: methodId,
                  options: [
                    for (final m in _methods)
                      FormaSelectOption(
                        value: m.id,
                        label: '${m.brand.toUpperCase()} •••• ${m.last4}',
                      ),
                  ],
                  onChanged: (v) => setState(() => methodId = v),
                ),
      ],
      onSubmit: () {
        if (type == BillingType.creditCard && methodId == null) {
          throw const ValidationError('Adicione ou selecione um cartão.');
        }
        return _repo.subscribe(
          planId: plan.id,
          type: type,
          paymentMethodId: type == BillingType.creditCard ? methodId : null,
        );
      },
    );
    if (result == null || !mounted) return;
    context.read<SessionCubit>().clearSubscriptionBlock();
    unawaited(context.read<CurrentCompanyCubit>().load());
    await _load();
    if (!mounted) return;
    FormaToast.show(
      context,
      message: 'Assinatura solicitada',
      description: type == BillingType.creditCard
          ? 'Pagamento em processamento.'
          : 'Abra a fatura para pagar via ${type.label}.',
      variant: FormaToastVariant.success,
      actionLabel: result.invoiceUrl == null ? null : 'Abrir fatura',
      onAction: result.invoiceUrl == null
          ? null
          : () => unawaited(launchUrl(Uri.parse(result.invoiceUrl!))),
    );
  }

  Future<void> _cancel() async {
    final cancelled = await showCancelSubscriptionDialog(
      context,
      repository: _repo,
    );
    if (!cancelled || !mounted) return;
    Toasts.success(context, 'Assinatura cancelada');
    unawaited(context.read<CurrentCompanyCubit>().load());
    await _load();
  }
}

String _nextCharge(SubscriptionInfo s) =>
    'próxima cobrança em ${Fmt.date(s.nextDueDate)}';

String _paymentDates(Payment p) => [
  'vencimento ${Fmt.date(p.dueDate)}',
  if (p.paymentDate != null) 'pago em ${Fmt.date(p.paymentDate)}',
].join(' · ');

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.current,
    required this.onSubscribe,
  });

  final Plan plan;
  final bool current;
  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final highlight = current || plan.popular;
    return Container(
      width: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ext.cardBackground,
        borderRadius: BorderRadius.circular(context.formaShape.cardRadius),
        border: Border.all(
          color: highlight ? ext.primaryColor : ext.border,
          width: highlight ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.name,
                  style: typo.title16.copyWith(color: ext.textPrimary),
                ),
              ),
              if (current)
                const FormaBadge(
                  label: 'Atual',
                  variant: FormaBadgeVariant.success,
                )
              else if (plan.popular)
                const FormaBadge(
                  label: 'Mais popular',
                  variant: FormaBadgeVariant.primary,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              text: Fmt.money(plan.price),
              style: typo.h3.copyWith(color: ext.textPrimary),
              children: [
                TextSpan(
                  text: plan.cycleLabel,
                  style: typo.body14.copyWith(color: ext.textMuted),
                ),
              ],
            ),
          ),
          if (plan.description != null) ...[
            const SizedBox(height: 6),
            Text(
              plan.description!,
              style: typo.body13.copyWith(color: ext.textMuted),
            ),
          ],
          const SizedBox(height: 14),
          for (final f in plan.features)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    f.available ? Icons.check_rounded : Icons.close_rounded,
                    size: 16,
                    color: f.available ? ext.successColor : ext.textHint,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f.name,
                      style: typo.body13.copyWith(
                        color: f.available ? ext.textPrimary : ext.textHint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          if (!current)
            FormaButton(
              label: 'Assinar',
              variant: highlight
                  ? FormaButtonVariant.primary
                  : FormaButtonVariant.secondary,
              width: double.infinity,
              small: true,
              onPressed: onSubscribe,
            ),
        ],
      ),
    );
  }
}
