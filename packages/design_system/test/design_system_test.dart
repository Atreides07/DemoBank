import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'font_loader.dart';

void main() {
  setUpAll(loadDsTestFonts);
  testWidgets('loading motion does not repaint the static status surface', (
    tester,
  ) async {
    var paints = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: DsAppTheme.light(),
        home: Scaffold(
          body: RepaintBoundary(
            child: CustomPaint(
              painter: _PaintCounter(() => paints++),
              child: const DsStatus(
                title: 'Обновляем выборку',
                kind: DsStatusKind.loading,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final staticPaints = paints;
    await tester.pump(const Duration(milliseconds: 200));
    expect(paints, staticPaints);
  });
  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'semantic composition: dark=$dark, text=$scale, narrow screen',
        (tester) async {
          tester.view.physicalSize = const Size(320, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? DsAppTheme.dark() : DsAppTheme.light(),
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(320, 1000),
                  textScaler: TextScaler.linear(scale),
                ),
                child: DsPage(
                  title: 'Платежи и операции',
                  subtitle:
                      'Длинное пояснение помогает проверить реальную компоновку',
                  bottomNavigation: DsNavigationBar(
                    destinations: const [
                      DsDestination(label: 'Главная', icon: Icons.home),
                      DsDestination(label: 'Платежи', icon: Icons.payments),
                    ],
                    selectedIndex: 0,
                    onSelected: (_) {},
                  ),
                  children: [
                    const DsCard(
                      child: DsMetric(
                        label: 'Расходы за период',
                        value: '128 456,78 ₽',
                        change: 'На 12% меньше',
                        detail: 'Сравнение с таким же периодом',
                      ),
                    ),
                    DsSection(
                      title: 'История операций с длинным названием',
                      action: DsButton(
                        label: 'Все операции',
                        onPressed: () {},
                        variant: DsButtonVariant.quiet,
                      ),
                      child: const DsTransactionTile(
                        title: 'Магазин товаров для дома и ремонта',
                        subtitle: 'Покупка · сегодня, 14:35',
                        value: '−12 499 ₽',
                        icon: Icons.home_outlined,
                      ),
                    ),
                    DsCard(
                      child: DsColumn(
                        children: [
                          const DsField(
                            label: 'Лицевой счёт',
                            hint: 'Введите номер',
                          ),
                          DsButton(
                            label: 'Продолжить безопасную оплату',
                            onPressed: () {},
                            icon: Icons.lock_outline,
                          ),
                          DsButton(label: 'Недоступно', onPressed: null),
                          DsCheckbox(
                            label: 'Сохранить реквизиты для следующего платежа',
                            value: true,
                            onChanged: (_) {},
                          ),
                          DsChoice(
                            label: 'Очень длинная категория расходов',
                            selected: true,
                            onSelected: (_) {},
                          ),
                        ],
                      ),
                    ),
                    const DsStatus(
                      title: 'Платёж завершён',
                      message: 'Квитанция доступна в истории',
                      kind: DsStatusKind.success,
                    ),
                    const DsPaymentSummary(
                      title: 'Подтверждение платежа',
                      amount: '4 200 ₽',
                      details: [
                        DsDetail(
                          'Получатель',
                          'Управляющая компания «Новый квартал»',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(find.text('Платежи и операции'), findsOneWidget);
        },
      );
    }
  }

  testWidgets(
    'chart exact values, text alternative and action preserve identity',
    (tester) async {
      DsChartPoint? selected;
      const points = [
        DsChartPoint(
          id: 'day-1',
          label: '1 окт',
          value: 0,
          displayValue: '0 ₽',
        ),
        DsChartPoint(
          id: 'day-2',
          label: '2 окт',
          value: 12499,
          displayValue: '124,99 ₽',
          detail: '2 операции',
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: DsAppTheme.light(),
          home: DsPage(
            children: [
              DsBarChart(
                points: points,
                onSelected: (point) => selected = point,
              ),
              const DsRankedBars(points: points),
            ],
          ),
        ),
      );
      await tester.tap(find.text('2 окт').first);
      await tester.pumpAndSettle();
      expect(selected?.id, 'day-2');
      expect(find.text('2 окт: 124,99 ₽ · 2 операции'), findsOneWidget);
      await tester.tap(find.text('Все значения списком'));
      await tester.pumpAndSettle();
      expect(find.text('Показать график'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DsBarChart),
          matching: find.text('124,99 ₽'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 1.3, 1.5, 2.0]) {
    testWidgets('transaction rhythm and full semantics at text $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      const title = 'Магазин товаров для дома и ремонта';
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: DsAppTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    DsTransactionTile(
                      title: title,
                      subtitle: 'Покупки · Проведено',
                      value: '−12 499,90 ₽',
                      icon: DsIcons.shopping,
                      onTap: () => opened = true,
                    ),
                    const DsTransactionPlaceholder(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      try {
        expect(
          find.bySemanticsLabel('$title, Покупки · Проведено, −12 499,90 ₽'),
          findsOneWidget,
        );
      } finally {
        semantics.dispose();
      }
      final row = tester.getRect(find.byType(DsTransactionTile));
      expect(row.height, greaterThanOrEqualTo(48));
      if (scale == 1) expect(row.height, lessThanOrEqualTo(72));
      expect(
        tester.getTopLeft(find.byType(DsTransactionPlaceholder)).dy,
        row.bottom,
      );
      expect(
        tester.getSize(find.byType(DsTransactionPlaceholder)).height,
        row.height,
      );
      for (final child in [find.text(title), find.byType(DsMoneyText)]) {
        final rect = tester.getRect(child);
        expect(rect.top, greaterThanOrEqualTo(row.top));
        expect(rect.bottom, lessThanOrEqualTo(row.bottom));
      }
      await tester.tap(find.byType(DsTransactionTile));
      expect(opened, true);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('slot geometry matches evicted row at both text scales', (
    tester,
  ) async {
    for (final scale in [1.0, 2.0]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: DsAppTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: const Scaffold(
              body: Column(
                children: [
                  DsTransactionTile(
                    key: ValueKey('loaded'),
                    title: 'Операция',
                    subtitle: 'Сегодня',
                    value: '100 ₽',
                    icon: Icons.wallet,
                  ),
                  DsTransactionPlaceholder(key: ValueKey('placeholder')),
                ],
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('loaded'))).height,
        tester.getSize(find.byKey(const ValueKey('placeholder'))).height,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'scroll-coupled header collapses and expands with continuous gesture',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: DsAppTheme.light(),
          home: Scaffold(
            body: CustomScrollView(
              controller: controller,
              slivers: [
                const DsCollapsingHeader(
                  title: 'DemoBank',
                  balance: '320 450 ₽',
                  subtitle: 'Доступно на всех счетах',
                ),
                DsLazySliverList(
                  itemCount: 100,
                  itemBuilder: (_, index) => const DsTransactionPlaceholder(),
                ),
              ],
            ),
          ),
        ),
      );
      double extent() => tester
          .renderObject<RenderSliver>(find.byType(DsCollapsingHeader))
          .geometry!
          .paintExtent;
      final initial = extent();
      controller.jumpTo(200);
      await tester.pump();
      final collapsed = extent();
      expect(collapsed, lessThan(initial));
      controller.jumpTo(0);
      await tester.pump();
      expect(extent(), initial);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pinned header keeps the full amount at 200 percent on narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      const amount = '320 450,00 ₽';
      await tester.pumpWidget(
        MaterialApp(
          theme: DsAppTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 800),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: CustomScrollView(
                controller: controller,
                slivers: [
                  const DsCollapsingHeader(
                    title: 'DemoBank',
                    balance: amount,
                    subtitle: 'Доступно на всех счетах',
                  ),
                  DsLazySliverList(
                    itemCount: 100,
                    itemBuilder: (_, index) => const DsTransactionPlaceholder(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      void checkAmount() {
        final fraction = find.descendant(
          of: find.byKey(const ValueKey('ds-header-amount')),
          matching: find.text('450,00 ₽'),
        );
        expect(fraction, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(fraction);
        expect(
          paragraph.getMaxIntrinsicWidth(0),
          lessThanOrEqualTo(paragraph.constraints.maxWidth),
        );
        expect(paragraph.didExceedMaxLines, false);
      }

      checkAmount();
      controller.jumpTo(500);
      await tester.pump();
      checkAmount();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'narrow large text keeps headlines and full multiline choices readable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      const headline = 'Аналитика трат';
      const account = 'Накопительный счёт';
      var selected = false;
      for (final dark in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? DsAppTheme.dark() : DsAppTheme.light(),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 900),
                textScaler: TextScaler.linear(2),
              ),
              child: DsPage(
                title: headline,
                children: [
                  DsFlow(
                    children: [
                      DsChoice(
                        label: account,
                        selected: false,
                        onSelected: (value) => selected = value,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final heading = tester.renderObject<RenderParagraph>(
          find.text(headline),
        );
        final wordBoxes = heading.getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 9),
        );
        expect(
          wordBoxes.map((box) => box.top).toSet(),
          hasLength(1),
          reason: 'A headline word must not be split into separate lines.',
        );
        expect(heading.text.toPlainText(), headline);

        final label = tester.renderObject<RenderParagraph>(find.text(account));
        final labelBoxes = label.getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: account.length),
        );
        expect(label.didExceedMaxLines, false);
        expect(labelBoxes.map((box) => box.top).toSet().length, greaterThan(1));
        expect(labelBoxes.every((box) => box.right <= label.size.width), true);
        expect(
          labelBoxes.every((box) => box.bottom <= label.size.height),
          true,
          reason:
              'The chip must grow to contain every line, not paint the second line outside its surface.',
        );
        expect(find.bySemanticsLabel(account), findsOneWidget);
        await tester.tap(find.text(account));
        expect(selected, true);
        expect(tester.takeException(), isNull);
      }
      semantics.dispose();
    },
  );

  testWidgets('DS semantics expose financial values and controls', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: DsAppTheme.dark(),
        home: DsPage(
          children: [
            DsTransactionTile(
              title: 'Кофейня',
              subtitle: 'Еда',
              value: '−300 ₽',
              icon: Icons.coffee,
              onTap: () {},
            ),
            const DsStatus(title: 'Нет операций', kind: DsStatusKind.empty),
          ],
        ),
      ),
    );
    expect(find.bySemanticsLabel('Кофейня, Еда, −300 ₽'), findsOneWidget);
    semantics.dispose();
  });
}

class _PaintCounter extends CustomPainter {
  _PaintCounter(this.onPaint);
  final VoidCallback onPaint;
  @override
  void paint(Canvas canvas, Size size) => onPaint();
  @override
  bool shouldRepaint(_PaintCounter oldDelegate) => false;
}
