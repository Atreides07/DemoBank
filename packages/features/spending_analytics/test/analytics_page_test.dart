import 'dart:async';

import 'package:app_localizations/app_localizations.dart';
import 'package:bank_core/bank_core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_analytics/spending_analytics.dart';

final _now = DateTime(2026, 10, 16);
final _ru = AppFormats('ru');
const _accounts = [
  Account(
    id: 'main',
    name: 'Основной счёт',
    balance: Money(500000),
    lastDigits: '4821',
    kind: 'debit',
  ),
  Account(
    id: 'savings',
    name: 'Накопительный счёт',
    balance: Money(1000000),
    lastDigits: '0924',
    kind: 'savings',
  ),
  Account(
    id: 'euro',
    name: 'Счёт в евро',
    balance: Money(250000, currency: 'EUR'),
    lastDigits: '8201',
    kind: 'debit',
  ),
];

void main() {
  testWidgets(
    'category, time and merchant clicks pass expense-only filters with the complete context',
    (tester) async {
      final source = LedgerFilter(
        from: DateTime.utc(2026, 9, 30, 21),
        to: DateTime.utc(2026, 10, 16, 21),
        currency: 'EUR',
        accounts: ['main', 'euro'],
      );
      const revision = 'server-revision-17';
      final base = _summary(source, revision: revision);
      final day = AggregatePoint(
        id: 'day-12',
        label: '12.10',
        amount: base.total,
        count: base.count,
        from: DateTime.utc(2026, 10, 11, 21),
        to: DateTime.utc(2026, 10, 12, 21),
      );
      final reader = _Reader(
        (_) async => SpendingSummary(
          total: base.total,
          refunds: base.refunds,
          previous: base.previous,
          count: base.count,
          revision: revision,
          categories: base.categories,
          merchants: base.merchants,
          timeline: [day],
          comparisonFrom: base.comparisonFrom,
          comparisonTo: base.comparisonTo,
        ),
      );
      final drills = <LedgerFilter>[];
      await _mount(tester, reader, initialFilter: source, onDrill: drills.add);
      // Deliberately start without a kind. The page must add the restriction,
      // rather than inherit it accidentally from ReportingPeriod.month().
      expect(reader.requests.single.kind, isNull);

      Future<void> click(String label) async {
        final finder = find.text(label);
        await tester.ensureVisible(finder);
        await tester.pump();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await click('1. Кафе и рестораны');
      expect(
        drills.single,
        source.copyWith(
          category: 'dining',
          kind: EntryKind.expense,
          revision: revision,
        ),
      );
      drills.clear();
      await click('12.10');
      expect(
        drills.single,
        source.copyWith(
          from: day.from,
          to: day.to,
          kind: EntryKind.expense,
          revision: revision,
        ),
      );
      drills.clear();
      await click('Кофейня');
      expect(
        drills.single,
        source.copyWith(
          merchant: 'cafe',
          kind: EntryKind.expense,
          revision: revision,
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'EUR selection reaches the reader and survives account and period changes',
    (tester) async {
      final reader = _Reader((filter) async => _summary(filter));
      await _mount(tester, reader);
      expect(reader.requests.single.currency, 'RUB');
      await _tapChoice(tester, 'EUR');
      expect(reader.requests.last.currency, 'EUR');
      expect(_choice(tester, 'EUR').selected, isTrue);
      expect(
        _metric(tester).value,
        _ru.money(const Money(15000, currency: 'EUR')),
      );

      await _tapChoice(tester, 'Счёт в евро');
      expect(reader.requests.last.accounts, ['euro']);
      await _tapChoice(tester, 'Прошлый месяц');
      final selected = reader.requests.last;
      expect(selected.currency, 'EUR');
      expect(selected.accounts, ['euro']);
      expect(selected.from, ReportingPeriod.month(_now, offset: -1).from);
      expect(selected.to, ReportingPeriod.month(_now, offset: -1).to);
      expect(_choice(tester, 'EUR').selected, isTrue);
      expect(_choice(tester, 'Счёт в евро').selected, isTrue);
      expect(_choice(tester, 'Прошлый месяц').selected, isTrue);
      expect(
        find.text('${_ru.period(selected.from!, selected.to!)} · EUR · Москва'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'financial readout separates money delta, zero comparison base, empty and zero expenses',
    (tester) async {
      final filter = ReportingPeriod.month(_now).copyWith(currency: 'EUR');
      await _mount(
        tester,
        _Reader(
          (query) async =>
              _summary(query, totalMinor: 15000, previousMinor: 10000),
        ),
        initialFilter: filter,
      );
      expect(
        _metric(tester).change,
        '${_ru.money(const Money(5000, currency: 'EUR'), signed: true)} · ${_ru.percent(50, signed: true)}',
      );
      expect(find.text(_metric(tester).change!), findsOneWidget);

      await _mount(
        tester,
        _Reader(
          (query) async => _summary(query, totalMinor: 15000, previousMinor: 0),
        ),
        initialFilter: filter,
      );
      expect(
        _metric(tester).change,
        '${_ru.money(const Money(15000, currency: 'EUR'), signed: true)} · нет базы для процента',
      );
      expect(_metric(tester).change, isNot(contains('%')));
      expect(_metric(tester).change, isNot(contains('Infinity')));

      await _mount(
        tester,
        _Reader(
          (query) async =>
              _summary(query, totalMinor: 0, previousMinor: 0, postedCount: 0),
        ),
        initialFilter: filter,
      );
      expect(find.text('Нет расходов в этом периоде'), findsOneWidget);
      expect(_metric(tester).value, _ru.money(const Money(0, currency: 'EUR')));
      expect(
        tester.widget<DsRankedBars>(find.byType(DsRankedBars)).points,
        isEmpty,
      );

      await _mount(
        tester,
        _Reader(
          (query) async =>
              _summary(query, totalMinor: 0, previousMinor: 0, postedCount: 2),
        ),
        initialFilter: filter,
      );
      expect(find.text('Нет расходов в этом периоде'), findsNothing);
      expect(_metric(tester).value, _ru.money(const Money(0, currency: 'EUR')));
      final categories = tester.widget<DsRankedBars>(find.byType(DsRankedBars));
      expect(categories.points.single.value, 0);
      expect(categories.points.single.detail, '${_ru.percent(0)} · 2 операции');
      expect(find.text('Полная выборка · 2 операции'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'payment refresh reloads the selected context and releases the refresh subscription',
    (tester) async {
      final signal = ValueNotifier<int>(0);
      addTearDown(signal.dispose);
      final reader = _Reader((filter) async => _summary(filter));
      await _mount(tester, reader, refreshSignal: signal);
      await _tapChoice(tester, 'EUR');
      await _tapChoice(tester, 'Счёт в евро');
      await _tapChoice(tester, 'Прошлый месяц');
      final selected = reader.requests.last;
      final previousValue = _metric(tester).value;
      final response = Completer<SpendingSummary>();
      reader.respond = (_) => response.future;
      final count = reader.requests.length;

      signal.value++;
      await tester.pump();
      await tester.pump();
      expect(reader.requests, hasLength(count + 1));
      expect(reader.requests.last, selected);
      expect(reader.requests.last.currency, 'EUR');
      expect(reader.requests.last.accounts, ['euro']);
      expect(_metric(tester).value, previousValue);
      expect(find.text('Обновляем выбранный период'), findsOneWidget);
      expect(
        find.text('Сейчас показан предыдущий согласованный результат.'),
        findsOneWidget,
      );

      response.complete(
        _summary(selected, totalMinor: 17500, revision: 'after-payment'),
      );
      await tester.pumpAndSettle();
      expect(
        _metric(tester).value,
        _ru.money(const Money(17500, currency: 'EUR')),
      );
      expect(_choice(tester, 'Прошлый месяц').selected, isTrue);
      expect(_choice(tester, 'Счёт в евро').selected, isTrue);
      expect(_choice(tester, 'EUR').selected, isTrue);
      expect(find.text('Обновляем выбранный период'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      signal.value++;
      await tester.pump();
      expect(reader.requests, hasLength(count + 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending filters retain coherent old charts and only the latest response becomes visible',
    (tester) async {
      final initial = ReportingPeriod.month(
        _now,
      ).copyWith(currency: 'EUR', accounts: ['euro']);
      final previous = ReportingPeriod.month(_now, offset: -1);
      final year = ReportingPeriod.year(_now);
      final older = Completer<SpendingSummary>();
      final newest = Completer<SpendingSummary>();
      final reader = _Reader((filter) {
        if (filter.from == previous.from) return older.future;
        if (filter.from == year.from) return newest.future;
        return Future.value(
          _summary(filter, totalMinor: 10000, revision: 'current'),
        );
      });
      await _mount(tester, reader, initialFilter: initial);
      await _tapChoice(tester, 'Прошлый месяц', settle: false);
      expect(reader.requests.last.from, previous.from);
      expect(
        _metric(tester).value,
        _ru.money(const Money(10000, currency: 'EUR')),
      );
      expect(
        find.text('${_ru.period(initial.from!, initial.to!)} · EUR · Москва'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Запрошено: ${_ru.period(previous.from!, previous.to!)}',
        ),
        findsOneWidget,
      );
      final oldCategories = tester.widget<DsRankedBars>(
        find.byType(DsRankedBars),
      );
      final oldTimeline = tester.widget<DsBarChart>(find.byType(DsBarChart));
      expect(oldCategories.points.single.value, 10000);
      expect(oldTimeline.points.single.value, 10000);
      expect(oldCategories.onSelected, isNull);
      expect(oldTimeline.onSelected, isNull);

      await _tapChoice(tester, 'Год', settle: false);
      final latestFilter = reader.requests.last;
      expect(latestFilter.from, year.from);
      expect(latestFilter.currency, 'EUR');
      expect(latestFilter.accounts, ['euro']);
      newest.complete(
        _summary(latestFilter, totalMinor: 30000, revision: 'latest'),
      );
      await tester.pumpAndSettle();
      expect(
        _metric(tester).value,
        _ru.money(const Money(30000, currency: 'EUR')),
      );
      expect(_choice(tester, 'Год').selected, isTrue);
      expect(
        tester
            .widget<DsRankedBars>(find.byType(DsRankedBars))
            .points
            .single
            .value,
        30000,
      );

      older.complete(
        _summary(
          initial.copyWith(from: previous.from, to: previous.to),
          totalMinor: 20000,
          revision: 'obsolete',
        ),
      );
      await tester.pumpAndSettle();
      expect(
        _metric(tester).value,
        _ru.money(const Money(30000, currency: 'EUR')),
      );
      expect(_choice(tester, 'Год').selected, isTrue);
      expect(_choice(tester, 'Прошлый месяц').selected, isFalse);
      expect(
        tester.widget<DsBarChart>(find.byType(DsBarChart)).points.single.value,
        30000,
      );
      expect(find.textContaining('Запрошено:'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _mount(
  WidgetTester tester,
  _Reader reader, {
  LedgerFilter? initialFilter,
  Listenable? refreshSignal,
  ValueChanged<LedgerFilter>? onDrill,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: DsAppTheme.light(),
      home: AnalyticsPage(
        reader: reader,
        now: () => _now,
        accounts: _accounts,
        initialFilter: initialFilter,
        refreshSignal: refreshSignal,
        onDrill: onDrill ?? (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapChoice(
  WidgetTester tester,
  String label, {
  bool settle = true,
}) async {
  final finder = find.byWidgetPredicate(
    (widget) => widget is DsChoice && widget.label == label,
  );
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
  if (settle) await tester.pumpAndSettle();
}

DsChoice _choice(WidgetTester tester, String label) => tester.widget<DsChoice>(
  find.byWidgetPredicate(
    (widget) => widget is DsChoice && widget.label == label,
  ),
);

DsMetric _metric(WidgetTester tester) => tester.widget<DsMetric>(
  find.byWidgetPredicate(
    (widget) => widget is DsMetric && widget.label == 'Расходы за период',
  ),
);

final class _Reader implements AnalyticsReader {
  _Reader(this.respond);
  Future<SpendingSummary> Function(LedgerFilter) respond;
  final List<LedgerFilter> requests = [];
  @override
  Future<SpendingSummary?> cached(LedgerFilter filter) async => null;
  @override
  Future<SpendingSummary> summary(LedgerFilter filter) {
    requests.add(filter);
    return respond(filter);
  }
}

SpendingSummary _summary(
  LedgerFilter filter, {
  int totalMinor = 15000,
  int previousMinor = 10000,
  int postedCount = 3,
  String revision = 'snapshot',
}) {
  final from = filter.from ?? DateTime.utc(2026, 9, 30, 21);
  final to = filter.to ?? DateTime.utc(2026, 10, 16, 21);
  final amount = Money(totalMinor, currency: filter.currency);
  List<AggregatePoint> points(String id, String label) => postedCount == 0
      ? []
      : [
          AggregatePoint(
            id: id,
            label: label,
            amount: amount,
            count: postedCount,
            from: from,
            to: to,
          ),
        ];
  return SpendingSummary(
    total: amount,
    refunds: Money(0, currency: filter.currency),
    previous: Money(previousMinor, currency: filter.currency),
    count: postedCount,
    revision: revision,
    categories: points('dining', 'Кафе'),
    merchants: points('cafe', 'Кофейня'),
    timeline: points('time-$revision', 'Период'),
    comparisonFrom: from.subtract(to.difference(from)),
    comparisonTo: from,
  );
}
