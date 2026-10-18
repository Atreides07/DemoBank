import 'package:app_foundation/app_foundation.dart';
import 'package:app_localizations/app_localizations.dart';
import 'package:design_system/design_system.dart';
import 'package:fines/fines.dart';
import 'package:flutter/material.dart';

/// Separate host: the fines contract and common infrastructure only.
class FinesApplication extends StatefulWidget {
  const FinesApplication({super.key, this.environment});
  final AppEnvironment? environment;
  @override
  State<FinesApplication> createState() => _FinesApplicationState();
}

class _FinesApplicationState extends State<FinesApplication>
    with WidgetsBindingObserver {
  late final AppEnvironment _environment;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _environment = widget.environment ?? AppEnvironment.fromDefines();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (locales != null) _environment.updateSystemLocales(locales);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.environment == null) _environment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _environment,
    builder: (context, _) => MaterialApp(
      onGenerateTitle: (context) => context.l10n.servicesFines,
      debugShowCheckedModeBanner: false,
      theme: DsAppTheme.light(brand: DsBrand.fines),
      darkTheme: DsAppTheme.dark(brand: DsBrand.fines),
      themeMode: _environment.theme,
      locale: _environment.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        DsLocalizations.delegate,
      ],
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
              label: context.l10n.envTitle,
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
