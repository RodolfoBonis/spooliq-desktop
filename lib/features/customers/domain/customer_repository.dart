import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:spooliq_desktop/core/network/json.dart';
import 'package:spooliq_desktop/core/network/paginated.dart';
import 'package:spooliq_desktop/features/customers/domain/customer.dart';

abstract interface class CustomerRepository {
  Future<Paginated<Customer>> list({PageQuery page = const PageQuery()});

  Future<Customer> get(String id);

  Future<Customer> create(CustomerInput input);

  Future<Customer> update(String id, CustomerInput input);

  Future<void> delete(String id);

  /// CSV de clientes (opcionalmente filtrado por [search]).
  Future<Uint8List> exportCsv({String? search});

  /// Importa um CSV; devolve o resultado por linha.
  Future<CustomerImportResult> importCsv(String filePath);
}

/// Linha do relatório de importação.
class CustomerImportRow extends Equatable {
  const CustomerImportRow({
    required this.line,
    required this.status,
    this.name,
    this.message,
  });

  factory CustomerImportRow.fromJson(Json j) => CustomerImportRow(
    line: j.integer('line'),
    status: j.str('status'),
    name: j.strOrNull('name'),
    message: j.strOrNull('message'),
  );

  final int line;

  /// `created`, `skipped` ou `error`.
  final String status;
  final String? name;
  final String? message;

  @override
  List<Object?> get props => [line, status, name, message];
}

/// Resultado de `POST /customers/import`.
class CustomerImportResult extends Equatable {
  const CustomerImportResult({
    required this.created,
    required this.skipped,
    required this.failed,
    this.rows = const [],
  });

  factory CustomerImportResult.fromJson(Json j) => CustomerImportResult(
    created: j.integer('created'),
    skipped: j.integer('skipped'),
    failed: j.integer('failed'),
    rows: j.list('rows', CustomerImportRow.fromJson),
  );

  final int created;
  final int skipped;
  final int failed;
  final List<CustomerImportRow> rows;

  /// Linhas que não viraram cliente (para mostrar ao usuário).
  List<CustomerImportRow> get problems =>
      rows.where((r) => r.status != 'created').toList();

  @override
  List<Object?> get props => [created, skipped, failed, rows];
}
