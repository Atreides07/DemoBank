import 'package:app_foundation/app_foundation.dart';
import 'package:flutter/widgets.dart';

import 'fines_application.dart';

Future<void> main() async {
  installErrorReporting();
  WidgetsFlutterBinding.ensureInitialized();
  // The stored language is applied before the first frame, so the interface
  // never appears in another language first.
  final environment = AppEnvironment.fromDefines();
  await environment.restorePreferences();
  runApp(FinesApplication(environment: environment));
}
