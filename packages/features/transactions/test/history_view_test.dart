import 'dart:async';

import 'package:app_localizations/app_localizations.dart';
import 'package:bank_core/bank_core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transactions/transactions.dart';

void main() {
  testWidgets(
    'an applied filter excluding the reading anchor starts at the top',
    (tester) async {
      final view = await _mountDeepHistory(tester);
      final previousAnchor = view.cubit.readingAnchorId!;

      await view.cubit.load(filter: LedgerFilter(merchant: 'other'));
      await tester.pumpAndSettle();

      expect(view.cubit.state.filter.merchant, 'other');
      expect(view.cubit.state.ids.values, isNot(contains(previousAnchor)));
      expect(view.controller.offset, view.controller.position.minScrollExtent);
      expect(
        find.byKey(const ValueKey('other-0')).hitTestable(),
        findsOneWidget,
        reason:
            'Clamping to the bottom of a shorter result is not its beginning',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'an applied filter retaining the anchor preserves reading position',
    (tester) async {
      final view = await _mountDeepHistory(tester);
      final anchor = view.cubit.readingAnchorId!;
      final row = find.byKey(ValueKey(anchor));
      final before = tester.getTopLeft(row).dy;
      final offset = view.controller.offset;

      await view.cubit.load(filter: LedgerFilter(merchant: 'market'));
      await tester.pumpAndSettle();

      expect(view.cubit.state.filter.merchant, 'market');
      expect(view.cubit.state.ids.values, contains(anchor));
      expect(view.controller.offset, closeTo(offset, 1));
      expect(tester.getTopLeft(row).dy, closeTo(before, 1));
      expect(view.controller.offset, greaterThan(0));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'pending and failed filters do not reset the applied reading view',
    (tester) async {
      final view = await _mountDeepHistory(tester);
      final oldFilter = view.cubit.state.filter;
      final oldAnchor = view.cubit.readingAnchorId!;
      final response = Completer<LedgerPage>();
      view.reader.otherResponse = response;
      final request = view.cubit.load(filter: LedgerFilter(merchant: 'other'));
      await tester.pump();

      expect(view.cubit.state.pendingFilter?.merchant, 'other');
      expect(view.cubit.state.filter, oldFilter);
      expect(view.controller.offset, greaterThan(0));
      response.completeError(StateError('fixture offline'));
      await request;
      await tester.pumpAndSettle();

      expect(view.cubit.state.failed, isTrue);
      expect(view.cubit.state.filter, oldFilter);
      expect(view.cubit.state.ids.values, contains(oldAnchor));
      expect(view.controller.offset, greaterThan(0));
      expect(find.byKey(ValueKey(oldAnchor)), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'category choices retain the applied selection while pending or failed',
    (tester) async {
      final view = _HistoryView();
      addTearDown(view.close);
      await view.cubit.load();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: DsAppTheme.light(),
          home: Scaffold(
            body: CustomScrollView(
              controller: view.controller,
              slivers: [
                HistorySliver(
                  cubit: view.cubit,
                  controller: view.controller,
                  onEntry: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      bool selected(String label) =>
          tester.widget<DsChoice>(_choice(label)).selected;

      expect(selected('Все'), isTrue);
      expect(selected('Продукты'), isFalse);
      expect(selected('Транспорт'), isFalse);

      final groceries = Completer<LedgerPage>();
      view.reader.categoryResponses['groceries'] = groceries;
      await tester.tap(_choice('Продукты'));
      await tester.pump();

      expect(view.cubit.state.pendingFilter?.category, 'groceries');
      expect(selected('Все'), isTrue);
      expect(selected('Продукты'), isFalse);
      groceries.complete(
        view.reader._page(LedgerFilter(category: 'groceries'), 0, 30),
      );
      await tester.pumpAndSettle();

      expect(view.cubit.state.pendingFilter, isNull);
      expect(view.cubit.state.filter.category, 'groceries');
      expect(selected('Продукты'), isTrue);
      expect(selected('Все'), isFalse);

      final transport = Completer<LedgerPage>();
      view.reader.categoryResponses['transport'] = transport;
      await tester.tap(_choice('Транспорт'));
      await tester.pump();

      expect(view.cubit.state.pendingFilter?.category, 'transport');
      expect(selected('Продукты'), isTrue);
      expect(selected('Транспорт'), isFalse);
      transport.completeError(StateError('fixture offline'));
      await tester.pumpAndSettle();

      expect(view.cubit.state.pendingFilter, isNull);
      expect(view.cubit.state.filter.category, 'groceries');
      expect(selected('Продукты'), isTrue);
      expect(selected('Все'), isFalse);
      expect(selected('Транспорт'), isFalse);
      expect(
        find
            .text('Не удалось загрузить операции. Повторите запрос.')
            .hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'retained rows update their day, status, value and visual details',
    (tester) async {
      final view = _HistoryView();
      addTearDown(view.close);
      var revision = 0;
      var entry = _rowEntry();
      view.reader.firstPage = _entryPage(entry, revision: '${revision++}');
      await view.cubit.load();
      await tester.pumpWidget(_rowApp(view, onEntry: (_) {}));
      await tester.pumpAndSettle();

      final row = find.byKey(ValueKey(entry.id));
      DsTransactionTile tile() => tester.widget<DsTransactionTile>(row);
      Future<void> apply(LedgerEntry next) async {
        view.reader.firstPage = _entryPage(next, revision: '${revision++}');
        view.cubit.userIsReading = true;
        await view.cubit.load(background: true);
        await tester.pumpAndSettle();
        expect(view.cubit.state.pendingUpdate, isNotNull);
        view.cubit.applyUpdate();
        await tester.pumpAndSettle();
        entry = next;
        expect(find.byKey(ValueKey(entry.id)), findsOneWidget);
      }

      expect(find.text('16.10.2026'), findsOneWidget);
      expect(tile().changed, isFalse);
      // A day change alone must invalidate the cached day header.
      await apply(_rowEntry(day: 17));
      expect(find.text('16.10.2026'), findsNothing);
      expect(find.text('17.10.2026'), findsOneWidget);
      expect(tile().changed, isFalse);

      await apply(_rowEntry(day: 17, status: EntryStatus.posted));
      expect(tile().subtitle, contains('Проведено'));
      expect(tile().changed, isTrue);
      // Both revisions carry the changed mark, so status is the visual delta.
      await apply(_rowEntry(day: 17, status: EntryStatus.cancelled));
      expect(tile().subtitle, contains('Отменено'));
      expect(tile().changed, isTrue);

      await apply(
        _rowEntry(
          day: 17,
          status: EntryStatus.cancelled,
          amount: const Money(65432, currency: 'EUR'),
        ),
      );
      expect(tile().value, '−654,32\u00a0€');
      expect(find.text('−654,32\u00a0€'), findsOneWidget);
      expect(tile().positive, isFalse);
      await apply(
        _rowEntry(
          day: 17,
          status: EntryStatus.cancelled,
          amount: const Money(65432, currency: 'EUR'),
          kind: EntryKind.refund,
        ),
      );
      expect(tile().value, '+654,32\u00a0€');
      expect(tile().positive, isTrue);

      await apply(
        _rowEntry(
          day: 17,
          status: EntryStatus.cancelled,
          amount: const Money(65432, currency: 'EUR'),
          kind: EntryKind.refund,
          title: 'Возврат за поездку',
          category: 'transport',
        ),
      );
      expect(tile().title, 'Возврат за поездку');
      expect(tile().subtitle, contains('Транспорт'));
      expect(tile().icon, DsIcons.transport);
      expect(tile().changed, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'equivalent rows use the latest entry and callback and inherited styling',
    (tester) async {
      final view = _HistoryView();
      addTearDown(view.close);
      final original = _rowEntry(category: 'groceries');
      final oldActions = <LedgerEntry>[];
      final latestActions = <LedgerEntry>[];
      view.reader.firstPage = _entryPage(original, revision: 'first');
      await view.cubit.load();
      await tester.pumpWidget(_rowApp(view, onEntry: oldActions.add));
      await tester.pumpAndSettle();

      final row = find.byKey(ValueKey(original.id));
      final title = find.descendant(
        of: row,
        matching: find.text(original.title),
      );
      final initialColor = tester.widget<Text>(title).style!.color;
      final initialHeight = tester.getSize(row).height;
      expect(
        find.descendant(of: row, matching: find.byType(DsIconBadge)),
        findsOneWidget,
      );
      await tester.tap(row);
      expect(oldActions, [same(original)]);

      final latest = _rowEntry(
        category: 'groceries',
        account: 'savings',
        merchant: 'new-merchant',
        subtitle: 'Новые сведения для деталей',
      );
      view.reader.firstPage = _entryPage(latest, revision: 'second');
      await view.cubit.load(background: true);
      await tester.pumpWidget(_rowApp(view, onEntry: latestActions.add));
      await tester.pumpAndSettle();

      await tester.tap(row);
      expect(oldActions, [same(original)]);
      expect(latestActions, [same(latest)]);
      expect(latestActions.single.accountId, 'savings');

      await tester.pumpWidget(
        _rowApp(
          view,
          onEntry: latestActions.add,
          theme: DsAppTheme.dark(),
          textScale: 2,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<Text>(title).style!.color, isNot(initialColor));
      expect(tester.getSize(row).height, greaterThan(initialHeight));
      expect(
        find.descendant(of: row, matching: find.byType(DsIconBadge)),
        findsNothing,
      );
      await tester.tap(row);
      expect(latestActions, [same(latest), same(latest)]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}

Widget _rowApp(
  _HistoryView view, {
  required ValueChanged<LedgerEntry> onEntry,
  ThemeData? theme,
  double textScale = 1,
}) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: theme ?? DsAppTheme.light(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(
    body: CustomScrollView(
      controller: view.controller,
      slivers: [
        HistorySliver(
          cubit: view.cubit,
          controller: view.controller,
          onEntry: onEntry,
          showFilters: false,
        ),
      ],
    ),
  ),
);

LedgerEntry _rowEntry({
  String title = 'Покупка',
  String subtitle = 'Сведения об операции',
  String category = 'unmapped-category',
  Money amount = const Money(12345),
  int day = 16,
  EntryKind kind = EntryKind.expense,
  EntryStatus status = EntryStatus.pending,
  String account = 'main',
  String merchant = 'market',
}) => LedgerEntry(
  id: 'retained-row',
  title: title,
  subtitle: subtitle,
  categoryId: category,
  amount: amount,
  occurredAt: DateTime.utc(2026, 10, day, 6),
  accountId: account,
  merchantId: merchant,
  kind: kind,
  status: status,
);

LedgerPage _entryPage(LedgerEntry entry, {required String revision}) =>
    LedgerPage(
      items: [entry],
      total: 1,
      totalAmount: entry.amount,
      revision: revision,
      startCursor: '0',
    );

Future<_HistoryView> _mountDeepHistory(WidgetTester tester) async {
  final view = _HistoryView();
  addTearDown(view.close);
  await view.cubit.load();
  for (var page = 1; page < 4; page++) {
    await view.cubit.loadNext();
  }
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: DsAppTheme.light(),
      home: Scaffold(
        body: CustomScrollView(
          controller: view.controller,
          slivers: [
            HistorySliver(
              cubit: view.cubit,
              controller: view.controller,
              onEntry: (_) {},
              showFilters: false,
            ),
          ],
        ),
      ),
    ),
  );
  view.controller.jumpTo(5000);
  await tester.pumpAndSettle();
  expect(view.cubit.readingAnchorId, isNotNull);
  expect(view.controller.offset, greaterThan(3000));
  return view;
}

final class _HistoryView {
  _HistoryView() {
    cubit = HistoryCubit(reader);
  }
  final reader = _Reader();
  final controller = ScrollController();
  late final HistoryCubit cubit;

  Future<void> close() async {
    controller.dispose();
    await cubit.close();
  }
}

final class _Reader implements HistoryReader {
  Completer<LedgerPage>? otherResponse;
  LedgerPage? firstPage;
  final categoryResponses = <String, Completer<LedgerPage>>{};

  @override
  Future<LedgerPage?> cached(LedgerFilter filter, {String? cursor}) async =>
      null;

  @override
  Future<LedgerPage> page(
    LedgerFilter filter, {
    String? cursor,
    int limit = 30,
    int? startIndex,
  }) async {
    if (filter.merchant == 'other' && cursor == null && startIndex == null) {
      if (otherResponse case final response?) return response.future;
    }
    if (cursor == null && startIndex == null) {
      if (categoryResponses[filter.category] case final response?) {
        return response.future;
      }
      if (firstPage case final page?) return page;
    }
    final start = startIndex ?? (cursor == null ? 0 : int.parse(cursor));
    return _page(filter, start, limit);
  }

  @override
  Future<LedgerPage> around(
    LedgerFilter filter,
    String anchorId, {
    int fallbackIndex = 0,
  }) async {
    final included = anchorId.startsWith(
      filter.merchant == 'other' ? 'other-' : 'txn-',
    );
    final index = included
        ? int.parse(anchorId.split('-').last)
        : fallbackIndex;
    return _page(filter, (index ~/ 30) * 30, 30);
  }

  LedgerPage _page(LedgerFilter filter, int start, int limit) {
    final other = filter.merchant == 'other';
    final total = other ? 30 : 240;
    final end = (start + limit).clamp(0, total);
    return LedgerPage(
      items: [
        for (var index = start; index < end; index++)
          LedgerEntry(
            id: '${other ? 'other' : 'txn'}-$index',
            title: '${other ? 'Новая выборка' : 'Операция'} $index',
            subtitle: 'Проведено',
            amount: const Money(10000),
            occurredAt: DateTime.utc(
              2026,
              10,
              16,
            ).subtract(Duration(minutes: index)),
            categoryId: filter.category ?? 'groceries',
            merchantId: other ? 'other' : 'market',
            accountId: 'main',
            kind: EntryKind.expense,
            status: EntryStatus.posted,
          ),
      ],
      total: total,
      totalAmount: Money(total * 10000),
      revision: 'fixture-1',
      startIndex: start,
      startCursor: '$start',
      prevCursor: start == 0 ? null : '${start - limit}',
      nextCursor: end == total ? null : '$end',
    );
  }
}

Finder _choice(String label) => find.byWidgetPredicate(
  (widget) => widget is DsChoice && widget.label == label,
);
