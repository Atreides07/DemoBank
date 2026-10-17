import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'font_loader.dart';

void main() {
  setUpAll(loadDsTestFonts);
  for (final density in DsDensity.values) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'wallet $density amount never overlaps actions at text $scale',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(320, 900);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final scroll = ScrollController();
          addTearDown(scroll.dispose);
          await tester.pumpWidget(
            MaterialApp(
              theme: DsAppTheme.light(),
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(320, 900),
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: CustomScrollView(
                    controller: scroll,
                    slivers: [
                      DsCollapsingHeader(
                        density: density,
                        title: 'DemoBank',
                        balance: '1 534 765,80 ₽',
                        child: DsFlow(
                          children: [
                            DsButton(label: 'Оплатить', onPressed: () {}),
                            DsButton(
                              label: 'Аналитика',
                              onPressed: () {},
                              variant: DsButtonVariant.secondary,
                            ),
                          ],
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 1500)),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          final amount = tester.getRect(
            find.byKey(const ValueKey('ds-header-amount')),
          );
          final actions = tester.getRect(find.byType(FilledButton));
          expect(amount.bottom, lessThanOrEqualTo(actions.top));
          expect(find.text('Оплатить').hitTestable(), findsOneWidget);
          expect(find.text('Аналитика').hitTestable(), findsOneWidget);
          final header = tester.widget<SliverPersistentHeader>(
            find.byType(SliverPersistentHeader),
          );
          scroll.jumpTo(
            (header.delegate.maxExtent - header.delegate.minExtent) * .45,
          );
          await tester.pumpAndSettle();
          expect(find.text('Оплатить').hitTestable(), findsNothing);
          expect(find.text('Аналитика').hitTestable(), findsNothing);
          expect(
            find.byKey(const ValueKey('ds-header-amount')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final dark in [false, true]) {
    testWidgets('yellow selection preserves readable contrast dark=$dark', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? DsAppTheme.dark() : DsAppTheme.light(),
          home: DsPage(
            children: [
              DsChoice(label: 'Этот месяц', selected: true, onSelected: (_) {}),
            ],
          ),
        ),
      );
      final style = tester.widget<TextButton>(find.byType(TextButton)).style!;
      final a = style.foregroundColor!.resolve({})!.computeLuminance();
      final b = style.backgroundColor!.resolve({})!.computeLuminance();
      expect(
        (a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05)),
        greaterThanOrEqualTo(4.5),
      );
    });
  }
}
