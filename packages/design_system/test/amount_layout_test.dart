import 'package:design_system/design_system.dart';
import 'package:design_system/src/amount.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'font_loader.dart';

const _nbsp = ' ';

/// Long balances as each interface language writes them.
const _amounts = {
  'ru': '1${_nbsp}234${_nbsp}567${_nbsp}890,55$_nbsp₽',
  'en': '₽1,234,567,890.55',
  'en sum': 'UZS${_nbsp}12,750,000,000',
  'uz sum': '12${_nbsp}750${_nbsp}000${_nbsp}000${_nbsp}soʻm',
};

void _expectFits(WidgetTester tester, Finder within, String reason) {
  final paragraphs = find.descendant(
    of: within,
    matching: find.byType(RichText),
  );
  expect(paragraphs, findsWidgets, reason: reason);
  final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
  for (final element in paragraphs.evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    expect(
      paragraph.getMaxIntrinsicWidth(double.infinity),
      lessThanOrEqualTo(paragraph.size.width + 0.5),
      reason: '$reason: "${paragraph.text.toPlainText()}" is clipped',
    );
    final right = paragraph.localToGlobal(Offset(paragraph.size.width, 0)).dx;
    expect(right, lessThanOrEqualTo(screen.width + 0.5), reason: reason);
  }
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(320, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: DsAppTheme.light(),
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 900),
          textScaler: TextScaler.linear(2),
        ),
        child: Scaffold(body: child),
      ),
    ),
  );
  await tester.pump();
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(loadDsTestFonts);

  group('pieces', () {
    test('break between digit groups whatever the grouping symbol', () {
      expect(DsAmountLayout.pieces('₽1,250,000.00'), ['₽1,', '250,', '000.00']);
      expect(DsAmountLayout.pieces('1 250 000,00 ₽'), [
        '1 ',
        '250 ',
        '000,00 ₽',
      ]);
    });

    test('keep a currency word with its digits', () {
      expect(DsAmountLayout.pieces('UZS${_nbsp}12,750,000'), [
        'UZS${_nbsp}12,',
        '750,',
        '000',
      ]);
      expect(DsAmountLayout.pieces('12${_nbsp}750${_nbsp}soʻm'), [
        '12$_nbsp',
        '750${_nbsp}soʻm',
      ]);
    });

    test('never split a decimal comma from its cents', () {
      expect(DsAmountLayout.pieces('124,80 ₽'), ['124,80 ₽']);
      expect(DsAmountLayout.pieces('−₽12.50'), ['−₽12.50']);
    });

    test('lose no character', () {
      for (final amount in _amounts.values) {
        expect(DsAmountLayout.pieces(amount).join(), amount);
      }
    });
  });

  for (final MapEntry(key: name, value: amount) in _amounts.entries) {
    testWidgets('$name: a long amount fits 320 pt at 200 percent', (
      tester,
    ) async {
      await _pump(
        tester,
        Padding(
          padding: const EdgeInsets.all(16),
          child: DsMoneyText(amount, key: const ValueKey('money')),
        ),
      );
      _expectFits(tester, find.byKey(const ValueKey('money')), name);
      expect(find.bySemanticsLabel(amount), findsOneWidget);
    });

    testWidgets('$name: the pinned balance header fits 320 pt at 200 percent', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await _pump(
        tester,
        CustomScrollView(
          controller: controller,
          slivers: [
            DsCollapsingHeader(
              title: 'DemoBank',
              balance: amount,
              label: 'Total balance',
              subtitle: 'Balance',
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 2000)),
          ],
        ),
      );
      final header = find.byKey(const ValueKey('ds-header-amount'));
      _expectFits(tester, header, name);
      controller.jumpTo(500);
      await tester.pump();
      expect(tester.takeException(), isNull);
      _expectFits(tester, header, '$name collapsed');
    });
  }
}
