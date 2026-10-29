import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'font_loader.dart';

void main() {
  setUpAll(loadDsTestFonts);

  testWidgets(
    'paired action surfaces share a row height without clipping content',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: DsAppTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: DsActionGrid(
                children: [
                  for (final height in [80.0, 140.0, 100.0])
                    DsPanel(
                      key: ValueKey(height),
                      child: LayoutBuilder(
                        builder: (_, _) => SizedBox(height: height),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      final first = tester.getRect(find.byKey(const ValueKey(80.0)));
      final second = tester.getRect(find.byKey(const ValueKey(140.0)));
      final third = tester.getRect(find.byKey(const ValueKey(100.0)));
      expect(first.height, second.height);
      expect(first.right, lessThan(second.left));
      expect(third.top, greaterThan(second.bottom));
      expect(third.height, greaterThanOrEqualTo(100));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a panel shortcut responds across its entire visible surface', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: DsAppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 180,
            child: DsShortcutBar(
              panel: true,
              actions: [DsShortcut('Пополнить', DsIcons.add, () => taps++)],
            ),
          ),
        ),
      ),
    );
    final surface = tester.getRect(find.byType(DsPanel));
    await tester.tapAt(surface.bottomCenter - const Offset(0, 4));
    expect(taps, 1);
    final button = find.bySemanticsLabel('Пополнить');
    expect(button, findsOneWidget);
    expect(
      tester
          .getSemantics(button)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    semantics.dispose();
  });
}
