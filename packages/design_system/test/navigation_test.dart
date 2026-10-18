import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('detail media below the viewport starts only when revealed', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final started = <int>{};
    await tester.pumpWidget(
      MaterialApp(
        theme: DsAppTheme.light(),
        home: DsSliverPage(
          controller: scroll,
          prebuildOffscreen: false,
          slivers: [
            DsSliverSections(
              children: [
                for (var index = 0; index < 3; index++)
                  Builder(
                    builder: (_) {
                      started.add(index);
                      return SizedBox(height: 700, child: Text('Media $index'));
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(started, {0});
    scroll.jumpTo(740);
    await tester.pumpAndSettle();
    expect(started, {0, 1});
    expect(find.text('Media 1').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('page defers unseen sections and keeps visited input state', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    var built = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: DsPage(
          scrollController: scroll,
          children: [
            const TextField(),
            const SizedBox(height: 2000),
            Builder(
              builder: (_) {
                built++;
                return const Text('Last section');
              },
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(built, 0);
    await tester.enterText(find.byType(TextField), 'saved input');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Last section'),
      400,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first,
    );
    expect(built, 1);
    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    expect(find.text('saved input'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final entry in <String, Key>{
    'local': const ValueKey('input'),
    'global': GlobalKey(),
  }.entries) {
    testWidgets(
      'page preserves ${entry.key} keyed input when a section is inserted',
      (tester) async {
        var inserted = false;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            theme: DsAppTheme.light(),
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return DsPage(
                  children: [
                    if (inserted) const DsText('New section'),
                    TextField(key: entry.value),
                  ],
                );
              },
            ),
          ),
        );
        await tester.enterText(find.byType(TextField), 'saved input');
        update(() => inserted = true);
        await tester.pumpAndSettle();
        expect(find.text('saved input'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('route back stays reachable after long scrolling at $scale', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: DsAppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => DsPage(
              title: 'Список',
              children: [
                DsButton(
                  label: 'Открыть операцию',
                  onPressed: () => Navigator.of(context).push(
                    dsRoute<void>(
                      builder: (_) => DsPage(
                        title: 'Детали операции',
                        scrollController: scroll,
                        children: [
                          for (var index = 0; index < 40; index++)
                            DsText('Реквизиты операции $index'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('Открыть операцию'));
      await tester.pumpAndSettle();
      final before = tester.getRect(find.byTooltip('Назад'));
      await tester.scrollUntilVisible(
        find.text('Реквизиты операции 39'),
        500,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(0));
      expect(find.text('Реквизиты операции 39').hitTestable(), findsOneWidget);
      expect(tester.getRect(find.byTooltip('Назад')), before);
      expect(find.byTooltip('Назад').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      expect(find.text('Список'), findsOneWidget);
      expect(find.text('Детали операции'), findsNothing);
    });
  }

  testWidgets('system and toolbar back leave one local step before route', (
    tester,
  ) async {
    var localStep = true;
    var backCount = 0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        theme: DsAppTheme.light(),
        home: Builder(
          builder: (context) => DsPage(
            title: 'Платежи',
            children: [
              DsButton(
                label: 'Открыть',
                onPressed: () => Navigator.of(context).push(
                  dsRoute<void>(
                    builder: (_) => StatefulBuilder(
                      builder: (context, setState) {
                        update = setState;
                        return DsPage(
                          title: localStep ? 'Подтверждение' : 'Данные платежа',
                          onBack: localStep
                              ? () => update(() {
                                  localStep = false;
                                  backCount++;
                                })
                              : null,
                          children: const [DsText('Сохранённый ввод')],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(backCount, 1);
    expect(find.text('Данные платежа'), findsOneWidget);
    expect(find.text('Сохранённый ввод'), findsOneWidget);
    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();
    expect(backCount, 1);
    expect(find.text('Платежи'), findsOneWidget);
  });
}
