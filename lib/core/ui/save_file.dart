import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

/// Pergunta onde salvar e grava [bytes]. Retorna o caminho, ou null se o
/// usuário cancelar.
Future<String?> saveBytesAs(
  Uint8List bytes, {
  required String suggestedName,
  required String typeLabel,
  required String extension,
}) async {
  final location = await getSaveLocation(
    suggestedName: suggestedName,
    acceptedTypeGroups: [
      XTypeGroup(label: typeLabel, extensions: [extension]),
    ],
  );
  if (location == null) return null;
  // O diálogo do sistema nem sempre acrescenta a extensão.
  final path = location.path.toLowerCase().endsWith('.$extension')
      ? location.path
      : '${location.path}.$extension';
  await File(path).writeAsBytes(bytes, flush: true);
  return path;
}
