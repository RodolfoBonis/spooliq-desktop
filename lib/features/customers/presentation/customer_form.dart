import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forma_ui/forma_ui.dart';
import 'package:spooliq_desktop/core/di/injector.dart';
import 'package:spooliq_desktop/core/format/masks.dart';
import 'package:spooliq_desktop/core/ui/form_dialog.dart';
import 'package:spooliq_desktop/features/customers/domain/customer.dart';
import 'package:spooliq_desktop/features/customers/domain/customer_repository.dart';

/// Diálogo de criação/edição de cliente. Retorna o cliente salvo.
Future<Customer?> showCustomerForm(BuildContext context, {Customer? customer}) {
  final c = customer;
  final ctrl = {
    'name': TextEditingController(text: c?.name),
    'email': TextEditingController(text: c?.email),
    'phone': TextEditingController(text: Masks.format(Masks.phone, c?.phone)),
    'document': TextEditingController(
      text: Masks.format(Masks.document, c?.document),
    ),
    'address': TextEditingController(text: c?.address),
    'city': TextEditingController(text: c?.city),
    'state': TextEditingController(text: c?.state),
    'zip': TextEditingController(text: Masks.format(Masks.cep, c?.zipCode)),
    'notes': TextEditingController(text: c?.notes),
  };
  var active = c?.isActive ?? true;
  final repo = di<CustomerRepository>();

  return showFormDialog<Customer>(
    context,
    title: c == null ? 'Novo cliente' : 'Editar cliente',
    width: 600,
    fields: (setState) => [
      FormaTextField(
        label: 'Nome',
        controller: ctrl['name'],
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        validator: requiredValidator,
      ),
      Row(
        children: [
          Expanded(
            child: FormaTextField(
              label: 'E-mail',
              controller: ctrl['email'],
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return null;
                return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)
                    ? null
                    : 'E-mail inválido';
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FormaTextField(
              label: 'Telefone / WhatsApp',
              hint: '(00) 00000-0000',
              controller: ctrl['phone'],
              keyboardType: TextInputType.phone,
              inputFormatters: [Masks.phone],
            ),
          ),
        ],
      ),
      FormaTextField(
        label: 'CPF / CNPJ',
        controller: ctrl['document'],
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp('[0-9./-]')),
          LengthLimitingTextInputFormatter(18),
        ],
      ),
      FormaTextField(label: 'Endereço', controller: ctrl['address']),
      Row(
        children: [
          Expanded(
            flex: 3,
            child: FormaTextField(label: 'Cidade', controller: ctrl['city']),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: FormaTextField(
              label: 'UF',
              controller: ctrl['state'],
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [LengthLimitingTextInputFormatter(2)],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 140,
            child: FormaTextField(
              label: 'CEP',
              controller: ctrl['zip'],
              inputFormatters: [Masks.cep],
            ),
          ),
        ],
      ),
      FormaTextField(
        label: 'Observações',
        controller: ctrl['notes'],
        maxLines: 3,
        minLines: 2,
      ),
      if (c != null)
        FormaCheckbox(
          value: active,
          label: 'Cliente ativo',
          onChanged: (v) => setState(() => active = v),
        ),
    ],
    onSubmit: () {
      final input = CustomerInput(
        name: ctrl['name']!.text,
        email: ctrl['email']!.text,
        phone: ctrl['phone']!.text,
        document: ctrl['document']!.text,
        address: ctrl['address']!.text,
        city: ctrl['city']!.text,
        state: ctrl['state']!.text,
        zipCode: ctrl['zip']!.text,
        notes: ctrl['notes']!.text,
        isActive: c == null ? null : active,
      );
      return c == null ? repo.create(input) : repo.update(c.id, input);
    },
  );
}
