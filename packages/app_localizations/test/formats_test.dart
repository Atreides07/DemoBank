import 'package:app_localizations/app_localizations.dart';
import 'package:bank_core/bank_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const _nbsp = ' ';

void main() {
  setUpAll(() async {
    for (final language in AppLanguage.values) {
      await initializeDateFormatting(language.code);
    }
  });

  final ru = AppFormats('ru');
  final en = AppFormats('en');
  final uz = AppFormats('uz');

  group('money', () {
    test('keeps every kopeck and follows the language', () {
      expect(ru.money(const Money(123456789)), '1${_nbsp}234${_nbsp}567,89 ₽');
      expect(en.money(const Money(123456789)), '₽1,234,567.89');
      expect(uz.money(const Money(123456789)), '1${_nbsp}234${_nbsp}567,89 ₽');
      expect(ru.money(const Money(1000)), '10 ₽');
      expect(en.money(const Money(1)), '₽0.01');
    });

    test('names the sum in each language', () {
      const sum = Money(1275000000, currency: 'UZS');
      expect(ru.money(sum), '12${_nbsp}750${_nbsp}000 сум');
      expect(uz.money(sum), '12${_nbsp}750${_nbsp}000 soʻm');
      expect(en.money(sum), 'UZS 12,750,000');
    });

    test('uses a typographic minus and an explicit plus on request', () {
      expect(ru.money(const Money(-5000)), '${AppFormats.minus}50 ₽');
      expect(en.money(const Money(5000), signed: true), '+₽50');
      expect(en.money(const Money(0), signed: true), '₽0');
    });

    test('signs ledger entries the way a customer reads them', () {
      LedgerEntry entry(EntryKind kind, int minor) => LedgerEntry(
        id: 'id',
        title: 'title',
        subtitle: 'subtitle',
        amount: Money(minor),
        occurredAt: DateTime.utc(2026, 10, 16, 12),
        categoryId: 'other',
        merchantId: 'merchant',
        accountId: 'main',
        kind: kind,
        status: EntryStatus.posted,
      );
      expect(en.entryAmount(entry(EntryKind.expense, 1000)), '−₽10');
      expect(en.entryAmount(entry(EntryKind.refund, 1000)), '+₽10');
      expect(ru.entryAmount(entry(EntryKind.transfer, -1000)), '−10 ₽');
    });
  });

  test('percentages follow the language', () {
    expect(ru.percent(12.4), '12,4$_nbsp%');
    expect(en.percent(12.4, signed: true), '+12.4%');
    expect(uz.percent(-3), '${AppFormats.minus}3,0%');
    expect(en.percent(30, fractionDigits: 0), '30%');
  });

  test('reporting instants are shown in Moscow time', () {
    final instant = DateTime.utc(2026, 10, 16, 21, 30);
    expect(ru.date(instant), '17.10.2026');
    expect(en.date(instant), '10/17/2026');
    expect(uz.date(instant), contains('2026'));
    expect(ru.time(instant), '00:30');
    expect(en.time(instant), contains('AM'));
    expect(ru.dayMonth(instant), '17.10');
    expect(en.dayMonth(instant), '10/17');
    expect(ru.dayMonthLong(DateTime(2026, 10, 22)), '22 октября');
    expect(en.dayMonthLong(DateTime(2026, 10, 22)), 'October 22');
    expect(uz.dayMonthLong(DateTime(2026, 10, 22)), contains('22'));
    expect(
      ru.period(DateTime.utc(2026, 9, 30, 21), DateTime.utc(2026, 10, 16, 21)),
      '01.10.2026 — 16.10.2026',
    );
  });

  group('typed amounts', () {
    test('are parsed exactly in each language', () {
      expect(ru.parseAmount('1 234,05'), 123405);
      expect(ru.parseAmount('1${_nbsp}234.5'), 123450);
      expect(uz.parseAmount('15000'), 1500000);
      expect(en.parseAmount('1,234.05'), 123405);
      expect(en.parseAmount('0.01'), 1);
    });

    test('reject what is not an amount', () {
      for (final value in ['1.001', '-3', 'NaN', '1e3', '', '1,2,3', '.5']) {
        expect(ru.parseAmount(value), isNull, reason: value);
      }
      expect(ru.parseAmount('1234567', maxIntegerDigits: 6), isNull);
    });

    test('are written back with the language separator', () {
      expect(ru.amountInput(50000), '500');
      expect(ru.amountInput(15550), '155,5');
      expect(en.amountInput(15555), '155.55');
      expect(uz.amountInput(5), '0,05');
    });
  });

  test('month keys match the catalogue select cases', () {
    expect(AppFormats.monthKey(1), 'january');
    expect(AppFormats.monthKey(12), 'december');
  });
}
