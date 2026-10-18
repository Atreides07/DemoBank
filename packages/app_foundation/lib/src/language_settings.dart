import 'dart:async';

import 'package:app_localizations/app_localizations.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/widgets.dart';

import '../app_foundation.dart';

/// Language choice shared by the bank and standalone hosts. Each language is
/// named in itself so it can be found from any current language.
class LanguageSection extends StatelessWidget {
  const LanguageSection({super.key, required this.environment});
  final AppEnvironment environment;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final chosen = environment.chosenLanguage;
    return DsSection(
      title: l10n.languageTitle,
      subtitle: l10n.languageSubtitle,
      child: DsFlow(
        children: [
          DsChoice(
            label: l10n.languageSystem(environment.systemLanguage.nativeName),
            selected: chosen == null,
            onSelected: (_) => unawaited(environment.setLanguage(null)),
          ),
          for (final language in AppLanguage.values)
            DsChoice(
              label: language.nativeName,
              selected: chosen == language,
              onSelected: (_) => unawaited(environment.setLanguage(language)),
            ),
        ],
      ),
    );
  }
}

class LanguageSettingsPage extends StatelessWidget {
  const LanguageSettingsPage({super.key, required this.environment});
  final AppEnvironment environment;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: environment,
    builder: (context, _) => DsPage(
      title: context.l10n.languageTitle,
      children: [LanguageSection(environment: environment)],
    ),
  );
}
