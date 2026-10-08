import 'package:flutter_driver/driver_extension.dart';
import 'package:spooliq_desktop/app/app.dart';
import 'package:spooliq_desktop/bootstrap.dart';
import 'package:spooliq_desktop/core/config/app_config.dart';

/// Entry point para automação (flutter_driver / screenshots).
Future<void> main() async {
  // Sem emulação de texto: o teclado real continua funcionando enquanto a
  // automação inspeciona o app.
  enableFlutterDriverExtension(enableTextEntryEmulation: false);
  await bootstrap(SpoolIqApp.new, flavor: Flavor.production);
}
