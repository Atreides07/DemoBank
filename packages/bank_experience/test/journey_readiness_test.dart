import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../apps/bank_app/integration_test/support/journey_readiness.dart';

void main() {
  testWidgets('waits for an active loader below the viewport', (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: _LoadingDrill(
          controller: scroll,
          delay: const Duration(seconds: 15),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.byType(CircularProgressIndicator, skipOffstage: false),
      findsOneWidget,
    );
    final started = tester.binding.clock.now();

    await waitForJourneyReadiness(tester, stage: 'merchant drill');

    expect(find.text('Loaded rows', skipOffstage: false), findsOneWidget);
    expect(tester.binding.clock.now().difference(started).inSeconds, 15);
    expect(scroll.offset, 0, reason: 'Readiness must preserve the viewport');
  });

  testWidgets('pumps a newly pushed route before checking its loading state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => unawaited(
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) =>
                        const _LoadingDrill(delay: Duration(seconds: 15)),
                  ),
                ),
              ),
              child: const Text('Open merchant'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open merchant'));

    await waitForJourneyReadiness(tester, stage: 'new merchant route');

    expect(find.text('Loaded rows', skipOffstage: false), findsOneWidget);
  });

  testWidgets('does not wait for a covered route with a disabled ticker', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                const CircularProgressIndicator(),
                TextButton(
                  onPressed: () => unawaited(
                    Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) =>
                            const Scaffold(body: Text('Current route')),
                      ),
                    ),
                  ),
                  child: const Text('Cover loading route'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Cover loading route'));
    final started = tester.binding.clock.now();

    await waitForJourneyReadiness(tester, stage: 'covered route');

    expect(find.text('Current route'), findsOneWidget);
    expect(
      find.byType(CircularProgressIndicator, skipOffstage: false),
      findsOneWidget,
    );
    expect(
      tester.binding.clock.now().difference(started).inSeconds,
      lessThan(10),
    );
  });

  testWidgets(
    'an unfinished active load fails within the existing data budget',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _LoadingDrill()));
      final started = tester.binding.clock.now();

      await expectLater(
        () => waitForJourneyReadiness(
          tester,
          stage: 'unfinished merchant request',
        ),
        throwsA(
          predicate<Object>(
            (error) => error.toString().contains(
              'Stage "unfinished merchant request" is still loading',
            ),
          ),
        ),
      );

      expect(tester.binding.clock.now().difference(started).inSeconds, 60);
    },
  );
}

/// The real HistorySliver places its loading adapter inside a
/// SliverMainAxisGroup below the drill header. A nonpainted group child is
/// excluded by default finders, even while its progress ticker is active.
class _LoadingDrill extends StatefulWidget {
  const _LoadingDrill({this.controller, this.delay});
  final ScrollController? controller;
  final Duration? delay;

  @override
  State<_LoadingDrill> createState() => _LoadingDrillState();
}

class _LoadingDrillState extends State<_LoadingDrill> {
  Timer? _response;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.delay case final delay?) {
      _response = Timer(delay, () => setState(() => _loading = false));
    }
  }

  @override
  void dispose() {
    _response?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: CustomScrollView(
      controller: widget.controller,
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 1200)),
        SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('Loaded rows'),
            ),
          ],
        ),
      ],
    ),
  );
}
