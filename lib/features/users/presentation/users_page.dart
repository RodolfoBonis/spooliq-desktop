import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/core/auth/session_user.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/format/formatters.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/state/paged_list_cubit.dart';
import 'package:spooliq_desktop/core/ui/feedback.dart';
import 'package:spooliq_desktop/core/ui/form_dialog.dart';
import 'package:spooliq_desktop/core/ui/page_layout.dart';
import 'package:spooliq_desktop/core/ui/paged_table.dart';
import 'package:spooliq_desktop/features/auth/presentation/session_cubit.dart';
import 'package:spooliq_desktop/features/users/domain/app_user.dart';

class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = PagedListCubit<AppUser>(
          (q) => di<UserRepository>().list(page: q),
          idOf: (u) => u.id,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: const _UsersView(),
    );
  }
}

class _UsersView extends StatelessWidget {
  const _UsersView();

  @override
  Widget build(BuildContext context) {
    final me = context.select<SessionCubit, SessionUser?>((c) => c.state.user);
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final muted = typo.body14.copyWith(color: ext.textMuted);

    bool isMe(AppUser u) => u.email == me?.email;

    return PageLayout(
      title: 'Usuários',
      subtitle: 'Quem da sua equipe acessa o SpoolIQ.',
      actions: [
        FormaButton.primary(
          label: 'Adicionar usuário',
          small: true,
          icon: const Icon(
            Icons.person_add_alt_outlined,
            size: 18,
            color: Colors.white,
          ),
          onPressed: () => unawaited(_create(context)),
        ),
      ],
      body: PagedTable<AppUser>(
        itemLabel: 'usuários',
        columns: [
          FormaColumn(
            id: 'name',
            label: 'Usuário',
            flex: 3,
            cellBuilder: (_, u) => Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: ext.primarySurface,
                  child: Text(
                    u.name.isEmpty ? '?' : u.name[0].toUpperCase(),
                    style: typo.caption12Med.copyWith(color: ext.primaryColor),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMe(u) ? '${u.name} (você)' : u.name,
                        style: typo.body14Medium.copyWith(
                          color: ext.textPrimary,
                        ),
                      ),
                      Text(
                        u.email,
                        style: typo.caption12.copyWith(color: ext.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          FormaColumn(
            id: 'type',
            label: 'Papel',
            width: 150,
            cellBuilder: (_, u) => Align(
              alignment: Alignment.centerLeft,
              child: FormaBadge(
                label: u.type.label,
                variant: switch (u.type) {
                  UserType.owner => FormaBadgeVariant.primary,
                  UserType.admin => FormaBadgeVariant.info,
                  UserType.user => FormaBadgeVariant.neutral,
                },
              ),
            ),
          ),
          FormaColumn(
            id: 'active',
            label: 'Status',
            width: 120,
            cellBuilder: (_, u) => Align(
              alignment: Alignment.centerLeft,
              child: FormaBadge(
                label: u.isActive ? 'Ativo' : 'Inativo',
                variant: u.isActive
                    ? FormaBadgeVariant.success
                    : FormaBadgeVariant.neutral,
              ),
            ),
          ),
          FormaColumn(
            id: 'created_at',
            label: 'Desde',
            width: 120,
            cellBuilder: (_, u) => Text(Fmt.date(u.createdAt), style: muted),
          ),
        ],
        trailingBuilder: (context, u) => u.type == UserType.owner || isMe(u)
            ? const SizedBox.shrink()
            : FormaMenuButton(
                items: [
                  FormaMenuItem(
                    label: 'Editar nome',
                    icon: Icons.edit_outlined,
                    onTap: () => unawaited(_rename(context, u)),
                  ),
                  FormaMenuItem(
                    label: u.isActive ? 'Desativar acesso' : 'Reativar acesso',
                    icon: u.isActive
                        ? Icons.block_outlined
                        : Icons.check_circle_outline,
                    onTap: () => unawaited(_toggle(context, u)),
                  ),
                  const FormaMenuItem.divider(),
                  FormaMenuItem(
                    label: 'Remover',
                    icon: Icons.delete_outline,
                    destructive: true,
                    onTap: () => unawaited(_delete(context, u)),
                  ),
                ],
              ),
        empty: const FormaEmptyState(
          icon: Icons.manage_accounts_outlined,
          title: 'Só você por aqui',
          message: 'Adicione pessoas da equipe para colaborar nos orçamentos.',
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context) async {
    final cubit = context.read<PagedListCubit<AppUser>>();
    final name = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    var type = UserType.user;
    final saved = await showFormDialog<AppUser>(
      context,
      title: 'Adicionar usuário',
      description: 'A pessoa entra com este e-mail e senha.',
      fields: (setState) => [
        FormaTextField(
          label: 'Nome',
          controller: name,
          autofocus: true,
          validator: requiredValidator,
        ),
        FormaTextField(
          label: 'E-mail',
          controller: email,
          keyboardType: TextInputType.emailAddress,
          validator: (v) =>
              RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v ?? '')
              ? null
              : 'E-mail inválido',
        ),
        FormaTextField(
          label: 'Senha inicial',
          controller: password,
          obscureText: true,
          helperText: 'Mínimo de 8 caracteres',
          validator: (v) =>
              (v ?? '').length < 8 ? 'Mínimo de 8 caracteres' : null,
        ),
        FormaSelect<UserType>(
          label: 'Papel',
          value: type,
          options: const [
            FormaSelectOption(
              value: UserType.user,
              label: 'Usuário',
              subtitle: 'Cria e acompanha orçamentos',
            ),
            FormaSelectOption(
              value: UserType.admin,
              label: 'Administrador',
              subtitle: 'Também gerencia catálogo, presets, empresa e equipe',
            ),
          ],
          onChanged: (v) => setState(() => type = v ?? UserType.user),
        ),
      ],
      onSubmit: () => di<UserRepository>().create(
        name: name.text,
        email: email.text,
        password: password.text,
        type: type,
      ),
    );
    if (saved == null || !context.mounted) return;
    cubit.upsert(saved);
    Toasts.success(context, 'Usuário adicionado', description: saved.email);
  }

  Future<void> _rename(BuildContext context, AppUser u) async {
    final cubit = context.read<PagedListCubit<AppUser>>();
    final name = TextEditingController(text: u.name);
    final saved = await showFormDialog<AppUser>(
      context,
      title: 'Editar usuário',
      fields: (_) => [
        FormaTextField(
          label: 'Nome',
          controller: name,
          autofocus: true,
          validator: requiredValidator,
        ),
      ],
      onSubmit: () => di<UserRepository>().update(u.id, name: name.text),
    );
    if (saved != null) cubit.upsert(saved);
  }

  Future<void> _toggle(BuildContext context, AppUser u) async {
    final cubit = context.read<PagedListCubit<AppUser>>();
    try {
      final saved = await di<UserRepository>().update(
        u.id,
        isActive: !u.isActive,
      );
      cubit.upsert(saved);
      if (context.mounted) {
        Toasts.success(
          context,
          saved.isActive ? 'Acesso reativado' : 'Acesso desativado',
        );
      }
    } on ApiError catch (e) {
      if (context.mounted) Toasts.error(context, e);
    }
  }

  Future<void> _delete(BuildContext context, AppUser u) async {
    final cubit = context.read<PagedListCubit<AppUser>>();
    if (!await confirmDelete(context, what: '${u.name} da equipe')) return;
    try {
      await di<UserRepository>().delete(u.id);
      cubit.remove(u.id);
      if (context.mounted) Toasts.success(context, 'Usuário removido');
    } on ApiError catch (e) {
      if (context.mounted) Toasts.error(context, e);
    }
  }
}
