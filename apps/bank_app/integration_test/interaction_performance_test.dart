import 'dart:async';
import 'package:accounts/accounts.dart';
import 'dart:io';
import 'dart:ui';

import 'package:app_foundation/app_foundation.dart';
import 'package:app_localizations/app_localizations.dart';
import 'package:bank_core/bank_core.dart';
import 'package:bank_experience/bank_experience.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:spending_analytics/spending_analytics.dart';
import 'package:transactions/transactions.dart';

import 'support/profile_trace_storage.dart';

/// Separate from the 60-second scroll gate. Run on the same physical Android:
/// flutter drive --profile --no-dds --driver=test_driver/interaction_performance_driver.dart
/// --target=integration_test/interaction_performance_test.dart
/// --dart-define=PERF_PROBE=true --dart-define=DATA_SOURCE=http
/// --dart-define=API_BASE_URL=https://your-demo-server
/// Omit DATA_SOURCE=http for the ordinary local transport. Flutter 3.35.7 needs
/// --no-dds for traceAction's VM-service connection in this environment.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;
  testWidgets(
    'physical history interactions and analytical drill performance',
    (tester) async {
      // Probes find screens by their Russian text.
      final environment = AppEnvironment.fromDefines(language: AppLanguage.ru);
      final probe = _Probe(tester, binding, environment);
      try {
        probe.publish('preparing');
        expect(
          kProfileMode,
          isTrue,
          reason: 'Frame budgets require a physical profile build.',
        );
        expect(Platform.isAndroid, isTrue);
        expect(const bool.fromEnvironment('PERF_PROBE'), isTrue);
        expect(
          binding.platformDispatcher.accessibilityFeatures.disableAnimations,
          isFalse,
          reason: 'The full-motion comparison needs system animations enabled.',
        );
        await environment.cache
            .clear(); // Response cache only; retain the journal.
        final startup = Stopwatch()..start();
        await tester.pumpWidget(BankExperience(environment: environment));
        await tester.pump();
        probe.conditions['preparationFirstFrameworkFrameMs'] = _ms(
          startup.elapsed,
        );
        await _until(tester, () {
          if (!_homeExists()) return false;
          final state = _home(tester).state;
          if (state.failed && !state.loading) {
            throw StateError('Startup history request failed');
          }
          return state.rowCount > 0 && !state.loading;
        });
        probe.conditions['preparationNetworkReadyMs'] = _ms(startup.elapsed);
        probe.conditions['sourceRows'] = _home(tester).state.total;
        expect(_home(tester).state.total, greaterThanOrEqualTo(12000));
        await _settle(tester);
        probe.startTimings();
        const repeats = int.fromEnvironment(
          'INTERACTION_REPEATS',
          defaultValue: 1,
        );
        expect(repeats, greaterThan(0));
        probe.conditions['repeatsPerMotionMode'] = repeats;
        for (final immediate in [false, true]) {
          environment.setComparison(immediate);
          await _settle(tester);
          expect(
            tester.widget<HistorySliver>(_homeSliver).animate,
            !immediate,
            reason: 'The actual mounted history must use the selected mode.',
          );
          final mode = immediate ? 'immediate' : 'full';
          for (var iteration = 0; iteration < repeats; iteration++) {
            final prefix = 'history_${mode}_$iteration';
            await _resetHistory(tester);
            await _reveal(tester, _choice('Продукты'));
            await probe.stage(
              '${prefix}_filter',
              (action) async {
                _choose(tester, action, 'Продукты');
              },
              ready: () =>
                  _home(tester).state.filter.category == 'groceries' &&
                  !_home(tester).state.loading,
            );
            await _reveal(tester, _choice('Транспорт'));
            await _reveal(tester, _choice('Кафе и рестораны'));
            expect(_choice('Транспорт').hitTestable(), findsOneWidget);
            await probe.stage(
              '${prefix}_rapid_filters',
              (action) async {
                _choose(tester, action, 'Транспорт');
                await tester
                    .pump(); // One real vsync, no wait for the older response.
                _choose(tester, action, 'Кафе и рестораны');
              },
              ready: () =>
                  _home(tester).state.filter.category == 'dining' &&
                  !_home(tester).state.loading,
            );
            expect(_home(tester).state.pendingFilter, isNull);
            await _resetHistory(tester);
            final reading = await _prepareReadingAnchor(tester, environment);
            final anchor = reading.anchorId;
            final history = _home(tester);
            final before = _anchorTop(tester, anchor);
            final oldRevision = history.state.revision;
            final oldIndex = _index(history.state, anchor);
            await probe.stage(
              '${prefix}_activity_while_reading',
              (action) async {
                action.evidence.addAll({
                  'anchorId': anchor,
                  'anchorIndexBefore': oldIndex,
                  'statusChangingId': reading.changingId,
                });
                action.handler(
                  'environment.addActivity',
                  () => unawaited(environment.addActivity()),
                );
              },
              ready: () =>
                  !environment.activityInProgress &&
                  history.state.pendingUpdate != null &&
                  !history.state.loading,
            );
            expect(history.state.revision, oldRevision);
            expect(_anchorTop(tester, anchor), closeTo(before, 2));
            final pendingRevision = history.state.pendingUpdate!.revision;
            await _reveal(tester, _button('Показать обновления'));
            await probe.stage(
              '${prefix}_apply_anchor_window',
              (action) async {
                final button = tester.widget<DsButton>(
                  _button('Показать обновления'),
                );
                action.evidence.addAll({
                  'anchorId': anchor,
                  'anchorIndexBefore': oldIndex,
                  'oldRevision': oldRevision,
                  'pendingRevision': pendingRevision,
                });
                action.handler('pendingUpdate.apply', button.onPressed!);
              },
              ready: () =>
                  history.state.pendingUpdate == null &&
                  history.state.revision == pendingRevision &&
                  history.state.ids.values.contains(anchor),
            );
            final after = _anchorTop(tester, anchor);
            probe.lastEvidence.addAll({
              'anchorIndexAfter': _index(history.state, anchor),
              'anchorTopBefore': before,
              'anchorTopAfter': after,
              'anchorDisplacementLogicalPixels': after - before,
              'statusChangingId': reading.changingId,
              'retainedStatusChangeMarked': history.state.updatedIds.contains(
                reading.changingId,
              ),
            });
            expect(after, closeTo(before, 2));
            expect(history.state.updatedIds, contains(reading.changingId));
            expect(history.state.pages.length, lessThanOrEqualTo(5));
          }
        }
        environment.setComparison(false);
        await _settle(tester);
        await _referenceAccount(tester, probe);
        await _analytics(tester, probe);
        expect(tester.takeException(), isNull);
        probe.publish('passed');
      } catch (error) {
        probe.conditions['failureNetworkEvents'] = environment.apiEvents
            .map((event) => event.toJson())
            .toList();
        probe.publish('failed', failureType: error.runtimeType.toString());
        rethrow;
      } finally {
        probe.stopTimings();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        environment.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );
}

Future<void> _referenceAccount(WidgetTester tester, _Probe probe) async {
  final home = tester.widget<HistorySliver>(_homeSliver).controller;
  home.jumpTo(0);
  await _settle(tester);
  final product = find.byKey(const ValueKey('home-account-main'));
  await _reveal(tester, product);
  final before = home.offset;
  await probe.stage(
    'account_open',
    (action) async {
      final card = tester.widget<DsAccountProduct>(product);
      action.handler('account.onTap', card.onTap);
    },
    ready: () {
      final pages = tester.widgetList<AccountDashboard>(
        find.byType(AccountDashboard),
      );
      return pages.isNotEmpty &&
          pages.single.profile != null &&
          pages.single.summary != null;
    },
  );
  final dashboard = tester.widget<AccountDashboard>(
    find.byType(AccountDashboard),
  );
  final scroll = find.byKey(const PageStorageKey('account-main'));
  await probe.stage('account_collapse_restore', (action) async {
    action.evidence['gestures'] =
        'forward and reverse flings on the mounted account';
    await tester.fling(scroll, const Offset(0, -650), 1200);
    await _settle(tester);
    expect(dashboard.scrollController.offset, greaterThan(208));
    expect(find.byTooltip('Назад').hitTestable(), findsOneWidget);
    await tester.fling(scroll, const Offset(0, 1600), 1800);
    await _settle(tester);
  }, ready: () => dashboard.scrollController.offset <= 1);
  await probe.stage('account_back', (action) async {
    final header = tester.widget<DsAccountHeader>(find.byType(DsAccountHeader));
    action.handler('account.back', header.onBack);
  }, ready: () => find.byType(AccountDashboard).evaluate().isEmpty);
  expect(home.offset, closeTo(before, 2));
}

Future<void> _analytics(WidgetTester tester, _Probe probe) async {
  await probe.stage(
    'analytics_navigation',
    (action) async {
      await action.tap(
        find.descendant(
          of: find.byType(DsNavigationBar),
          matching: find.text('Аналитика'),
        ),
      );
    },
    ready: () =>
        find.byType(AnalyticsPage).evaluate().isNotEmpty &&
        _analyticsCubits(tester).isNotEmpty &&
        _analyticsReady(_analyticsCubits(tester).first),
  );
  await _reveal(tester, _choice('Год'));
  await probe.stage(
    'analytics_period_year',
    (action) async {
      _choose(tester, action, 'Год');
    },
    ready: () =>
        _analyticsReady(_analyticsCubits(tester).first) &&
        tester.widget<DsChoice>(_choice('Год')).selected,
  );
  final overview = _analyticsCubits(tester).first;
  final total = overview.state.summary!.total;
  probe.lastEvidence.addAll({
    'fullDatasetRows': _home(tester).state.total,
    'expenseCountInPeriod': overview.state.summary!.count,
    'categoryPoints': overview.state.summary!.categories.length,
    'timePoints': overview.state.summary!.timeline.length,
  });
  final rankedFinder = find.byType(DsRankedBars, skipOffstage: false);
  var ranked = tester.widget<DsRankedBars>(rankedFinder);
  final categoryIndex = ranked.points.indexWhere((point) => point.value > 0);
  expect(categoryIndex, isNonNegative);
  final category = ranked.points[categoryIndex];
  await _reveal(
    tester,
    find.text('${categoryIndex + 1}. ${category.label}', skipOffstage: false),
  );
  final categoryScroll = _overviewScroll(tester);
  ranked = tester.widget<DsRankedBars>(rankedFinder);
  await probe.stage('analytics_category_drill', (action) async {
    action.evidence['category'] = category.id;
    action.handler(
      'chart.category.onSelected',
      () => ranked.onSelected!(category),
    );
  }, ready: () => _drillReady(tester));
  final detail = _analyticsCubits(tester).last.state.summary!;
  expect(detail.total.minor, category.value);
  expect(_detail(tester).state.filter.kind, EntryKind.expense);
  await _backToOverview(tester, probe, 'analytics_category_back');
  expect(_analyticsCubits(tester).first.state.summary!.total, total);
  expect(tester.widget<DsRankedBars>(rankedFinder).selectedId, category.id);
  expect(_overviewScroll(tester), closeTo(categoryScroll, 2));

  final chartFinder = find.byType(DsBarChart, skipOffstage: false);
  await _reveal(tester, chartFinder);
  final chart = tester.widget<DsBarChart>(chartFinder);
  final point = chart.points.firstWhere((point) => point.value > 0);
  await _reveal(
    tester,
    find
        .descendant(
          of: chartFinder,
          matching: find.text(point.label, skipOffstage: false),
          skipOffstage: false,
        )
        .first,
  );
  final timeScroll = _overviewScroll(tester);
  await probe.stage('analytics_time_drill', (action) async {
    action.evidence['timePoint'] = point.id;
    action.handler('chart.time.onSelected', () => chart.onSelected!(point));
  }, ready: () => _drillReady(tester));
  expect(_analyticsCubits(tester).last.state.summary!.total.minor, point.value);
  expect(_detail(tester).state.filter.kind, EntryKind.expense);
  await _backToOverview(tester, probe, 'analytics_time_back');
  expect(tester.widget<DsBarChart>(chartFinder).selectedId, point.id);
  expect(_overviewScroll(tester), closeTo(timeScroll, 2));
  expect(tester.widget<DsChoice>(_choice('Год')).selected, isTrue);
}

Future<void> _backToOverview(
  WidgetTester tester,
  _Probe probe,
  String name,
) async {
  final back = find.byTooltip('Назад');
  expect(back.hitTestable(), findsOneWidget);
  final button = tester.widget<DsIconButton>(
    find.ancestor(of: back, matching: find.byType(DsIconButton)).first,
  );
  await probe.stage(
    name,
    (action) async {
      action.handler('drill.back.onPressed', button.onPressed!);
    },
    ready: () =>
        find.byType(AnalyticsPage).evaluate().isNotEmpty &&
        _analyticsReady(_analyticsCubits(tester).first),
  );
}

bool _analyticsReady(AnalyticsCubit cubit) =>
    !cubit.state.loading && !cubit.state.failed && cubit.state.summary != null;
bool _drillReady(WidgetTester tester) =>
    find.text('Детализация расходов').evaluate().isNotEmpty &&
    _analyticsCubits(tester).length > 1 &&
    _analyticsReady(_analyticsCubits(tester).last) &&
    !_detail(tester).state.loading &&
    _detail(tester).state.rowCount > 0;
List<AnalyticsCubit> _analyticsCubits(WidgetTester tester) => tester
    .widgetList<BlocBuilder<AnalyticsCubit, AnalyticsState>>(
      find.byWidgetPredicate(
        (widget) => widget is BlocBuilder<AnalyticsCubit, AnalyticsState>,
        skipOffstage: false,
      ),
    )
    .map((widget) => widget.bloc!)
    .toList();
HistoryCubit _detail(WidgetTester tester) => tester
    .widgetList<HistorySliver>(find.byType(HistorySliver, skipOffstage: false))
    .last
    .cubit;
Finder get _homeSliver => find.descendant(
  of: find.byKey(const PageStorageKey<String>('home'), skipOffstage: false),
  matching: find.byType(HistorySliver, skipOffstage: false),
  skipOffstage: false,
);
bool _homeExists() => _homeSliver.evaluate().isNotEmpty;
HistoryCubit _home(WidgetTester tester) =>
    tester.widget<HistorySliver>(_homeSliver).cubit;
Finder _choice(String label) => find.byWidgetPredicate(
  (widget) => widget is DsChoice && widget.label == label,
  skipOffstage: false,
);
Finder _button(String label) => find.byWidgetPredicate(
  (widget) => widget is DsButton && widget.label == label,
  skipOffstage: false,
);
void _choose(WidgetTester tester, _Action action, String label) {
  final visible = _choice(label).hitTestable();
  expect(visible, findsOneWidget, reason: 'Reveal $label before measuring.');
  final choice = tester.widget<DsChoice>(visible);
  expect(choice.onSelected, isNotNull);
  action.handler('choice.$label', () => choice.onSelected!(!choice.selected));
}

int _index(HistoryState state, String id) =>
    state.ids.entries.firstWhere((entry) => entry.value == id).key;
double _anchorTop(WidgetTester tester, String id) =>
    tester.getTopLeft(find.byKey(ValueKey<String>(id), skipOffstage: false)).dy;
double _overviewScroll(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(AnalyticsPage, skipOffstage: false),
            matching: find.byType(Scrollable, skipOffstage: false),
            skipOffstage: false,
          )
          .first,
    )
    .position
    .pixels;

Future<void> _resetHistory(WidgetTester tester) async {
  final sliver = tester.widget<HistorySliver>(_homeSliver);
  sliver.controller.jumpTo(0);
  await _settle(tester);
  // Walk the actual lazy feed before asking ensureVisible to resolve a
  // filter. A far sliver's estimated preceding extent is not a painted target.
  // Preparation stays outside the measured interaction; no callback is invoked
  // until the real heading and filter have entered the viewport.
  final heading = find.descendant(
    of: find.byKey(const PageStorageKey<String>('home')),
    matching: find.text('История операций'),
  );
  for (
    var step = 0;
    step < 60 && heading.hitTestable().evaluate().isEmpty;
    step++
  ) {
    await tester.drag(
      find.byKey(const PageStorageKey<String>('home')),
      const Offset(0, -320),
    );
    await _settle(tester);
  }
  expect(heading.hitTestable(), findsOneWidget);
  await _reveal(tester, _choice('Все'));
  final choice = tester.widget<DsChoice>(_choice('Все').hitTestable());
  choice.onSelected!(true);
  await _until(
    tester,
    () =>
        _home(tester).state.filter.category == null &&
        !_home(tester).state.loading,
  );
  await _settle(tester);
}

Future<({String anchorId, String changingId})> _prepareReadingAnchor(
  WidgetTester tester,
  AppEnvironment environment,
) async {
  // Discover the next real fixture status change without mutating it. These
  // setup requests are outside the measured stages and use the selected HTTP
  // adapter. The ordinary UI still loads every visible page through its repo.
  final pending = await environment.api.get(
    '/v1/transactions',
    query: {'status': 'pending', 'limit': 1},
  );
  final entries = (pending['items'] as List).cast<Map<String, dynamic>>();
  expect(entries, isNotEmpty);
  final changingId = entries.first['id'] as String;
  final changingTile = find.byKey(
    ValueKey<String>(changingId),
    skipOffstage: false,
  );
  for (var gesture = 0; gesture < 120; gesture++) {
    if (changingTile.evaluate().isNotEmpty) {
      await Scrollable.ensureVisible(
        tester.element(changingTile),
        alignment: .35,
        duration: const Duration(milliseconds: 240),
      );
      await _settle(tester);
      expect(changingTile.hitTestable(), findsOneWidget);
      final history = _home(tester);
      final anchor = history.readingAnchorId;
      final anchorFinder = anchor == null
          ? null
          : find.byKey(ValueKey<String>(anchor), skipOffstage: false);
      if (anchor != null &&
          history.state.ids.values.contains(anchor) &&
          _index(history.state, anchor) >= 90 &&
          history.userIsReading &&
          anchorFinder!.evaluate().isNotEmpty &&
          tester
              .getRect(anchorFinder)
              .overlaps(
                tester.getRect(
                  find.byKey(
                    const PageStorageKey<String>('home'),
                    skipOffstage: false,
                  ),
                ),
              )) {
        return (anchorId: anchor, changingId: changingId);
      }
    }
    await tester.fling(
      find.byKey(const PageStorageKey<String>('home'), skipOffstage: false),
      const Offset(0, -1000),
      1500,
    );
    await _settle(tester);
    await _until(
      tester,
      () =>
          !_home(tester).state.loading &&
          _home(tester).state.loadingPages.isEmpty,
    );
  }
  throw StateError(
    'Actual gestures did not establish a reading anchor beyond row 90',
  );
}

Future<void> _until(
  WidgetTester tester,
  bool Function() ready, {
  VoidCallback? sample,
}) async {
  final watch = Stopwatch()..start();
  while (!ready()) {
    if (watch.elapsed > const Duration(seconds: 60)) {
      throw StateError('Application data-ready timeout');
    }
    await tester.pump(const Duration(milliseconds: 20));
    sample?.call();
    expect(tester.takeException(), isNull);
  }
}

Future<void> _settle(WidgetTester tester) => tester
    .pumpAndSettle(
      const Duration(milliseconds: 16),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 20),
    )
    .then((_) {});
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    // A lazy child cannot be found by waiting for a frame at the same offset.
    // Scroll only the active route; hidden IndexedStack pages must stay put.
    final scrollable = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable &&
          axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
    );
    await tester.scrollUntilVisible(
      finder,
      240,
      scrollable: scrollable.first,
      maxScrolls: 40,
    );
  }
  if (finder.hitTestable().evaluate().isEmpty) {
    await Scrollable.ensureVisible(
      tester.element(finder),
      alignment: .5,
      duration: const Duration(milliseconds: 240),
    );
  }
  await _settle(tester);
  expect(
    finder.hitTestable(),
    findsOneWidget,
    reason: 'Interaction setup must expose the real control before tracing.',
  );
}

double _ms(Duration value) => value.inMicroseconds / 1000;

final class _Action {
  _Action(this.tester);
  final WidgetTester tester;
  final Stopwatch watch = Stopwatch()..start();
  final List<Map<String, Object?>> handlers = [];
  final List<Future<void>> firstFrames = [];
  final List<double> driverTapToPump = [];
  final Map<String, Object?> evidence = {};
  double? latestHandlerStartedMs;

  void handler(String label, VoidCallback action) {
    final timer = Stopwatch()..start();
    final firstFrame = Completer<void>();
    final row = <String, Object?>{
      'label': label,
      'entry': 'actual widget callback; excludes input dispatch',
    };
    handlers.add(row);
    firstFrames.add(firstFrame.future);
    latestHandlerStartedMs = _ms(watch.elapsed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      row['handlerToFirstFrameworkFrameMs'] = _ms(timer.elapsed);
      firstFrame.complete();
    });
    action();
    row['synchronousHandlerMs'] = _ms(timer.elapsed);
    WidgetsBinding.instance.scheduleFrame();
  }

  Future<void> tap(Finder finder) async {
    final timer = Stopwatch()..start();
    await tester.tap(finder);
    await tester.pump();
    driverTapToPump.add(_ms(timer.elapsed));
  }
}

final class _Probe {
  _Probe(this.tester, this.binding, this.environment);
  final WidgetTester tester;
  final IntegrationTestWidgetsFlutterBinding binding;
  final AppEnvironment environment;
  final List<FrameTiming> _frames = [];
  final List<Map<String, Object?>> stages = [];
  final Map<String, Object?> conditions = {};
  bool _watching = false;
  String? _current;
  Map<String, Object?> get lastEvidence =>
      stages.last['evidence']! as Map<String, Object?>;
  void _collect(List<FrameTiming> values) => _frames.addAll(values);
  void startTimings() {
    WidgetsBinding.instance.addTimingsCallback(_collect);
    _watching = true;
  }

  void stopTimings() {
    if (_watching) WidgetsBinding.instance.removeTimingsCallback(_collect);
    _watching = false;
  }

  Future<void> stage(
    String name,
    Future<void> Function(_Action) action, {
    required bool Function() ready,
  }) async {
    _current = name;
    publish('running');
    // Outside traceAction: progress logging must not affect a measured frame.
    debugPrint('INTERACTION trace begin $name');
    int? firstFrame;
    int? lastFrame;
    _Action? measured;
    var readyMs = 0.0;
    var readyFrameMs = 0.0;
    var settledMs = 0.0;
    var maxPages = 0;
    final startRss = ProcessInfo.currentRss;
    final previousRequest = environment.apiEvents.fold<int>(
      0,
      (max, event) => event.requestId > max ? event.requestId : max,
    );
    final navigationOffset = environment.navigationFirstFrameMs.length;
    void sample() {
      for (final history in tester.widgetList<HistorySliver>(
        find.byType(HistorySliver, skipOffstage: false),
      )) {
        final count = history.cubit.state.pages.length;
        if (count > maxPages) maxPages = count;
      }
    }

    await binding.traceAction(
      () async {
        firstFrame = binding.platformDispatcher.frameData.frameNumber;
        measured = _Action(tester);
        await action(measured!);
        await _until(tester, ready, sample: sample);
        readyMs = _ms(measured!.watch.elapsed);
        await tester.pump();
        readyFrameMs = _ms(measured!.watch.elapsed);
        await _settle(tester);
        await Future.wait(measured!.firstFrames);
        settledMs = _ms(measured!.watch.elapsed);
        sample();
        lastFrame = binding.platformDispatcher.frameData.frameNumber;
      },
      streams: ['Dart', 'Embedder', 'GC'],
      reportKey: 'interaction_$name',
    );
    compactProfileTrace(binding.reportData!, 'interaction_$name');
    debugPrint('INTERACTION trace end $name');
    // Flutter batches FrameTiming delivery. Match engine frame IDs, so the
    // two-second drain and frames from adjoining stages are never attributed.
    await tester.pump(const Duration(seconds: 2));
    final frames = _frames
        .where(
          (frame) =>
              frame.frameNumber > firstFrame! &&
              frame.frameNumber <= lastFrame!,
        )
        .toList();
    const budget = int.fromEnvironment('FRAME_BUDGET_US', defaultValue: 16667);
    final uiMisses = frames
        .where((frame) => frame.buildDuration.inMicroseconds > budget)
        .length;
    final rasterMisses = frames
        .where((frame) => frame.rasterDuration.inMicroseconds > budget)
        .length;
    final eitherMisses = frames
        .where(
          (frame) =>
              frame.buildDuration.inMicroseconds > budget ||
              frame.rasterDuration.inMicroseconds > budget,
        )
        .length;
    stages.add({
      'name': name,
      'status': 'measured',
      'motionComparisonImmediate': environment.motionComparison,
      'systemReduceMotion':
          binding.platformDispatcher.accessibilityFeatures.disableAnimations,
      'frameIdStartExclusive': firstFrame,
      'frameIdEndInclusive': lastFrame,
      'frameAttribution': 'engine frameNumber; callback batching excluded',
      'dataReadyMs': readyMs,
      'dataReadyFrameworkFrameMs': readyFrameMs,
      'latestHandlerToDataReadyMs': measured!.latestHandlerStartedMs == null
          ? null
          : readyMs - measured!.latestHandlerStartedMs!,
      'visualSettledMs': settledMs,
      'handlers': measured!.handlers,
      'driverTapToPumpMs': measured!.driverTapToPump,
      'navigationHandlerToFirstFrameworkFrameMs': environment
          .navigationFirstFrameMs
          .skip(navigationOffset)
          .toList(),
      'uiBuildMs': _distribution(
        frames.map((frame) => _ms(frame.buildDuration)).toList(),
      ),
      'rasterMs': _distribution(
        frames.map((frame) => _ms(frame.rasterDuration)).toList(),
      ),
      'vsyncOverheadMs': _distribution(
        frames.map((frame) => _ms(frame.vsyncOverhead)).toList(),
      ),
      'totalSpanMs': _distribution(
        frames.map((frame) => _ms(frame.totalSpan)).toList(),
      ),
      'frameBudgetUs': budget,
      'missDefinition':
          'UI build or raster duration exceeds budget; idle vsync gaps are not classified as dropped frames',
      'uiMisses': uiMisses,
      'rasterMisses': rasterMisses,
      'eitherMisses': eitherMisses,
      'eitherMissesPercent': frames.isEmpty
          ? null
          : eitherMisses * 100 / frames.length,
      'maxAppliedModelPagesPerHistory': maxPages,
      'rssBeforeBytes': startRss,
      'rssAfterBytes': ProcessInfo.currentRss,
      'networkEvents': environment.apiEvents
          .where((event) => event.requestId > previousRequest)
          .map((event) => event.toJson())
          .toList(),
      'evidence': measured!.evidence,
      'frames': [
        for (final frame in frames)
          {
            'frameNumber': frame.frameNumber,
            'vsyncUs': frame.timestampInMicroseconds(FramePhase.vsyncStart),
            'buildStartUs': frame.timestampInMicroseconds(
              FramePhase.buildStart,
            ),
            'buildFinishUs': frame.timestampInMicroseconds(
              FramePhase.buildFinish,
            ),
            'rasterStartUs': frame.timestampInMicroseconds(
              FramePhase.rasterStart,
            ),
            'rasterFinishUs': frame.timestampInMicroseconds(
              FramePhase.rasterFinish,
            ),
            'buildUs': frame.buildDuration.inMicroseconds,
            'rasterUs': frame.rasterDuration.inMicroseconds,
          },
      ],
    });
    publish('running');
    expect(
      frames,
      isNotEmpty,
      reason: 'No actual engine FrameTiming for $name',
    );
    expect(maxPages, lessThanOrEqualTo(5));
    expect(tester.takeException(), isNull);
  }

  void publish(String status, {String? failureType}) {
    binding.reportData = {
      ...?binding.reportData,
      'interaction_profile': {
        ...conditions,
        'status': status,
        'currentStage': _current,
        'failureType': failureType,
        'buildMode': kProfileMode
            ? 'profile'
            : kReleaseMode
            ? 'release'
            : 'debug',
        'framePolicy': binding.framePolicy.name,
        'source': environment.sourceLabel,
        'httpKeepAlive': environment.http
            ? environment.api.persistentConnection
            : null,
        'scope': environment.scopeId,
        'transport': environment.http ? 'http' : 'simulation',
        'protocol': environment.http
            ? Uri.parse(
                const String.fromEnvironment(
                  'API_BASE_URL',
                  defaultValue: 'https://demo.invalid',
                ),
              ).scheme
            : 'local adapter',
        'requestedProfile': environment.simulation.profile.toJson(),
        'profileAppliesLocally': !environment.http,
        'httpServerConditions': const String.fromEnvironment(
          'HTTP_PROFILE_DESCRIPTION',
          defaultValue: 'Not supplied; attach server launch evidence',
        ),
        'seed': environment.simulation.transport.seed,
        'cache': 'native response cache cleared once; journal retained',
        'refreshRateHz':
            binding.platformDispatcher.views.first.display.refreshRate,
        'physicalViewWidth':
            binding.platformDispatcher.views.first.physicalSize.width,
        'physicalViewHeight':
            binding.platformDispatcher.views.first.physicalSize.height,
        'devicePixelRatio':
            binding.platformDispatcher.views.first.devicePixelRatio,
        'dataReadyPollingMs': 20,
        'frameTimingDeliveryDrainMs': 2000,
        'deviceLabel': const String.fromEnvironment(
          'DEVICE_LABEL',
          defaultValue: 'Attach physical-device evidence externally',
        ),
        'stages': stages,
        'statusMeaning':
            'Scenario and instrumentation assertions; numerical performance budgets remain explicit measurements, assessed separately from the sustained scroll gate',
        'notes':
            'Raw traceAction traces are separate interaction_* report keys. Widget-callback handler metrics exclude input dispatch. Data-ready is observed by polling; dataReadyFrameworkFrameMs is the next framework pump after that observation, not guaranteed first physical presentation. UI/raster timings are actual engine FrameTiming. Applied page count is state.pages only; prepared pending windows also contribute to RSS. This is a scenario probe, not the sustained 60-second scroll gate or human animation-benefit test. RSS is not Android PSS.',
      },
    };
  }
}

Map<String, Object?> _distribution(List<double> values) {
  values.sort();
  double? percentile(double fraction) =>
      values.isEmpty ? null : values[((values.length - 1) * fraction).round()];
  return {
    'count': values.length,
    'p50': percentile(.5),
    'p95': percentile(.95),
    'p99': percentile(.99),
    'max': values.isEmpty ? null : values.last,
  };
}
