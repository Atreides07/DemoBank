import 'dart:io';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Load SDK-licensed offline fonts instead of the widget tester's Ahem blocks.
/// Walking the SDK location keeps this test independent of a developer's path.
Future<void> _loadSdkFonts() async {
  var directory = File(Platform.resolvedExecutable).parent;
  Directory? fonts;
  while (directory.parent.path != directory.path) {
    final candidate = Directory(
      '${directory.path}/bin/cache/artifacts/material_fonts',
    );
    if (candidate.existsSync()) {
      fonts = candidate;
      break;
    }
    directory = directory.parent;
  }
  if (fonts == null) throw StateError('Flutter SDK material_fonts not found');
  final roboto = FontLoader('packages/design_system/DsSans');
  for (final weight in ['Regular', 'Medium', 'Bold']) {
    roboto.addFont(
      File('${fonts.path}/Roboto-$weight.ttf').readAsBytes().then(
        (bytes) => ByteData.sublistView(Uint8List.fromList(bytes)),
      ),
    );
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      File('${fonts.path}/MaterialIcons-Regular.otf').readAsBytes().then(
        (bytes) => ByteData.sublistView(Uint8List.fromList(bytes)),
      ),
    );
  await icons.load();
}

void main() {
  setUpAll(_loadSdkFonts);
  for (final variant in ['light', 'dark', 'narrow_large_text']) {
    testWidgets('visual design system $variant', (tester) async {
      final narrow = variant == 'narrow_large_text';
      final size = Size(narrow ? 320 : 430, 1200);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: variant == 'dark' ? DsAppTheme.dark() : DsAppTheme.light(),
          home: RepaintBoundary(
            key: const ValueKey('capture'),
            child: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(narrow ? 2 : 1),
                disableAnimations: true,
              ),
              child: DsPage(
                title: 'Добрый день, Анна',
                subtitle: 'Пятница, 16 октября',
                children: [
                  DsCard(
                    tone: DsCardTone.dark,
                    child: DsColumn(
                      gap: DsSpace.section,
                      children: [
                        const DsMetric(
                          label: 'Общий баланс',
                          value: '320 450,00 ₽',
                          detail: 'На двух счетах · RUB',
                        ),
                        DsButton(
                          label: 'Перевести',
                          onPressed: () {},
                          icon: Icons.arrow_outward_rounded,
                        ),
                      ],
                    ),
                  ),
                  DsSection(
                    title: 'Расходы за октябрь',
                    subtitle: 'Только проведённые покупки',
                    child: DsCard(
                      child: DsColumn(
                        children: [
                          const DsMetric(
                            label: 'Потрачено',
                            value: '42 890 ₽',
                            change: 'На 12% меньше прошлого периода',
                          ),
                          DsBarChart(
                            points: const [
                              DsChartPoint(
                                id: '1',
                                label: '1–7',
                                value: 12400,
                                displayValue: '12 400 ₽',
                              ),
                              DsChartPoint(
                                id: '2',
                                label: '8–14',
                                value: 22100,
                                displayValue: '22 100 ₽',
                              ),
                              DsChartPoint(
                                id: '3',
                                label: '15–16',
                                value: 8390,
                                displayValue: '8 390 ₽',
                              ),
                            ],
                            valueLabel: (value) =>
                                '${(value / 1000).round()} тыс. ₽',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const DsSection(
                    title: 'Последние операции',
                    child: DsColumn(
                      gap: DsSpace.none,
                      children: [
                        DsTransactionTile(
                          title: 'Зелёный маркет',
                          subtitle: 'Продукты · сегодня',
                          value: '−2 490 ₽',
                          icon: Icons.shopping_bag_outlined,
                        ),
                        DsTransactionTile(
                          title: 'Зарплата',
                          subtitle: 'Пополнение · вчера',
                          value: '+180 000 ₽',
                          icon: Icons.south_west_rounded,
                          positive: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('capture')),
        matchesGoldenFile('goldens/design_system_$variant.png'),
      );
    });
  }
}
