import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// Arquivo pronto para `POST /slicer/analyze`. Quando [temporary], é uma
/// cópia enxuta criada só para o upload e deve ser apagada depois.
class SliceUpload {
  const SliceUpload(this.path, {this.temporary = false});

  final String path;
  final bool temporary;

  Future<void> dispose() async {
    if (!temporary) return;
    try {
      await File(path).parent.delete(recursive: true);
    } on FileSystemException {
      // Pasta temporária: o sistema limpa depois.
    }
  }
}

/// Entradas de um projeto fatiado que bastam para a análise (tempo, gramas,
/// cores e objetos por mesa). G-codes e imagens, que somam centenas de MB em
/// projetos grandes, ficam de fora.
const sliceMetadataEntries = {
  'Metadata/slice_info.config',
  'Metadata/project_settings.config',
  'Metadata/model_settings.config',
  '[Content_Types].xml',
  '_rels/.rels',
};

/// O parser de G-code só lê os primeiros e os últimos 2 MB do arquivo.
const int gcodeHeadTailBytes = 2 * 1024 * 1024;

/// Acima disto enviamos só o necessário (o servidor aceita até 95 MB).
const int directUploadLimitBytes = 8 * 1024 * 1024;

/// Prepara o arquivo do fatiador para análise sem subir o projeto inteiro:
/// - `.3mf` com `slice_info.config`: só os metadados (poucos KB);
/// - `.gcode` grande: só o começo e o fim, que é o que o servidor lê;
/// - o resto vai como está.
Future<SliceUpload> prepareSliceUpload(String filePath) async {
  final size = await File(filePath).length();
  if (size <= directUploadLimitBytes) return SliceUpload(filePath);
  final lower = filePath.toLowerCase();
  final slim = await Isolate.run(
    () => lower.endsWith('.3mf')
        ? slimSlicedProject(filePath)
        : lower.endsWith('.gcode')
        ? gcodeHeadTail(filePath)
        : null,
  );
  return slim == null
      ? SliceUpload(filePath)
      : SliceUpload(slim, temporary: true);
}

/// Cria um `.3mf` só com os metadados do fatiamento. Null quando o projeto
/// não tem `slice_info.config` (aí o servidor precisa dos G-codes).
String? slimSlicedProject(String filePath) {
  final input = InputFileStream(filePath);
  try {
    final archive = ZipDecoder().decodeStream(input);
    final out = Archive();
    var hasSliceInfo = false;
    for (final f in archive.files) {
      if (!f.isFile || !sliceMetadataEntries.contains(f.name)) continue;
      final bytes = f.readBytes();
      if (bytes == null) continue;
      out.addFile(ArchiveFile.bytes(f.name, bytes));
      if (f.name == 'Metadata/slice_info.config') hasSliceInfo = true;
    }
    if (!hasSliceInfo) return null;
    return _writeTemp(filePath, ZipEncoder().encodeBytes(out));
  } on Object {
    // Arquivo que não abre aqui: o servidor dá o erro certo para ele.
    return null;
  } finally {
    input.closeSync();
  }
}

/// Começo + fim de um G-code grande (onde ficam o fatiador, o tempo e as
/// gramas). Null quando a leitura falha.
String? gcodeHeadTail(String filePath) {
  RandomAccessFile? raf;
  try {
    raf = File(filePath).openSync();
    final length = raf.lengthSync();
    final head = raf.readSync(gcodeHeadTailBytes);
    raf.setPositionSync(length - gcodeHeadTailBytes);
    final tail = raf.readSync(gcodeHeadTailBytes);
    final bytes = BytesBuilder(copy: false)
      ..add(head)
      ..add('\n'.codeUnits)
      ..add(tail);
    return _writeTemp(filePath, bytes.takeBytes());
  } on Object {
    return null;
  } finally {
    raf?.closeSync();
  }
}

String _writeTemp(String original, List<int> bytes) {
  final dir = Directory.systemTemp.createTempSync('spooliq-slice-');
  // Mantém o nome (e a extensão) do original: o servidor detecta o formato
  // e o app sugere o nome do produto a partir dele.
  final out = File(p.join(dir.path, p.basename(original)))
    ..writeAsBytesSync(bytes, flush: true);
  return out.path;
}
