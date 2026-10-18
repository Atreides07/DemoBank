import 'package:accounts/accounts.dart';
import 'package:app_foundation/app_foundation.dart';
import 'package:app_localizations/app_localizations.dart';
import 'package:bank_core/bank_core.dart';
import 'package:bank_experience/bank_experience.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:transactions/transactions.dart';

void main() {
  testWidgets('opening home loads one page without building all history rows', (
    tester,
  ) async {
    final environment = AppEnvironment(
      cache: MemoryCacheStore(),
      journal: MemoryCacheStore(),
    );
    addTearDown(environment.dispose);
    await tester.pumpWidget(BankExperience(environment: environment));
    for (var tick = 0; tick < 40; tick++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final any = find.byType(HistorySliver, skipOffstage: false);
    expect(any, findsOneWidget);
    expect(
      find.byType(DsTransactionTile).hitTestable(),
      findsNothing,
      reason:
          'History is opened from the overview or reached after the reference feed',
    );
    expect(find.byType(DsTransactionTile).evaluate().length, lessThan(30));
    final history = tester.widget<HistorySliver>(any).cubit;
    expect(history.state.failed, isFalse);
    expect(history.state.rowCount, 30);
    expect(history.state.total, 12000);
    expect(history.state.pages.length, 1);
    expect(
      environment.apiEvents
          .where(
            (event) =>
                event.path == '/v1/transactions' &&
                event.phase.name == 'started',
          )
          .length,
      1,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'a pending update preserves the home surface without rebuilding the pinned home header',
    (tester) async {
      final environment = AppEnvironment(
        cache: MemoryCacheStore(),
        journal: MemoryCacheStore(),
      );
      addTearDown(environment.dispose);
      await tester.pumpWidget(BankExperience(environment: environment));
      final historyFinder = find.byType(HistorySliver, skipOffstage: false);
      final history = tester.widget<HistorySliver>(historyFinder).cubit;
      await _pumpUntil(tester, () => !history.state.loading);
      await tester.pumpAndSettle();

      final scrollFinder = find.byKey(
        const PageStorageKey('home'),
        skipOffstage: false,
      );
      final scrollSurface = tester.widget<CustomScrollView>(scrollFinder);
      final controller = scrollSurface.controller!;
      await _revealRows(tester, controller);
      expect(history.userIsReading, isTrue);
      final offset = controller.offset;
      final rowKey = tester
          .widget<DsTransactionTile>(
            find.byType(DsTransactionTile).hitTestable().first,
          )
          .key!;
      final rowFinder = find.byKey(rowKey);
      final rowTop = tester.getTopLeft(rowFinder).dy;
      final scrollableFinder = find.descendant(
        of: scrollFinder,
        matching: find.byType(Scrollable),
      );
      final scrollable = tester.state<ScrollableState>(scrollableFinder.first);
      final refreshFinder = find.ancestor(
        of: scrollFinder,
        matching: find.byType(RefreshIndicator, skipOffstage: false),
      );
      final refreshSurface = tester.widget<RefreshIndicator>(refreshFinder);
      final header = find
          .byType(DsHomeHeader, skipOffstage: false)
          .evaluate()
          .single;
      final accountBuilders = find
          .descendant(
            of: scrollFinder,
            matching: find.byType(
              BlocBuilder<AccountsCubit, AccountsState>,
              skipOffstage: false,
            ),
            skipOffstage: false,
          )
          .evaluate()
          .toSet();
      final protectedElements = {...accountBuilders, header};
      final rebuilt = <Element>[];
      final previousRebuildObserver = debugOnRebuildDirtyWidget;
      debugOnRebuildDirtyWidget = (element, builtOnce) {
        previousRebuildObserver?.call(element, builtOnce);
        if (protectedElements.contains(element)) {
          rebuilt.add(element);
        }
      };
      addTearDown(() => debugOnRebuildDirtyWidget = previousRebuildObserver);

      final original = history.state.pages[0]!.items.first;
      final initialRevision = history.state.revision;
      final insertedId = _insertBeforeFirst(environment, history);
      await _backgroundRefresh(tester, history);

      expect(history.state.pendingUpdate, isNotNull);
      expect(history.state.pendingUpdate!.revision, isNot(initialRevision));
      expect(history.state.revision, initialRevision);
      expect(history.state.at(0)!.id, original.id);
      expect(find.text('Показать обновления').hitTestable(), findsOneWidget);
      expect(
        find.text('Показать обновления', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('Есть новые операции · показать', skipOffstage: false),
        findsNothing,
      );
      expect(
        rebuilt,
        isEmpty,
        reason: 'An independent notice must not rebuild accounts or the header',
      );
      expect(
        tester.widget<RefreshIndicator>(refreshFinder),
        same(refreshSurface),
      );
      expect(
        tester.widget<CustomScrollView>(scrollFinder),
        same(scrollSurface),
      );
      expect(
        tester.widget<CustomScrollView>(scrollFinder).controller,
        same(controller),
      );
      expect(controller.offset, offset);
      expect(
        tester.state<ScrollableState>(scrollableFinder.first),
        same(scrollable),
      );
      expect(tester.getTopLeft(rowFinder).dy, closeTo(rowTop, 1));

      await tester.tap(find.text('Показать обновления'));
      await tester.pumpAndSettle();
      expect(history.state.pendingUpdate, isNull);
      expect(history.state.revision, isNot(initialRevision));
      expect(history.state.at(0)!.id, insertedId);
      expect(find.text('Показать обновления'), findsNothing);
      expect(rebuilt, isEmpty);
      expect(
        tester.widget<RefreshIndicator>(refreshFinder),
        same(refreshSurface),
      );
      expect(
        tester.widget<CustomScrollView>(scrollFinder),
        same(scrollSurface),
      );
      expect(
        tester.state<ScrollableState>(scrollableFinder.first),
        same(scrollable),
      );
      // Applying a new prefix may adjust raw offset to keep the reading row
      // visually anchored; a notice alone must leave the old offset untouched.
      expect(tester.getTopLeft(rowFinder).dy, closeTo(rowTop, 1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('history hosts retain their default inline update action', (
    tester,
  ) async {
    final environment = AppEnvironment(
      cache: MemoryCacheStore(),
      journal: MemoryCacheStore(),
    );
    addTearDown(environment.dispose);
    final history = HistoryCubit(
      ApiHistoryRepository(environment.api, environment.cache),
    );
    addTearDown(history.close);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DsAppTheme.light(),
        home: Scaffold(
          body: CustomScrollView(
            controller: controller,
            slivers: [
              HistorySliver(
                cubit: history,
                controller: controller,
                onEntry: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    final initial = history.load();
    await _pumpUntil(tester, () => !history.state.loading);
    await initial;
    history.userIsReading = true;
    _insertBeforeFirst(environment, history);
    await _backgroundRefresh(tester, history);

    expect(history.state.pendingUpdate, isNotNull);
    expect(
      find.text('Есть новые операции · показать', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      tester.widget<HistorySliver>(find.byType(HistorySliver)).showUpdateAction,
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('motion comparison updates mounted home without theme changes', (
    tester,
  ) async {
    final environment = AppEnvironment(
      cache: MemoryCacheStore(),
      journal: MemoryCacheStore(),
    );
    addTearDown(environment.dispose);
    await tester.pumpWidget(BankExperience(environment: environment));
    final finder = find.byType(HistorySliver, skipOffstage: false);
    final initial = tester.widget<HistorySliver>(finder);
    await _pumpUntil(tester, () => !initial.cubit.state.loading);
    await tester.pumpAndSettle();
    final theme = tester.widget<MaterialApp>(find.byType(MaterialApp)).theme;
    expect(initial.animate, isTrue);

    for (final comparison in [true, false]) {
      environment.setComparison(comparison);
      await tester.pump();
      final current = tester.widget<HistorySliver>(finder);
      expect(current.animate, !comparison);
      expect(current.cubit, same(initial.cubit));
      expect(current.controller, same(initial.controller));
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).theme,
        same(theme),
      );
    }
    final surfaceFinder = find.byKey(const PageStorageKey('home'));
    final surface = tester.widget<CustomScrollView>(surfaceFinder);
    environment.setReducedMotion(true);
    await tester.pump();
    expect(tester.widget<CustomScrollView>(surfaceFinder), same(surface));
    expect(tester.widget<HistorySliver>(finder).animate, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'an excluding home filter reveals history after the bank prefix',
    (tester) async {
      final environment = AppEnvironment(
        cache: MemoryCacheStore(),
        journal: MemoryCacheStore(),
      );
      addTearDown(environment.dispose);
      await tester.pumpWidget(BankExperience(environment: environment));
      final sliver = tester.widget<HistorySliver>(
        find.byType(HistorySliver, skipOffstage: false),
      );
      final history = sliver.cubit;
      await _pumpUntil(tester, () => !history.state.loading);
      await tester.pumpAndSettle();
      final controller = sliver.controller;
      await _revealRows(tester, controller);
      final anchor = history.readingAnchorId!;
      final oldEntry = history.state.pages.values
          .expand((page) => page.items)
          .singleWhere((entry) => entry.id == anchor);
      final category = spendingCategories.firstWhere(
        (id) => id != oldEntry.categoryId,
      );

      final loading = history.load(filter: LedgerFilter(category: category));
      await _pumpUntil(tester, () => !history.state.loading);
      await loading;
      await tester.pumpAndSettle();

      expect(history.state.failed, isFalse);
      expect(history.state.filter.category, category);
      expect(history.state.ids.values, isNot(contains(anchor)));
      // The full reference feed precedes history. A changed filter must reveal
      // the matching rows without forcing users to traverse that feed again.
      expect(find.text('История операций').hitTestable(), findsOneWidget);
      expect(
        find
            .byWidgetPredicate(
              (widget) =>
                  widget is DsChoice &&
                  widget.label ==
                      lookupAppLocalizations(
                        const Locale('ru'),
                      ).categoryName(category) &&
                  widget.selected,
            )
            .hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey(history.state.at(0)!.id)).hitTestable(),
        findsOneWidget,
      );
      final firstRow = tester.getRect(
        find.byKey(ValueKey(history.state.at(0)!.id)),
      );
      expect(firstRow.top, greaterThanOrEqualTo(0));
      expect(
        firstRow.bottom,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(DsNavigationBar)).dy),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
  testWidgets(
    'horizontal offers keep their own offset across vertical feed recycling',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 780);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final environment = AppEnvironment(
        cache: MemoryCacheStore(),
        journal: MemoryCacheStore(),
      );
      addTearDown(environment.dispose);
      await tester.pumpWidget(BankExperience(environment: environment));
      final history = tester
          .widget<HistorySliver>(
            find.byType(HistorySliver, skipOffstage: false),
          )
          .cubit;
      await _pumpUntil(tester, () => !history.state.loading);
      final home = tester
          .widget<CustomScrollView>(find.byKey(const PageStorageKey('home')))
          .controller!;
      final offers = find.byWidgetPredicate(
        (w) => w is DsRail && w.style == DsRailStyle.offers,
      );
      for (var n = 0; n < 40 && offers.hitTestable().evaluate().isEmpty; n++) {
        home.jumpTo(
          (home.offset + 400).clamp(0, home.position.maxScrollExtent),
        );
        await tester.pumpAndSettle();
      }
      expect(offers.hitTestable(), findsOneWidget);
      ScrollPosition offerPosition() => tester
          .state<ScrollableState>(
            find.descendant(of: offers, matching: find.byType(Scrollable)),
          )
          .position;
      expect(
        offerPosition().pixels,
        0,
        reason:
            'A new horizontal rail must not inherit the vertical home offset',
      );
      await tester.drag(offers, const Offset(-90, 0));
      await tester.pumpAndSettle();
      final horizontal = offerPosition().pixels;
      expect(horizontal, greaterThan(20));
      final vertical = home.offset;
      home.jumpTo(0);
      await tester.pumpAndSettle();
      expect(
        offers,
        findsNothing,
        reason: 'The rail must leave the lazy cache before testing restoration',
      );
      home.jumpTo(vertical);
      await tester.pumpAndSettle();
      expect(offerPosition().pixels, closeTo(horizontal, 1));
      expect(home.offset, closeTo(vertical, 1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() ready) async {
  for (var tick = 0; tick < 100 && !ready(); tick++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(ready(), isTrue, reason: 'The bounded fixture request must complete');
}

String _insertBeforeFirst(AppEnvironment environment, HistoryCubit history) {
  final first = history.state.pages[0]!.items.first;
  const id = 'txn-notice-regression';
  environment.simulation.transport.api.addTransaction({
    'id': id,
    'title': 'Новая операция при чтении',
    'subtitle': 'Новая операция',
    'amountMinor': first.amount.minor + 100,
    'currency': first.amount.currency,
    'occurredAt': first.occurredAt
        .add(const Duration(minutes: 1))
        .toIso8601String(),
    'categoryId': first.categoryId,
    'merchantId': first.merchantId,
    'accountId': first.accountId,
    'kind': 'expense',
    'status': 'posted',
  });
  return id;
}

Future<void> _backgroundRefresh(
  WidgetTester tester,
  HistoryCubit history,
) async {
  // Complete the network fixture on the virtual clock before rendering. This
  // isolates the notice from the separate inline-loading UI transition.
  final refresh = history.load(background: true);
  for (var tick = 0; tick < 100 && history.state.loading; tick++) {
    await tester.binding.delayed(const Duration(milliseconds: 100));
  }
  expect(history.state.loading, isFalse);
  await refresh;
  await tester.pumpAndSettle();
}

Future<void> _revealRows(
  WidgetTester tester,
  ScrollController controller,
) async {
  for (var n = 0; n < 40; n++) {
    if (find.byType(DsTransactionTile).hitTestable().evaluate().isNotEmpty) {
      return;
    }
    controller.jumpTo(
      (controller.offset + 500).clamp(0, controller.position.maxScrollExtent),
    );
    await tester.pumpAndSettle();
  }
  fail('History must be reachable after the reference feed');
}
