import 'dart:convert';
import 'dart:io';

import 'package:app_localizations/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payment_domain/payment_domain.dart';

Map<String, dynamic> _arb(String language) =>
    jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync())
        as Map<String, dynamic>;

Iterable<String> _messages(Map<String, dynamic> arb) =>
    arb.keys.where((key) => !key.startsWith('@'));

/// Placeholders declared in the template that [message] uses, as `{name}`
/// or as the selector of a plural or select.
Set<String> _used(Map<String, dynamic> template, String key, String message) {
  final meta = template['@$key'] as Map<String, dynamic>?;
  final declared = (meta?['placeholders'] as Map<String, dynamic>? ?? {}).keys;
  return {
    for (final name in declared)
      if (message.contains('{$name}') || message.contains('{$name,')) name,
  };
}

final _cyrillic = RegExp('[Ѐ-ӿ]');

void main() {
  final ru = _arb('ru');
  final en = _arb('en');
  final uz = _arb('uz');

  test('every language has every message with the same placeholders', () {
    for (final other in [en, uz]) {
      expect(_messages(other).toSet(), _messages(ru).toSet());
      for (final key in _messages(ru)) {
        expect(
          _used(ru, key, other[key] as String),
          _used(ru, key, ru[key] as String),
          reason: '${other['@@locale']}: $key',
        );
      }
    }
  });

  test('English and Uzbek are written in Latin script', () {
    for (final arb in [en, uz]) {
      for (final key in _messages(arb)) {
        expect(
          _cyrillic.hasMatch(arb[key] as String),
          isFalse,
          reason: '${arb['@@locale']}: $key',
        );
      }
    }
  });

  test('Uzbek uses the official oʻ, gʻ and tutuq belgisi letters', () {
    for (final key in _messages(uz)) {
      final message = uz[key] as String;
      expect(
        RegExp("[oOgG]['‘’`]").hasMatch(message),
        isFalse,
        reason: '$key: use U+02BB, as in oʻ and gʻ',
      );
      expect(
        RegExp("[a-z]['’`][a-z]").hasMatch(message),
        isFalse,
        reason: '$key: use U+02BC for the tutuq belgisi',
      );
    }
  });

  test('every supported language loads, and others fall back to Russian', () {
    for (final language in AppLanguage.values) {
      expect(AppLocalizations.supportedLocales, contains(language.locale));
      expect(lookupAppLocalizations(language.locale).localeName, language.code);
    }
    expect(AppLanguage.resolve(const [Locale('de')]), AppLanguage.ru);
    expect(
      AppLanguage.resolve(const [Locale('de'), Locale('uz', 'UZ')]),
      AppLanguage.uz,
    );
  });

  test('plural forms agree with each language', () {
    final ru = lookupAppLocalizations(const Locale('ru'));
    final en = lookupAppLocalizations(const Locale('en'));
    final uz = lookupAppLocalizations(const Locale('uz'));
    expect(ru.commonOperationsCount(1), '1 операция');
    expect(ru.commonOperationsCount(3), '3 операции');
    expect(ru.commonOperationsCount(25), '25 операций');
    expect(ru.commonOperationsCount(1200), '1 200 операций');
    expect(en.commonOperationsCount(1), '1 transaction');
    expect(en.commonOperationsCount(1200), '1,200 transactions');
    expect(uz.commonOperationsCount(2), '2 ta operatsiya');
  });

  test('server-independent labels cover the whole category taxonomy', () {
    for (final language in AppLanguage.values) {
      final l10n = lookupAppLocalizations(language.locale);
      final names = spendingCategories.map(l10n.categoryName).toSet();
      expect(names, hasLength(spendingCategories.length));
      expect(l10n.category('unknown-id', 'Server name'), 'Server name');
      expect(
        l10n.category('dining', 'Server name'),
        l10n.categoryName('dining'),
      );
    }
  });

  test('failures are described without exposing codes', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(
      en.paymentFailure(const PaymentFailure(PaymentFailureCode.quoteExpired)),
      en.paymentErrorQuoteExpired,
    );
    expect(
      en.paymentFailure(
        const PaymentFailure(PaymentFailureCode.declined, 'Server reason'),
      ),
      'Server reason',
    );
  });
}
