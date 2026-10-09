import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/network/api_error.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/core/observability/app_logger.dart';
import 'package:spooliq_desktop/core/ui/feedback.dart';
import 'package:spooliq_desktop/core/ui/form_dialog.dart';
import 'package:spooliq_desktop/features/customers/domain/customer_repository.dart';
import 'package:spooliq_desktop/features/models3d/domain/model3d.dart';

/// Escolhe um STL/3MF e envia para a biblioteca. [customer] já vem
/// selecionado quando o envio parte da tela do cliente.
Future<Model3D?> showUploadModelDialog(
  BuildContext context, {
  FormaSelectOption<String>? customer,
}) async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(label: 'Modelos 3D', extensions: ['stl', '3mf']),
    ],
  );
  if (file == null || !context.mounted) return null;
  final fields = _ModelFields(
    name: file.name.replaceAll(
      RegExp(r'\.(stl|3mf)$', caseSensitive: false),
      '',
    ),
    customer: customer,
  );

  final saved = await showFormDialog<Model3D>(
    context,
    title: 'Enviar modelo',
    description: file.name,
    submitLabel: 'Enviar',
    fields: fields.build,
    onSubmit: () => di<Model3DRepository>().upload(
      filePath: file.path,
      name: fields.name.text,
      description: fields.description.text,
      customerId: fields.customer?.value,
      notes: fields.notes.text,
      tags: fields.tags.text,
    ),
  );
  if (saved != null && context.mounted) {
    Toasts.success(context, 'Modelo enviado', description: saved.name);
  }
  return saved;
}

/// Edita nome, cliente, descrição, tags e notas de um modelo.
Future<Model3D?> showEditModelDialog(BuildContext context, Model3D m) async {
  FormaSelectOption<String>? customer;
  if (m.customerId != null) {
    // A API devolve só o id do cliente; busca o nome para o combobox.
    var label = 'Cliente vinculado';
    try {
      label = (await di<CustomerRepository>().get(m.customerId!)).name;
    } on ApiError {
      // Mantém o rótulo genérico; o vínculo continua editável.
    } on Object catch (e, st) {
      unawaited(
        AppLogger.error(e, st, reason: 'model_customer', category: 'models3d'),
      );
    }
    customer = FormaSelectOption(value: m.customerId!, label: label);
  }
  if (!context.mounted) return null;
  final fields = _ModelFields(
    name: m.name,
    customer: customer,
    description: m.description,
    notes: m.notes,
    tags: m.tags.join(', '),
    canClearCustomer: true,
  );

  final saved = await showFormDialog<Model3D>(
    context,
    title: 'Editar modelo',
    description: m.fileName,
    fields: fields.build,
    onSubmit: () => di<Model3DRepository>().update(
      m.id,
      name: fields.name.text,
      customerId: fields.customer?.value,
      description: fields.description.text,
      notes: fields.notes.text,
      tags: fields.tags.text,
    ),
  );
  if (saved != null && context.mounted) {
    Toasts.success(context, 'Modelo atualizado', description: saved.name);
  }
  return saved;
}

/// Campos compartilhados entre envio e edição.
class _ModelFields {
  _ModelFields({
    required String name,
    this.customer,
    String? description,
    String? notes,
    String? tags,
    this.canClearCustomer = false,
  }) : name = TextEditingController(text: name),
       description = TextEditingController(text: description),
       notes = TextEditingController(text: notes),
       tags = TextEditingController(text: tags);

  final TextEditingController name;
  final TextEditingController description;
  final TextEditingController notes;
  final TextEditingController tags;
  final bool canClearCustomer;
  FormaSelectOption<String>? customer;

  List<Widget> build(StateSetter setState) => [
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
    if (canClearCustomer && customer != null)
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => customer = null),
          icon: const Icon(Icons.link_off_rounded, size: 16),
          label: const Text('Remover cliente'),
        ),
      ),
    FormaTextField(label: 'Descrição', controller: description, maxLines: 2),
    FormaTextField(
      label: 'Tags',
      hint: 'separadas por vírgula',
      controller: tags,
    ),
    FormaTextField(label: 'Notas', controller: notes, maxLines: 2),
  ];
}
