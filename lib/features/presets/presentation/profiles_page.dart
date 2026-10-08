import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/core/auth/permissions.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/ui/feedback.dart';
import 'package:spooliq_desktop/core/ui/form_dialog.dart';
import 'package:spooliq_desktop/core/ui/page_layout.dart';
import 'package:spooliq_desktop/features/auth/presentation/session_cubit.dart';
import 'package:spooliq_desktop/features/budgets/domain/budget.dart';
import 'package:spooliq_desktop/features/presets/domain/preset.dart';
import 'package:spooliq_desktop/features/presets/domain/preset_repository.dart';

/// Perfis de impressão: combinações prontas de máquina + energia + custos.
class ProfilesPage extends StatefulWidget {
  const ProfilesPage({super.key});

  @override
  State<ProfilesPage> createState() => _ProfilesPageState();
}

class _ProfilesPageState extends State<ProfilesPage> {
  final PresetRepository _repo = di<PresetRepository>();
  List<PrintProfile>? _profiles;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final page = await _repo.profiles();
      if (mounted) setState(() => _profiles = page.items);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
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

  @override
  Widget build(BuildContext context) {
    final canManage = context.select<SessionCubit, bool>(
      (c) => c.state.user?.canManagePresets ?? false,
    );
    final profiles = _profiles;

    return PageLayout(
      title: 'Perfis de impressão',
      subtitle:
          'Escolha um perfil no orçamento e máquina, energia e custos vêm '
          'preenchidos.',
      actions: [
        if (canManage)
          FormaButton.primary(
            label: 'Novo perfil',
            small: true,
            icon: const Icon(Icons.add, size: 18, color: Colors.white),
            onPressed: () => unawaited(_edit()),
          ),
      ],
      body: _error != null
          ? ErrorView(message: _error!, onRetry: () => unawaited(_load()))
          : profiles == null
          ? const LoadingView()
          : profiles.isEmpty
          ? Center(
              child: FormaEmptyState(
                icon: Icons.tune_outlined,
                title: 'Nenhum perfil ainda',
                message:
                    'Crie presets de máquina e energia e combine-os em um perfil.',
                action: canManage
                    ? FormaButton.primary(
                        label: 'Criar perfil',
                        small: true,
                        onPressed: () => unawaited(_edit()),
                      )
                    : null,
              ),
            )
          : SingleChildScrollView(
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final p in profiles)
                    _ProfileCard(
                      profile: p,
                      canManage: canManage,
                      onEdit: () => unawaited(_edit(p)),
                      onDuplicate: () => unawaited(
                        _run('Perfil duplicado', () async {
                          await _repo.duplicateProfile(p.id);
                        }),
                      ),
                      onDefault: () => unawaited(
                        _run(
                          'Perfil padrão atualizado',
                          () => _repo.setDefaultProfile(p.id),
                        ),
                      ),
                      onDelete: () async {
                        if (!await confirmDelete(
                          context,
                          what: 'o perfil "${p.name}"',
                        )) {
                          return;
                        }
                        await _run(
                          'Perfil excluído',
                          () => _repo.deleteProfile(p.id),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Future<void> _edit([PrintProfile? p]) async {
    List<Preset> machines;
    List<Preset> energy;
    List<Preset> costs;
    try {
      machines = await _repo.list(PresetType.machine);
      energy = await _repo.list(PresetType.energy);
      costs = await _repo.list(PresetType.cost);
    } on ApiError catch (e) {
      if (mounted) Toasts.error(context, e);
      return;
    }
    if (!mounted) return;
    final name = TextEditingController(text: p?.name);
    final description = TextEditingController(text: p?.description);
    var machine = p?.machinePreset?.id;
    var power = p?.energyPreset?.id;
    var cost = p?.costPreset?.id;
    var isDefault = p?.isDefault ?? false;
    var submitted = false;

    List<FormaSelectOption<String>> opts(List<Preset> list) => [
      for (final x in list) FormaSelectOption(value: x.id, label: x.name),
    ];

    final saved = await showFormDialog<PrintProfile>(
      context,
      title: p == null ? 'Novo perfil' : 'Editar perfil',
      fields: (setState) => [
        FormaTextField(
          label: 'Nome',
          hint: 'Ex.: P1S · PLA · Curitiba',
          controller: name,
          autofocus: true,
          validator: requiredValidator,
        ),
        FormaSelect<String>(
          label: 'Máquina',
          value: machine,
          options: opts(machines),
          errorText: submitted && machine == null ? 'Obrigatório' : null,
          onChanged: (v) => setState(() => machine = v),
        ),
        FormaSelect<String>(
          label: 'Energia',
          value: power,
          options: opts(energy),
          errorText: submitted && power == null ? 'Obrigatório' : null,
          onChanged: (v) => setState(() => power = v),
        ),
        FormaSelect<String>(
          label: 'Custos e margem',
          hint: 'Padrão da empresa',
          clearable: true,
          value: cost,
          options: opts(costs),
          onChanged: (v) => setState(() => cost = v),
        ),
        FormaTextField(
          label: 'Descrição',
          controller: description,
          maxLines: 2,
        ),
        FormaCheckbox(
          value: isDefault,
          label: 'Perfil padrão dos novos orçamentos',
          onChanged: (v) => setState(() => isDefault = v),
        ),
      ],
      onSubmit: () {
        submitted = true;
        if (machine == null || power == null) {
          throw const ValidationError('Selecione máquina e energia.');
        }
        return _repo.saveProfile(
          id: p?.id,
          name: name.text,
          description: description.text,
          machinePresetId: machine!,
          energyPresetId: power!,
          costPresetId: cost,
          isDefault: isDefault,
        );
      },
    );
    if (saved == null) return;
    await _load();
    if (mounted) {
      Toasts.success(
        context,
        p == null ? 'Perfil criado' : 'Perfil atualizado',
      );
    }
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.canManage,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDefault,
    required this.onDelete,
  });

  final PrintProfile profile;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDefault;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final p = profile;

    Widget row(IconData icon, String label, NamedRef? ref) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: ext.textHint),
          const SizedBox(width: 8),
          Text('$label  ', style: typo.caption12.copyWith(color: ext.textHint)),
          Expanded(
            child: Text(
              ref?.name ?? 'Padrão da empresa',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typo.body13.copyWith(color: ext.textPrimary),
            ),
          ),
        ],
      ),
    );

    return SizedBox(
      width: 340,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: ext.cardBackground,
          borderRadius: BorderRadius.circular(context.formaShape.cardRadius),
          border: Border.all(
            color: p.isDefault ? ext.primaryBorder : ext.border,
            width: p.isDefault ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (p.isDefault) ...[
                  Icon(Icons.star_rounded, size: 18, color: ext.primaryColor),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typo.title15.copyWith(color: ext.textPrimary),
                  ),
                ),
                if (canManage)
                  FormaMenuButton(
                    items: [
                      FormaMenuItem(
                        label: 'Editar',
                        icon: Icons.edit_outlined,
                        onTap: onEdit,
                      ),
                      FormaMenuItem(
                        label: 'Duplicar',
                        icon: Icons.copy_all_outlined,
                        onTap: onDuplicate,
                      ),
                      if (!p.isDefault)
                        FormaMenuItem(
                          label: 'Definir como padrão',
                          icon: Icons.star_outline_rounded,
                          onTap: onDefault,
                        ),
                      const FormaMenuItem.divider(),
                      FormaMenuItem(
                        label: 'Excluir',
                        icon: Icons.delete_outline,
                        destructive: true,
                        onTap: onDelete,
                      ),
                    ],
                  ),
              ],
            ),
            if (p.description != null) ...[
              const SizedBox(height: 4),
              Text(
                p.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: typo.caption12.copyWith(color: ext.textMuted),
              ),
            ],
            row(Icons.print_outlined, 'Máquina', p.machinePreset),
            row(Icons.bolt_outlined, 'Energia', p.energyPreset),
            row(Icons.payments_outlined, 'Custos', p.costPreset),
          ],
        ),
      ),
    );
  }
}
