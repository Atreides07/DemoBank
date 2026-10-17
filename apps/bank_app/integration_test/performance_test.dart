import 'dart:io';
import 'dart:ui';
import 'package:app_foundation/app_foundation.dart';
import 'package:bank_experience/bank_experience.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:network_client/network_client.dart';
import 'package:transactions/transactions.dart';

import 'support/profile_trace_storage.dart';

Map<String, Object> _distribution(List<double> values) {
  values.sort();
  double percentile(double p) =>
      values.isEmpty ? 0 : values[((values.length - 1) * p).round()];
  return {
    'count': values.length,
    'p50': percentile(.5),
    'p95': percentile(.95),
    'p99': percentile(.99),
    'max': values.isEmpty ? 0 : values.last,
  };
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  final timeout = Stopwatch()..start();
  while (!ready()) {
    if (timeout.elapsed > const Duration(seconds: 30)) {
      throw StateError('Timed out waiting for actual application data');
    }
    await tester.pump(const Duration(milliseconds: 20));
  }
}

HistoryCubit _history(WidgetTester tester) => tester
    .widget<HistorySliver>(
      find.byType(HistorySliver, skipOffstage: false).first,
    )
    .cubit;

bool _historyReady(WidgetTester tester) {
  if (find.byType(HistorySliver, skipOffstage: false).evaluate().isEmpty) {
    return false;
  }
  final state = _history(tester).state;
  if (state.rowCount == 0 && state.error != null) {
    throw StateError('History request failed: ${state.error}');
  }
  return state.rowCount > 0;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;
  testWidgets('physical Android performance with production data path', (
    tester,
  ) async {
    final startup = Stopwatch();
    int? firstPageCompletedUs;
    double? firstPageRequestMs;
    final environment = AppEnvironment.fromDefines(
      onApiEvent: (event) {
        if (startup.isRunning &&
            firstPageCompletedUs == null &&
            event.path == '/v1/transactions' &&
            event.phase == ApiRequestPhase.completed) {
          firstPageCompletedUs = startup.elapsedMicroseconds;
          firstPageRequestMs = event.elapsed.inMicroseconds / 1000;
        }
      },
    );
    try {
      // Explicit cold response cache, never clear the payment journal.
      await environment.cache.clear();
      startup.start();
      await tester.pumpWidget(BankExperience(environment: environment));
      await tester.pump();
      await _until(
        tester,
        () => find.byType(DsHomeHeader).evaluate().isNotEmpty,
      );
      final firstFrameMs = startup.elapsedMicroseconds / 1000;
      await _until(tester, () => _historyReady(tester));
      await tester.pump();
      final coldFirstPageFrameMs = startup.elapsedMicroseconds / 1000;
      expect(firstPageCompletedUs, isNotNull);
      final networkCompleteToFrameMs =
          coldFirstPageFrameMs - firstPageCompletedUs! / 1000;
      await _until(tester, () => !_history(tester).state.loading);
      final firstPageCount = _history(tester).state.rowCount;
      final totalRows = _history(tester).state.total;
      expect(firstPageCount, 30);
      expect(totalRows, greaterThanOrEqualTo(10000));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      final cachedStart = Stopwatch()..start();
      await tester.pumpWidget(BankExperience(environment: environment));
      await _until(tester, () => _historyReady(tester));
      await tester.pump();
      final cachedFirstPageFrameMs = cachedStart.elapsedMicroseconds / 1000;
      final cachedWasStale = _history(tester).state.stale;
      await _until(tester, () => !_history(tester).state.loading);
      await tester.pumpAndSettle();
      // Flush batched startup timings before the measured scrolling interval.
      await tester.pump(const Duration(seconds: 2));
      final collectedTimings = <FrameTiming>[];
      int? scrollFrameStart;
      int? scrollFrameEnd;
      final memorySamples = <Map<String, Object>>[];
      void memory(String stage) => memorySamples.add({
        'stage': stage,
        'rssBytes': ProcessInfo.currentRss,
        'loadedModelPages': _history(tester).state.pages.length,
        'knownRows': _history(tester).state.rowCount,
      });
      memory('before_scroll');
      var scrollSeconds = 0.0;
      var gestures = 0;
      var maxLoadedPages = 0;
      final seconds = const int.fromEnvironment(
        'BENCHMARK_SECONDS',
        defaultValue: 60,
      );
      await binding.traceAction(
        () async {
          void collect(List<FrameTiming> values) =>
              collectedTimings.addAll(values);
          WidgetsBinding.instance.addTimingsCallback(collect);
          scrollFrameStart = binding.platformDispatcher.frameData.frameNumber;
          final active = Stopwatch()..start();
          while (active.elapsed < Duration(seconds: seconds)) {
            final scroll = find.byKey(const PageStorageKey<String>('home'));
            // Traverse into the actual history, including page arrivals; periodically
            // reverse to exercise reuse and reveal the collapsing header again.
            final reverse = gestures % 16 >= 10;
            await tester.fling(scroll, Offset(0, reverse ? 1100 : -1100), 1500);
            await tester.pumpAndSettle();
            final pages = _history(tester).state.pages.length;
            if (pages > maxLoadedPages) maxLoadedPages = pages;
            gestures++;
          }
          scrollSeconds = active.elapsedMilliseconds / 1000;
          scrollFrameEnd = binding.platformDispatcher.frameData.frameNumber;
          await tester.pump(const Duration(seconds: 2));
          WidgetsBinding.instance.removeTimingsCallback(collect);
        },
        streams: ['Dart', 'Embedder', 'GC'],
        reportKey: 'scroll_timeline',
      );
      compactProfileTrace(binding.reportData!, 'scroll_timeline');
      // FrameTiming arrives in batches. Drain delivery without adding idle
      // drain frames to the scroll's denominator or its duration distribution.
      final timings = collectedTimings
          .where(
            (frame) =>
                frame.frameNumber > scrollFrameStart! &&
                frame.frameNumber <= scrollFrameEnd!,
          )
          .toList();
      memory('after_scroll');
      final driverTapLatency = <double>[];
      for (var cycle = 0; cycle < 6; cycle++) {
        for (final label in ['Аналитика', 'Платежи', 'Профиль', 'Главная']) {
          final watch = Stopwatch()..start();
          await tester.tap(
            find.descendant(
              of: find.byType(DsNavigationBar),
              matching: find.text(label),
            ),
          );
          await tester.pump();
          driverTapLatency.add(watch.elapsedMicroseconds / 1000);
          await tester.pumpAndSettle();
        }
        memory('navigation_cycle_$cycle');
      }
      final overBudget = timings
          .where(
            (v) =>
                v.buildDuration.inMicroseconds > 16667 ||
                v.rasterDuration.inMicroseconds > 16667,
          )
          .length;
      binding.reportData = {
        ...?binding.reportData,
        'device_profile': {
          'framePolicy': binding.framePolicy.name,
          'buildMode': kProfileMode
              ? 'profile'
              : kReleaseMode
              ? 'release'
              : 'debug',
          'elapsedSeconds': scrollSeconds,
          'gestures': gestures,
          'source': environment.sourceLabel,
          'httpKeepAlive': environment.http
              ? environment.api.persistentConnection
              : null,
          'scope': environment.scopeId,
          'network': environment.simulation.profile.toJson(),
          'firstWidgetFrameMs': firstFrameMs,
          'coldFirstPageFrameworkFrameMs': coldFirstPageFrameMs,
          'firstPageRequestMs': firstPageRequestMs,
          'firstPageNetworkCompleteToFrameworkFrameMs':
              networkCompleteToFrameMs,
          'cachedFirstPageFrameworkFrameMs': cachedFirstPageFrameMs,
          'cacheShownBeforeNetwork': cachedWasStale,
          'initialPageCount': firstPageCount,
          'totalRows': totalRows,
          'maxLoadedModelPages': maxLoadedPages,
          'frameCount': timings.length,
          'frameIdStartExclusive': scrollFrameStart,
          'frameIdEndInclusive': scrollFrameEnd,
          'frameAttribution':
              'engine frameNumber; two-second delivery drain excluded',
          'buildMs': _distribution(
            timings.map((v) => v.buildDuration.inMicroseconds / 1000).toList(),
          ),
          'rasterMs': _distribution(
            timings.map((v) => v.rasterDuration.inMicroseconds / 1000).toList(),
          ),
          'framesOverBudget': overBudget,
          'framesOverBudgetPercent': timings.isEmpty
              ? 0
              : overBudget * 100 / timings.length,
          'navigationDriverTapToPumpMs': _distribution(driverTapLatency),
          'navigationHandlerToFirstFrameMs': _distribution(
            environment.navigationFirstFrameMs,
          ),
          'memorySamples': memorySamples,
          'networkEvents': environment.apiEvents
              .map((e) => e.toJson())
              .toList(),
          'frames': [
            for (final t in timings)
              {
                'frameNumber': t.frameNumber,
                'vsyncUs': t.timestampInMicroseconds(FramePhase.vsyncStart),
                'buildUs': t.buildDuration.inMicroseconds,
                'rasterUs': t.rasterDuration.inMicroseconds,
              },
          ],
          'notes':
              'Cold/cache page metric is data-ready framework frame; rows may be below viewport. Handler metric excludes input dispatch and raster presentation. OS/process startup measured separately. RSS is process resident memory, not Android PSS.',
        },
      };
      expect(tester.takeException(), isNull);
      expect(timings, isNotEmpty);
      expect(maxLoadedPages, lessThanOrEqualTo(5));
    } catch (error) {
      binding.reportData = {
        ...?binding.reportData,
        'failed_profile': {
          'source': environment.sourceLabel,
          'httpKeepAlive': environment.http
              ? environment.api.persistentConnection
              : null,
          'failureType': error.runtimeType.toString(),
          'message': error.toString(),
          'networkEvents': environment.apiEvents
              .map((e) => e.toJson())
              .toList(),
        },
      };
      rethrow;
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      environment.dispose();
    }
  });
}
