import 'package:app_foundation/app_foundation.dart';
import 'package:bank_experience/bank_experience.dart';
import 'package:flutter/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final environment = AppEnvironment.fromDefines();
  await environment.restorePreferences();
  runApp(BankExperience(environment: environment, catalog: true));
}
