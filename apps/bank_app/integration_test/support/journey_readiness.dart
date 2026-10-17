import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test-only readiness shared by the device journey and its widget regressions.
Future<void> waitForJourneyReadiness(
  WidgetTester tester, {
  required String stage,
}) async {
  final deadline = tester.binding.clock.fromNowBy(const Duration(seconds: 60));
  // A tap can schedule a new route after the caller's first frame. Build it
  // before deciding whether data loading has finished.
  await tester.pump(const Duration(milliseconds: 100));
  while (_activeLoaders().isNotEmpty &&
      tester.binding.clock.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(_activeLoaders(), isEmpty, reason: 'Stage "$stage" is still loading');
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 10),
  );
  expect(tester.takeException(), isNull);
}

Iterable<Element> _activeLoaders() => find
    .byType(CircularProgressIndicator, skipOffstage: false)
    .evaluate()
    .where(
      // SliverMainAxisGroup hides nonpainted children from default finders,
      // although their progress tickers still run. Covered routes and muted
      // tabs are excluded so retained background UI cannot block this journey.
      (element) =>
          TickerMode.of(element) && (ModalRoute.of(element)?.isCurrent ?? true),
    );
