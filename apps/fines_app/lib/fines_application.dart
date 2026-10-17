import 'package:app_foundation/app_foundation.dart';
import 'package:design_system/design_system.dart';
import 'package:fines/fines.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Separate host: the fines contract and common infrastructure only.
class FinesApplication extends StatefulWidget {
  const FinesApplication({super.key, this.environment});
  final AppEnvironment? environment;
  @override
  State<FinesApplication> createState() => _FinesApplicationState();
}

class _FinesApplicationState extends State<FinesApplication> {
  late final AppEnvironment _environment;
  @override
  void initState() {
    super.initState();
    _environment = widget.environment ?? AppEnvironment.fromDefines();
  }

  @override
  void dispose() {
    if (widget.environment == null) _environment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _environment,
    builder: (context, _) => MaterialApp(
      title: 'Штрафы',
      debugShowCheckedModeBanner: false,
      theme: DsAppTheme.light(brand: DsBrand.fines),
      darkTheme: DsAppTheme.dark(brand: DsBrand.fines),
      themeMode: _environment.theme,
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations:
              MediaQuery.disableAnimationsOf(context) ||
              _environment.reduceMotion,
        ),
        child: child!,
      ),
      home: Builder(
        builder: (context) => FinesFeature(
          repository: ApiFinesRepository(_environment.api),
          checkout: _environment.checkout,
          accountId: 'main',
          actions: [
            DsIconButton(
              label: 'Среда демонстрации',
              icon: DsIcons.settings,
              onPressed: () => Navigator.of(context).push(
                dsRoute<void>(
                  builder: (context) =>
                      EnvironmentPage(environment: _environment),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
