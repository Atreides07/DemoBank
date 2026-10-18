/// User-facing strings and locale-aware formatting shared by every screen.
///
/// Strings live in `lib/l10n/app_*.arb` (Russian is the template) and are
/// compiled by `flutter gen-l10n`. Domain packages never format for display;
/// screens use [AppFormats] from the current [BuildContext].
library;

export 'src/context.dart';
export 'src/failures.dart';
export 'src/formats.dart';
export 'src/generated/app_localizations.g.dart';
export 'src/labels.dart';
export 'src/language.dart';
