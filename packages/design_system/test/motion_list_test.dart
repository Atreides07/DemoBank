import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Record {
  const _Record(this.id, {this.height = 80});
  final String id;
  final double height;
}

class _RememberedRow extends StatefulWidget {
  const _RememberedRow(this.record);
  final _Record record;
  static int creations = 0;

  @override
  State<_RememberedRow> createState() => _RememberedRowState();
}

class _RememberedRowState extends State<_RememberedRow> {
  late final int serial = ++_RememberedRow.creations;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: widget.record.height,
    child: Text(
      '${widget.record.id}/$serial',
      key: ValueKey('visual-${widget.record.id}'),
    ),
  );
}

void main() {
  final theme = DsAppTheme.light();
  Future<void> pumpList(
    WidgetTester tester,
    ValueNotifier<List<_Record>> records,
    ScrollController controller, {
    bool reduced = false,
    ValueChanged<String>? onAnchorChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Scaffold(
            body: ValueListenableBuilder<List<_Record>>(
              valueListenable: records,
              builder: (context, value, child) => CustomScrollView(
                controller: controller,
                slivers: [
                  DsAnimatedSliverList<_Record>(
                    items: value,
                    idOf: (record) => record.id,
                    controller: controller,
                    onAnchorChanged: onAnchorChanged,
                    itemBuilder: (_, record) => _RememberedRow(record),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('lazy rows retain state through reordering and interruptions', (
    tester,
  ) async {
    _RememberedRow.creations = 0;
    final records = ValueNotifier([
      const _Record('a'),
      const _Record('b'),
      const _Record('c'),
      const _Record('d'),
    ]);
    final controller = ScrollController();
    addTearDown(records.dispose);
    addTearDown(controller.dispose);
    await pumpList(tester, records, controller);
    final firstA = tester
        .widget<Text>(find.byKey(const ValueKey('visual-a')))
        .data;
    records.value = [
      const _Record('c'),
      const _Record('a'),
      const _Record('b'),
      const _Record('d'),
    ];
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final visualBefore = tester
        .getTopLeft(find.byKey(const ValueKey('visual-a')))
        .dy;
    records.value = [
      const _Record('d'),
      const _Record('c'),
      const _Record('b'),
      const _Record('a'),
    ];
    await tester.pump();
    await tester.pump();
    final visualAfter = tester
        .getTopLeft(find.byKey(const ValueKey('visual-a')))
        .dy;
    expect(visualAfter, closeTo(visualBefore, 1));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('visual-a'))).data,
      firstA,
    );
    expect(_RememberedRow.creations, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'new rows preserve visible anchor and a user gesture takes control',
    (tester) async {
      final records = ValueNotifier(List.generate(40, (i) => _Record('r$i')));
      final controller = ScrollController();
      addTearDown(records.dispose);
      addTearDown(controller.dispose);
      await pumpList(tester, records, controller);
      controller.jumpTo(400);
      await tester.pump();
      final anchorBefore = tester
          .getTopLeft(find.byKey(const ValueKey('visual-r5')))
          .dy;
      records.value = [const _Record('new'), ...records.value];
      await tester.pump();
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('visual-r5'))).dy,
        closeTo(anchorBefore, 1),
      );
      expect(controller.offset, closeTo(480, 1));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -150));
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(480));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'departures are inaccessible and rapid reinsertion has one identity',
    (tester) async {
      final records = ValueNotifier([
        const _Record('a'),
        const _Record('b'),
        const _Record('c'),
      ]);
      final controller = ScrollController();
      final semantics = tester.ensureSemantics();
      addTearDown(records.dispose);
      addTearDown(controller.dispose);
      await pumpList(tester, records, controller);
      records.value = [const _Record('a'), const _Record('c')];
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      expect(find.bySemanticsLabel(RegExp(r'^b/')), findsNothing);
      records.value = [const _Record('b'), const _Record('c')];
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('visual-b')), findsOneWidget);
      expect(find.byKey(const ValueKey('visual-a')), findsNothing);
      expect(find.byKey(const ValueKey('visual-c')), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'long histories release unmounted departures before animation completes',
    (tester) async {
      final records = ValueNotifier(
        List.generate(12000, (index) => _Record('r$index')),
      );
      final controller = ScrollController();
      addTearDown(records.dispose);
      addTearDown(controller.dispose);
      await pumpList(tester, records, controller);
      expect(find.byKey(const ValueKey('visual-r0')), findsOneWidget);
      controller.jumpTo(4000);
      await tester.pumpAndSettle();
      // r0 has a historical global key, but its lazy row is already disposed.
      expect(
        find.byKey(const ValueKey('visual-r0'), skipOffstage: false),
        findsNothing,
      );
      final anchor = find.byKey(const ValueKey('visual-r50'));
      final anchorBefore = tester.getTopLeft(anchor).dy;
      final identityBefore = tester.widget<Text>(anchor).data;
      records.value = records.value.sublist(30, 11000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      final delegate =
          tester
                  .widget<SliverList>(
                    find.byWidgetPredicate((w) => w is SliverList),
                  )
                  .delegate
              as SliverChildBuilderDelegate;
      expect(
        delegate.childCount,
        records.value.length,
        reason:
            'Disposed and never-mounted records must release their extents '
            'without waiting for an offscreen departure animation.',
      );
      expect(tester.getTopLeft(anchor).dy, closeTo(anchorBefore, 1));
      expect(tester.widget<Text>(anchor).data, identityBefore);
      // Scrolling into the old region during the same transition cannot
      // resurrect a removed model just to animate a row that never was visible.
      controller.jumpTo(0);
      await tester.pump();
      expect(find.byKey(const ValueKey('visual-r30')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('visual-r0'), skipOffstage: false),
        findsNothing,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mounted cache-buffer departures keep their animation and anchor',
    (tester) async {
      final records = ValueNotifier(
        List.generate(12000, (index) => _Record('r$index')),
      );
      final controller = ScrollController();
      addTearDown(records.dispose);
      addTearDown(controller.dispose);
      await pumpList(tester, records, controller);
      controller.jumpTo(4000);
      await tester.pumpAndSettle();
      final buffered = find.byKey(
        const ValueKey('visual-r47'),
        skipOffstage: false,
      );
      expect(buffered, findsOneWidget);
      expect(tester.getRect(buffered).bottom, lessThan(0));
      final anchor = find.byKey(const ValueKey('visual-r50'));
      final anchorBefore = tester.getTopLeft(anchor).dy;
      final identityBefore = tester.widget<Text>(anchor).data;
      records.value = records.value
          .where((record) => record.id != 'r47')
          .toList();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      final delegate =
          tester
                  .widget<SliverList>(
                    find.byWidgetPredicate((w) => w is SliverList),
                  )
                  .delegate
              as SliverChildBuilderDelegate;
      expect(delegate.childCount, records.value.length + 1);
      expect(buffered, findsOneWidget);
      expect(tester.getTopLeft(anchor).dy, closeTo(anchorBefore, 1));
      expect(tester.widget<Text>(anchor).data, identityBefore);
      await tester.pumpAndSettle();
      expect(buffered, findsNothing);
      expect(
        (tester
                    .widget<SliverList>(
                      find.byWidgetPredicate((w) => w is SliverList),
                    )
                    .delegate
                as SliverChildBuilderDelegate)
            .childCount,
        records.value.length,
      );
      expect(tester.getTopLeft(anchor).dy, closeTo(anchorBefore, 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'variable-height gaps preserve the anchor and both scroll boundaries',
    (tester) async {
      final records = ValueNotifier(
        List.generate(
          12000,
          (index) => _Record('v$index', height: 48 + (index % 5) * 19),
        ),
      );
      final controller = ScrollController();
      addTearDown(records.dispose);
      addTearDown(controller.dispose);
      await pumpList(tester, records, controller);
      controller.jumpTo(12000);
      await tester.pumpAndSettle();
      final anchor = find.byKey(const ValueKey('visual-v140'));
      final anchorBefore = tester.getTopLeft(anchor).dy;
      final identityBefore = tester.widget<Text>(anchor).data;
      final partial = find.byKey(const ValueKey('visual-v139'));
      final partialBefore = tester.getTopLeft(partial).dy;
      final partialIdentity = tester.widget<Text>(partial).data;
      expect(partialBefore, lessThan(0));
      expect(
        tester
            .getRect(
              find.byWidgetPredicate(
                (widget) =>
                    widget is _RememberedRow && widget.record.id == 'v139',
              ),
            )
            .bottom,
        greaterThan(0),
      );
      expect(anchorBefore, greaterThanOrEqualTo(0));
      expect(
        find.byKey(const ValueKey('visual-v0'), skipOffstage: false),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('visual-v400'), skipOffstage: false),
        findsNothing,
      );
      records.value = [
        ...records.value.sublist(80, 400),
        ...records.value.sublist(700),
      ];
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      expect(tester.getTopLeft(anchor).dy, closeTo(anchorBefore, 1));
      expect(tester.widget<Text>(anchor).data, identityBefore);
      expect(tester.getTopLeft(partial).dy, closeTo(partialBefore, 1));
      expect(tester.widget<Text>(partial).data, partialIdentity);
      expect(
        tester
            .widgetList<_RememberedRow>(
              find.byType(_RememberedRow, skipOffstage: false),
            )
            .length,
        lessThan(50),
      );
      // A second change introduces an entirely unmeasured height above the
      // anchor and removes another unmounted gap. No prefix-height estimate
      // may decide where this surviving row appears in the viewport.
      final secondGap = {for (var index = 90; index < 116; index++) 'v$index'};
      records.value = [
        const _Record('unmeasured', height: 217),
        ...records.value.where((record) => !secondGap.contains(record.id)),
      ];
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      expect(tester.getTopLeft(anchor).dy, closeTo(anchorBefore, 1));
      expect(tester.widget<Text>(anchor).data, identityBefore);
      expect(tester.getTopLeft(partial).dy, closeTo(partialBefore, 1));
      expect(tester.widget<Text>(partial).data, partialIdentity);
      final delegate =
          tester
                  .widget<SliverList>(
                    find.byWidgetPredicate((w) => w is SliverList),
                  )
                  .delegate
              as SliverChildBuilderDelegate;
      expect(delegate.childCount, records.value.length);
      controller.jumpTo(0);
      await tester.pumpAndSettle();
      final first = find.byWidgetPredicate(
        (widget) =>
            widget is _RememberedRow && widget.record.id == 'unmeasured',
      );
      final viewport = tester.getRect(find.byType(CustomScrollView));
      expect(tester.getTopLeft(first).dy, closeTo(viewport.top, 1));
      expect(controller.offset, closeTo(0, 1));
      for (var attempt = 0; attempt < 4; attempt++) {
        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pumpAndSettle();
        if (controller.position.extentAfter < 1) break;
      }
      final last = find.byWidgetPredicate(
        (widget) => widget is _RememberedRow && widget.record.id == 'v11999',
      );
      expect(last, findsOneWidget);
      expect(tester.getBottomRight(last).dy, closeTo(viewport.bottom, 1));
      expect(controller.position.extentAfter, lessThan(1));
      expect(
        tester
            .widgetList<_RememberedRow>(
              find.byType(_RememberedRow, skipOffstage: false),
            )
            .length,
        lessThan(50),
      );
      controller.jumpTo(0);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(first).dy, closeTo(viewport.top, 1));
      expect(
        find.byKey(const ValueKey('visual-v0'), skipOffstage: false),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reduced motion updates identities without an animated departure',
    (tester) async {
      final records = ValueNotifier([const _Record('a'), const _Record('b')]);
      final controller = ScrollController();
      addTearDown(records.dispose);
      addTearDown(controller.dispose);
      await pumpList(tester, records, controller, reduced: true);
      records.value = [const _Record('b'), const _Record('c')];
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('visual-a')), findsNothing);
      expect(find.byKey(const ValueKey('visual-b')), findsOneWidget);
      expect(find.byKey(const ValueKey('visual-c')), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets(
    'switching reduced motion during departure stops movement immediately',
    (tester) async {
      final records = ValueNotifier([
        const _Record('a'),
        const _Record('b'),
        const _Record('c'),
      ]);
      final controller = ScrollController();
      addTearDown(records.dispose);
      addTearDown(controller.dispose);
      await pumpList(tester, records, controller);
      records.value = [const _Record('a'), const _Record('c')];
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      await pumpList(tester, records, controller, reduced: true);
      await tester.pump();
      expect(find.byKey(const ValueKey('visual-b')), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('visible anchor notifications are stable and deduplicated', (
    tester,
  ) async {
    final records = ValueNotifier(
      List.generate(40, (index) => _Record('r$index')),
    );
    final controller = ScrollController();
    final anchors = <String>[];
    addTearDown(records.dispose);
    addTearDown(controller.dispose);
    await pumpList(tester, records, controller, onAnchorChanged: anchors.add);
    expect(anchors, ['r0']);
    controller.jumpTo(400);
    await tester.pump();
    expect(anchors.last, 'r5');
    final count = anchors.length;
    controller.jumpTo(410);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(anchors.length, count);
    expect(tester.takeException(), isNull);
  });

  testWidgets('duplicate identity fails explicitly', (tester) async {
    final records = ValueNotifier([const _Record('a'), const _Record('a')]);
    final controller = ScrollController();
    addTearDown(records.dispose);
    addTearDown(controller.dispose);
    await pumpList(tester, records, controller);
    expect(tester.takeException(), isArgumentError);
  });
}
