import 'dart:ui';

/// Languages the application ships with. The first is the fallback when the
/// device prefers a language the application does not support.
enum AppLanguage {
  ru('Русский'),
  en('English'),
  uz('Oʻzbekcha');

  const AppLanguage(this.nativeName);

  /// Shown in the language picker in the language itself, so a person can
  /// find their language whatever the current interface language is.
  final String nativeName;

  String get code => name;

  Locale get locale => Locale(code);

  static AppLanguage? tryParse(String? code) {
    for (final language in values) {
      if (language.code == code) return language;
    }
    return null;
  }

  /// The first supported language among the device preferences, in order.
  static AppLanguage resolve(Iterable<Locale> preferred) {
    for (final locale in preferred) {
      final language = tryParse(locale.languageCode);
      if (language != null) return language;
    }
    return AppLanguage.ru;
  }
}
