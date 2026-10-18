import 'package:flutter/widgets.dart';

import 'formats.dart';
import 'generated/app_localizations.g.dart';

extension AppLocalizationsContext on BuildContext {
  /// Strings for the current locale. Requires [AppLocalizations.delegate].
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// Money, number and date formatting for the current locale.
  AppFormats get formats => AppFormats.of(this);
}
