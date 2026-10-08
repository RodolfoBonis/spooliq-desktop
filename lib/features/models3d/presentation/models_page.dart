import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/core/auth/permissions.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/format/formatters.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/core/state/paged_list_cubit.dart';
import 'package:spooliq_desktop/core/ui/feedback.dart';
import 'package:spooliq_desktop/core/ui/form_dialog.dart';
import 'package:spooliq_desktop/core/ui/page_layout.dart';
import 'package:spooliq_desktop/core/ui/paged_table.dart';
import 'package:spooliq_desktop/core/ui/search_field.dart';
import 'package:spooliq_desktop/features/auth/presentation/session_cubit.dart';
import 'package:spooliq_desktop/features/customers/domain/customer_repository.dart';
import 'package:spooliq_desktop/features/models3d/domain/model3d.dart';
import 'package:spooliq_desktop/features/models3d/presentation/slice_analysis_view.dart';
import 'package:spooliq_desktop/features/models3d/viewer/model_preview.dart';

class ModelsPage extends StatelessWidget {
  const ModelsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = PagedListCubit<Model3D>(
          (q) => di<Model3DRepository>().list(page: q),
          idOf: (m) => m.id,
          initialQuery: const PageQuery(sortBy: 'created_at'),
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: const _ModelsView(),
    );
  }
}

class _ModelsView extends StatelessWidget {
  const _ModelsView();

  @override
  Widget build(BuildContext context) {
    final canDelete = context.select<SessionCubit, bool>(
      (c) => c.state.user?.canDeleteModels ?? false,
    );
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final cubit = context.read<PagedListCubit<Model3D>>();
    final muted = typo.body14.copyWith(color: ext.textMuted);

    return PageLayout(
      title: 'Modelos 3D',
      subtitle: 'Biblioteca de STL e 3MF, com análise do fatiador.',
      actions: [
        FormaButton.primary(
          label: 'Enviar modelo',
          small: true,
          icon: const Icon(Icons.upload_rounded, size: 18, color: Colors.white),
          onPressed: () => unawaited(_upload(context)),
        ),
      ],
      toolbar: SearchField(hint: 'Buscar modelos…', onChanged: cubit.search),
      body: PagedTable<Model3D>(
        itemLabel: 'modelos',
        onRowTap: (m) => unawaited(_details(context, m)),
        columns: [
          FormaColumn(
            id: 'name',
            label: 'Modelo',
            flex: 3,
            sortable: true,
            cellBuilder: (_, m) => Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: ext.accentSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.view_in_ar_outlined,
                    size: 18,
                    color: ext.accentColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typo.body14Medium.copyWith(
                          color: ext.textPrimary,
                        ),
                      ),
                      Text(
                        m.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typo.caption12.copyWith(color: ext.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          FormaColumn(
            id: 'format',
            label: 'Formato',
            width: 100,
            cellBuilder: (_, m) => Align(
              alignment: Alignment.centerLeft,
              child: FormaBadge(
                label: m.format,
                variant: FormaBadgeVariant.neutral,
              ),
            ),
          ),
          FormaColumn(
            id: 'file_size_bytes',
            label: 'Tamanho',
            width: 110,
            sortable: true,
            cellBuilder: (_, m) => Text(m.sizeLabel, style: muted),
          ),
          FormaColumn(
            id: 'tags',
            label: 'Tags',
            flex: 2,
            cellBuilder: (_, m) => Text(
              m.tags.isEmpty ? '—' : m.tags.join(', '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: muted,
            ),
          ),
          FormaColumn(
            id: 'created_at',
            label: 'Enviado em',
            width: 120,
            sortable: true,
            cellBuilder: (_, m) => Text(Fmt.date(m.createdAt), style: muted),
          ),
        ],
        trailingBuilder: (context, m) => FormaMenuButton(
          items: [
            FormaMenuItem(
              label: 'Visualizar em 3D',
              icon: Icons.threed_rotation_rounded,
              onTap: () => unawaited(showModelViewerDialog(context, m)),
            ),
            FormaMenuItem(
              label: 'Detalhes e fatiamento',
              icon: Icons.insights_outlined,
              onTap: () => unawaited(_details(context, m)),
            ),
            FormaMenuItem(
              label: 'Baixar arquivo',
              icon: Icons.download_rounded,
              onTap: () => unawaited(_download(context, m)),
            ),
            if (canDelete) ...[
              const FormaMenuItem.divider(),
              FormaMenuItem(
                label: 'Excluir',
                icon: Icons.delete_outline,
                destructive: true,
                onTap: () async {
                  if (!await confirmDelete(
                    context,
                    what: 'o modelo "${m.name}"',
                  )) {
                    return;
                  }
                  try {
                    await di<Model3DRepository>().delete(m.id);
                    cubit.remove(m.id);
                    if (context.mounted) {
                      Toasts.success(context, 'Modelo excluído');
                    }
                  } on ApiError catch (e) {
                    if (context.mounted) Toasts.error(context, e);
                  }
                },
              ),
            ],
          ],
        ),
        empty: FormaEmptyState(
          icon: Icons.view_in_ar_outlined,
          title: 'Nenhum modelo ainda',
          message: 'Envie arquivos STL ou 3MF para reutilizar nos orçamentos.',
          action: FormaButton.primary(
            label: 'Enviar modelo',
            small: true,
            onPressed: () => unawaited(_upload(context)),
          ),
        ),
      ),
    );
  }

  Future<void> _upload(BuildContext context) async {
    final cubit = context.read<PagedListCubit<Model3D>>();
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Modelos 3D', extensions: ['stl', '3mf']),
      ],
    );
    if (file == null || !context.mounted) return;
    final name = TextEditingController(
      text: file.name.replaceAll(
        RegExp(r'\.(stl|3mf)$', caseSensitive: false),
        '',
      ),
    );
    final description = TextEditingController();
    final notes = TextEditingController();
    final tags = TextEditingController();
    FormaSelectOption<String>? customer;
    const progress = 0.0;

    final saved = await showFormDialog<Model3D>(
      context,
      title: 'Enviar modelo',
      description: file.name,
      submitLabel: 'Enviar',
      fields: (setState) => [
        FormaTextField(
          label: 'Nome',
          controller: name,
          autofocus: true,
          validator: requiredValidator,
        ),
        FormaCombobox<String>(
          label: 'Cliente (opcional)',
          value: customer,
          search: (q) async {
            final page = await di<CustomerRepository>().list(
              page: PageQuery(pageSize: 8, search: q.isEmpty ? null : q),
            );
            return [
              for (final c in page.items)
                FormaSelectOption(value: c.id, label: c.name),
            ];
          },
          onChanged: (v) => setState(() => customer = v),
        ),
        FormaTextField(
          label: 'Descrição',
          controller: description,
          maxLines: 2,
        ),
        FormaTextField(
          label: 'Tags',
          hint: 'separadas por vírgula',
          controller: tags,
        ),
        FormaTextField(label: 'Notas', controller: notes, maxLines: 2),
        if (progress > 0) const LinearProgressIndicator(value: progress),
      ],
      onSubmit: () => di<Model3DRepository>().upload(
        filePath: file.path,
        name: name.text,
        description: description.text,
        customerId: customer?.value,
        notes: notes.text,
        tags: tags.text,
      ),
    );
    if (saved == null || !context.mounted) return;
    cubit.upsert(saved);
    Toasts.success(context, 'Modelo enviado', description: saved.name);
  }

  Future<void> _download(BuildContext context, Model3D m) async {
    final location = await getSaveLocation(suggestedName: m.fileName);
    if (location == null) return;
    try {
      final bytes = await di<Model3DRepository>().download(m.id);
      await File(location.path).writeAsBytes(bytes, flush: true);
      if (context.mounted) Toasts.success(context, 'Arquivo salvo');
    } on ApiError catch (e) {
      if (context.mounted) Toasts.error(context, e);
    }
  }

  Future<void> _details(BuildContext context, Model3D m) =>
      FormaSideSheet.show<void>(
        context,
        width: 760,
        builder: (_) => _ModelSheet(model: m),
      );
}

class _ModelSheet extends StatefulWidget {
  const _ModelSheet({required this.model});

  final Model3D model;

  @override
  State<_ModelSheet> createState() => _ModelSheetState();
}

class _ModelSheetState extends State<_ModelSheet> {
  SliceAnalysis? _analysis;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final a = await di<Model3DRepository>().sliceAnalysis(widget.model.id);
      if (mounted) setState(() => _analysis = a);
    } on ApiError catch (e) {
      if (mounted) {
        setState(() => _error = e is NotFoundError ? null : e.message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FormaThemeExtension>()!;
    final typo = context.formaTypography;
    final m = widget.model;
    final a = _analysis;
    return FormaSideSheetScaffold(
      title: m.name,
      subtitle: '${m.format} · ${m.sizeLabel}',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ModelPreview(model: m),
          const SizedBox(height: 16),
          if (m.description != null)
            Text(
              m.description!,
              style: typo.body14.copyWith(color: ext.textMuted),
            ),
          if (m.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in m.tags)
                  FormaBadge(label: t, variant: FormaBadgeVariant.neutral),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Análise do fatiador',
            style: typo.title15.copyWith(color: ext.textPrimary),
          ),
          const SizedBox(height: 6),
          if (_loading)
            const LoadingView()
          else if (_error != null)
            Text(_error!, style: typo.body13.copyWith(color: ext.errorColor))
          else if (a == null || a.plates.isEmpty)
            Text(
              'Sem análise disponível. Arquivos .3mf fatiados (Bambu Studio / OrcaSlicer) trazem tempo e filamentos.',
              style: typo.body13.copyWith(color: ext.textMuted),
            )
          else
            SliceAnalysisView(analysis: a),
          if (m.notes != null) ...[
            const SizedBox(height: 20),
            Text('Notas', style: typo.title15.copyWith(color: ext.textPrimary)),
            const SizedBox(height: 6),
            Text(m.notes!, style: typo.body13.copyWith(color: ext.textMuted)),
          ],
        ],
      ),
    );
  }
}
