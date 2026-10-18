import 'package:bank_core/bank_core.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Locale-aware presentation of money, numbers and reporting dates.
///
/// Amounts are formatted from exact minor units, never through a double, so a
/// grouping or rounding rule can never change a kopeck. Reporting instants are
/// shown in the bank's reporting time zone (Moscow, UTC+3); calendar dates
/// without a time zone are shown as they are.
final class AppFormats {
  factory AppFormats(String languageCode) =>
      _cache.putIfAbsent(languageCode, () => AppFormats._(languageCode));

  AppFormats._(this.languageCode)
    : _integer = NumberFormat.decimalPattern(languageCode),
      _decimalSeparator = NumberFormat.decimalPattern(
        languageCode,
      ).symbols.DECIMAL_SEP;

  static final Map<String, AppFormats> _cache = {};

  static AppFormats of(BuildContext context) =>
      AppFormats(Localizations.localeOf(context).languageCode);

  /// The bank reports days by Moscow time.
  static const reportingOffset = Duration(hours: 3);

  /// Typographic minus; a hyphen is not a sign in financial figures.
  static const minus = '−';

  final String languageCode;
  final NumberFormat _integer;
  final String _decimalSeparator;

  /// `1 234,56 ₽` (ru), `₽1,234.56` (en), `1 234,56 ₽` (uz). Whole amounts
  /// omit the fraction: `1 250 000 сум`.
  String money(Money value, {bool signed = false}) {
    final minor = value.minor.abs();
    final whole = _integer.format(minor ~/ 100);
    final fraction = minor % 100;
    final number = fraction == 0
        ? whole
        : '$whole$_decimalSeparator${fraction.toString().padLeft(2, '0')}';
    return '${_sign(value.minor, signed)}${_withCurrency(number, value.currency)}';
  }

  /// Amount of a ledger entry with the sign a customer expects: expenses are
  /// negative, income and refunds positive.
  String entryAmount(LedgerEntry entry) {
    if (entry.amount.minor < 0) return money(entry.amount);
    final text = money(entry.amount);
    return entry.kind == EntryKind.expense ? '$minus$text' : '+$text';
  }

  String currencySymbol(String currency) => switch ((currency, languageCode)) {
    ('RUB', _) => '₽',
    ('USD', _) => r'$',
    ('GBP', _) => '£',
    ('EUR', _) => '€',
    ('UZS', 'ru') => 'сум',
    ('UZS', 'uz') => 'soʻm',
    _ => currency,
  };

  String _withCurrency(String number, String currency) {
    final symbol = currencySymbol(currency);
    if (languageCode == 'en') {
      return symbol.length == 1 ? '$symbol$number' : '$symbol $number';
    }
    return '$number $symbol';
  }

  /// [value] is in percent: `12.4` → `+12,4 %` (ru) or `+12.4%` (en).
  String percent(num value, {int fractionDigits = 1, bool signed = false}) {
    final format = NumberFormat.decimalPercentPattern(
      locale: languageCode,
      decimalDigits: fractionDigits,
    );
    return '${_sign(value, signed)}${format.format(value.abs() / 100)}';
  }

  String number(int value) => _integer.format(value);

  /// Select key of a month for messages such as `spentInMonth`.
  static String monthKey(int month) => const [
    'january',
    'february',
    'march',
    'april',
    'may',
    'june',
    'july',
    'august',
    'september',
    'october',
    'november',
    'december',
  ][(month - 1) % 12];

  /// Short value for chart scales: `1,2 млн`, `1.2M`, `1,2 mln`.
  String compact(num value) =>
      NumberFormat.compact(locale: languageCode).format(value);

  String _sign(num value, bool signed) => value < 0
      ? minus
      : signed && value > 0
      ? '+'
      : '';

  /// Instants are converted to the reporting time zone; a local value (a
  /// calendar date picked or received without a zone) is shown unchanged.
  DateTime reporting(DateTime value) =>
      value.isUtc ? value.add(reportingOffset) : value;

  /// `16.10.2026` (ru), `10/16/2026` (en), `16/10/2026` (uz).
  String date(DateTime value) =>
      DateFormat.yMd(languageCode).format(reporting(value));

  /// `14:59` (ru, uz), `2:59 PM` (en).
  String time(DateTime value) =>
      DateFormat.jm(languageCode).format(reporting(value));

  /// Short day for chart axes: `16.10`, `10/16`.
  String dayMonth(DateTime value) =>
      DateFormat.Md(languageCode).format(reporting(value));

  /// Day and month name: `22 октября`, `October 22`, `22-oktabr`.
  String dayMonthLong(DateTime value) =>
      DateFormat.MMMMd(languageCode).format(reporting(value));

  /// Short month for chart axes: `10.2026`, `10/2026`.
  String monthYear(DateTime value) =>
      DateFormat.yM(languageCode).format(reporting(value));

  /// Inclusive date range of a half-open reporting interval.
  String period(DateTime from, DateTime toExclusive) =>
      '${date(from)} — ${date(toExclusive.subtract(const Duration(days: 1)))}';

  /// Parses an amount typed by a person into exact minor units, or `null`.
  ///
  /// Spaces are grouping. In English a comma is grouping and a point the
  /// decimal separator; in Russian and Uzbek either a comma or a point is
  /// accepted as the decimal separator. At most two fractional digits.
  int? parseAmount(String input, {int maxIntegerDigits = 9}) {
    var text = input.trim().replaceAll(RegExp(r'[\s  ]'), '');
    text = languageCode == 'en'
        ? text.replaceAll(',', '')
        : text.replaceAll(',', '.');
    final match = RegExp(
      '^(\\d{1,$maxIntegerDigits})(?:\\.(\\d{1,2}))?\$',
    ).firstMatch(text);
    if (match == null) return null;
    return int.parse(match[1]!) * 100 +
        int.parse((match[2] ?? '0').padRight(2, '0'));
  }

  /// An amount as a person would type it back into a field: no currency and
  /// no grouping, the locale's decimal separator, `500` or `500,5`.
  String amountInput(int minor) {
    final whole = minor ~/ 100;
    final fraction = minor % 100;
    if (fraction == 0) return '$whole';
    final digits = fraction % 10 == 0
        ? '${fraction ~/ 10}'
        : fraction.toString().padLeft(2, '0');
    return '$whole$_decimalSeparator$digits';
  }
}
