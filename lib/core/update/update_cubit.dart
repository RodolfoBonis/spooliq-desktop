import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spooliq_desktop/core/observability/app_logger.dart';
import 'package:spooliq_desktop/core/update/update_checker.dart';

/// Versão nova disponível (e não ignorada), ou null.
class UpdateCubit extends Cubit<AvailableUpdate?> {
  UpdateCubit(
    this._checker,
    this._prefs, {
    Future<String> Function()? currentVersion,
    this.interval = const Duration(hours: 6),
  }) : _currentVersion =
           currentVersion ??
           (() async => (await PackageInfo.fromPlatform()).version),
       super(null);

  final UpdateChecker _checker;
  final SharedPreferences _prefs;
  final Future<String> Function() _currentVersion;
  final Duration interval;
  Timer? _timer;

  static const _skippedKey = 'update.skipped_version';

  /// Primeira checagem após [delay] e depois a cada [interval].
  void start({Duration delay = const Duration(seconds: 10)}) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      unawaited(check());
      _timer = Timer.periodic(interval, (_) => unawaited(check()));
    });
  }

  Future<void> check() async {
    try {
      final update = await _checker.check(await _currentVersion());
      if (isClosed) return;
      final skipped = _prefs.getString(_skippedKey);
      emit(update == null || update.version == skipped ? null : update);
    } on Exception catch (e) {
      // Sem rede ou GitHub fora do ar: tenta de novo no próximo ciclo.
      AppLogger.warning('Falha ao verificar atualização', error: e);
    }
  }

  /// "Ignorar esta versão": some até sair uma mais nova.
  Future<void> skip() async {
    final version = state?.version;
    if (version == null) return;
    emit(null);
    await _prefs.setString(_skippedKey, version);
  }

  /// "Depois": some só nesta sessão.
  void dismiss() => emit(null);

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
