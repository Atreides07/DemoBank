import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'font_loader.dart';

void main() {
  setUpAll(loadDsTestFonts);

  testWidgets(
    'a reachable notice preserves reading position at 320px and 200 percent text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final theme = DsAppTheme.light();
      var applied = 0;

      for (final reduced in [false, true]) {
        final controller = ScrollController();
        final showNotice = ValueNotifier(false);
        addTearDown(controller.dispose);
        addTearDown(showNotice.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(320, 900),
                textScaler: const TextScaler.linear(2),
                disableAnimations: reduced,
              ),
              child: Scaffold(
                body: ValueListenableBuilder<bool>(
                  valueListenable: showNotice,
                  builder: (context, visible, child) => DsReadingSurface(
                    notice: visible
                        ? DsNotice(
                            message: 'Есть новые операции. Текущее место чтения сохранено.',
                            action: DsButton(
                              label: 'Показать обновления',
                              onPressed: () {
                                applied++;
                                showNotice.value = false;
                              },
                            ),
                          )
                        : null,
                    child: child!,
                  ),
                  child: CustomScrollView(
                    controller: controller,
                    slivers: [
                      DsLazySliverList(
                        itemCount: 1000,
                        itemBuilder: (context, index) => DsTransactionTile(
                          title: 'Операция $index',
                          subtitle: 'Проведено',
                          value: '100 ₽',
                          icon: DsIcons.receipt,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        controller.jumpTo(600);
        await tester.pump();
        final before = tester.getTopLeft(find.text('Операция 3'));
        showNotice.value = true;
        await tester.pump();

        expect(controller.offset, 600);
        expect(tester.getTopLeft(find.text('Операция 3')), before);
        expect(find.text('Показать обновления').hitTestable(), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.liveRegion == true,
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Показать обновления'));
        await tester.pump();
        expect(controller.offset, 600);
        expect(tester.getTopLeft(find.text('Операция 3')), before);
        expect(find.text('Показать обновления'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
      expect(applied, 2);
    },
  );

  testWidgets(
    'declarative transition page rebuilds from updated route settings',
    (tester) async {
      final label = ValueNotifier('Исходная детализация');
      addTearDown(label.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: DsAppTheme.light(),
          home: ValueListenableBuilder<String>(
            valueListenable: label,
            builder: (context, value, child) => Navigator(
              pages: [
                DsTransitionPage<void>(
                  key: const ValueKey('detail'),
                  name: '/detail',
                  child: Scaffold(body: Text(value)),
                ),
              ],
              onDidRemovePage: (page) {},
            ),
          ),
        ),
      );
      expect(find.text('Исходная детализация'), findsOneWidget);
      label.value = 'Изменённая детализация';
      await tester.pumpAndSettle();
      expect(find.text('Изменённая детализация'), findsOneWidget);
      expect(find.text('Исходная детализация'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
