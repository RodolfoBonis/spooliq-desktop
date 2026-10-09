import 'dart:io';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

/// Versão nova publicada nas GitHub Releases.
class AvailableUpdate extends Equatable {
  const AvailableUpdate({
    required this.version,
    required this.releaseUrl,
    this.downloadUrl,
  });

  /// Sem o "v" (ex.: `0.2.0`).
  final String version;

  /// Página da release (notas de versão).
  final String releaseUrl;

  /// Instalador da plataforma atual (`.dmg` / `.exe`), se publicado.
  final String? downloadUrl;

  @override
  List<Object?> get props => [version, releaseUrl, downloadUrl];
}

/// Consulta a última release pública e compara com a versão instalada.
///
/// Substitui o auto-update (Sparkle/WinSparkle) enquanto o app não tem
/// assinatura Developer ID: avisa e leva ao instalador.
class UpdateChecker {
  UpdateChecker({required this.feedUrl, Dio? dio, String? platform})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 10))),
      _platform = platform ?? Platform.operatingSystem;

  /// `https://api.github.com/repos/<owner>/<repo>/releases/latest`.
  final String feedUrl;
  final Dio _dio;
  final String _platform;

  /// A versão nova, ou null se [current] já é a mais recente.
  Future<AvailableUpdate?> check(String current) async {
    final res = await _dio.get<Map<String, dynamic>>(
      feedUrl,
      options: Options(
        headers: {'Accept': 'application/vnd.github+json'},
      ),
    );
    final json = res.data;
    if (json == null) return null;
    final tag = (json['tag_name'] as String? ?? '').replaceFirst('v', '');
    if (tag.isEmpty || compareVersions(tag, current) <= 0) return null;

    final extension = _platform == 'windows' ? '.exe' : '.dmg';
    final assets = (json['assets'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>();
    final installer = assets
        .where((a) => (a['name'] as String? ?? '').endsWith(extension))
        .firstOrNull;
    return AvailableUpdate(
      version: tag,
      releaseUrl: json['html_url'] as String? ?? feedUrl,
      downloadUrl: installer?['browser_download_url'] as String?,
    );
  }
}

/// Compara `x.y.z` numericamente (sufixos como `+build` são ignorados).
/// Negativo se [a] < [b], zero se iguais, positivo se [a] > [b].
int compareVersions(String a, String b) {
  List<int> parts(String v) => v
      .split('+')
      .first
      .split('-')
      .first
      .split('.')
      .map((p) => int.tryParse(p) ?? 0)
      .toList();
  final pa = parts(a);
  final pb = parts(b);
  for (var i = 0; i < 3; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}
