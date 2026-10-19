import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> revealJourneyElement(WidgetTester tester, Finder finder) async {
  bool visible() {
    final candidates = finder.evaluate().toSet();
    final onstage = find.byElementPredicate(candidates.contains);
    final elements = onstage.evaluate();
    if (elements.length != 1) return false;
    final object = elements.single.renderObject;
    return object is RenderBox &&
        object.hasSize &&
        onstage.hitTestable().evaluate().isNotEmpty;
  }

  Future<void> revealMounted() async {
    if (!visible() && finder.evaluate().length == 1) {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
    }
  }

  await tester.pumpAndSettle();
  await revealMounted();
  if (!visible()) {
    final scrollable = find
        .descendant(
          of: find.byType(CustomScrollView).last,
          matching: find.byType(Scrollable),
        )
        .first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
    for (var step = 0; step < 60 && !visible(); step++) {
      await tester.drag(scrollable, const Offset(0, -240));
      await tester.pumpAndSettle();
      await revealMounted();
    }
  }
  expect(
    visible(),
    isTrue,
    reason: 'Control must be onstage before interaction: $finder',
  );
}

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
          (element.widget as CircularProgressIndicator).value == null &&
          TickerMode.valuesOf(element).enabled &&
          (ModalRoute.of(element)?.isCurrent ?? true),
    );
