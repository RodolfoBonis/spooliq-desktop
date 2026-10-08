import 'package:spooliq_desktop/app/app.dart';
import 'package:spooliq_desktop/bootstrap.dart';
import 'package:spooliq_desktop/core/config/app_config.dart';

Future<void> main() => bootstrap(SpoolIqApp.new, flavor: Flavor.development);
