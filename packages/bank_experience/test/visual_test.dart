import 'dart:async';

import 'package:app_foundation/app_foundation.dart';
import 'package:accounts/accounts.dart';
import 'package:bank_experience/bank_experience.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:network_simulation/network_simulation.dart';

Future<void> _loadFonts() async {
  final family = FontLoader('packages/design_system/DsSans');
  for (final weight in ['Regular', 'Medium', 'Bold']) {
    family.addFont(
      rootBundle.load('packages/design_system/assets/fonts/Roboto-$weight.ttf'),
    );
  }
  await family.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

Future<void> _advanceNetwork(WidgetTester tester) async {
  // Advance the test clock, not a real sleep. This is deliberately bounded:
  // the catalog includes an always-loading component demonstration.
  for (var tick = 0; tick < 16; tick++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _awaitArtwork(WidgetTester tester) async {
  final elements = tester.elementList(find.byType(Image)).toList();
  await tester.runAsync(() async {
    await Future.wait(
      elements.map((element) async {
        final image = element.widget as Image;
        final stream = image.image.resolve(
          createLocalImageConfiguration(element),
        );
        final ready = Completer<void>();
        final listener = ImageStreamListener(
          (_, _) => ready.complete(),
          onError: (error, stack) => ready.completeError(error, stack),
        );
        stream.addListener(listener);
        try {
          await ready.future;
        } finally {
          stream.removeListener(listener);
        }
      }),
    );
  });
  await tester.pump();
}

Finder _navigation(String label) => find.descendant(
  of: find.byType(DsNavigationBar),
  matching: find.text(label),
);

AppEnvironment _environment({
  NetworkProfile profile = NetworkProfile.normal,
  bool dark = false,
}) => AppEnvironment(
  cache: MemoryCacheStore(),
  journal: MemoryCacheStore(),
  simulation: SimulationAdapter(
    profile: profile,
    scheduler: RealSimulationScheduler(),
  ),
)..theme = dark ? ThemeMode.dark : ThemeMode.light;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  for (final variant in ['light_phone', 'dark_phone', 'narrow_large_text']) {
    testWidgets('bank home, analytics and catalog render $variant', (
      tester,
    ) async {
      // Golden captures must show the real physical shadow, rather than the
      // testing binding's diagnostic elevation outline.
      final previousShadows = debugDisableShadows;
      debugDisableShadows = false;
      try {
        final narrow = variant == 'narrow_large_text';
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = narrow
            ? const Size(320, 1000)
            : variant == 'light_phone'
            ? const Size(360, 720)
            : const Size(390, 1000);
        tester.platformDispatcher.textScaleFactorTestValue = narrow ? 2 : 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final environment = _environment(dark: variant == 'dark_phone')
          ..reduceMotion = true;
        addTearDown(environment.dispose);
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('bank-capture'),
            child: BankExperience(environment: environment),
          ),
        );
        await _advanceNetwork(tester);
        await _awaitArtwork(tester);
        expect(tester.takeException(), isNull);
        expect(find.byType(DsHomeHeader), findsOneWidget);
        if (!narrow) expect(find.text('Основной счёт'), findsOneWidget);
        expect(find.text('Загружаем операции'), findsNothing);
        await expectLater(
          find.byKey(const ValueKey('bank-capture')),
          matchesGoldenFile('goldens/home_$variant.png'),
        );

        final primary = find.byKey(const ValueKey('home-account-main'));
        final homeController = tester
            .widget<CustomScrollView>(find.byKey(const PageStorageKey('home')))
            .controller!;
        for (var step = 0; step < 15 && primary.evaluate().isEmpty; step++) {
          homeController.jumpTo(
            (homeController.offset + 300).clamp(
              0,
              homeController.position.maxScrollExtent,
            ),
          );
          await tester.pumpAndSettle();
        }
        await Scrollable.ensureVisible(tester.element(primary), alignment: .5);
        await tester.pumpAndSettle();
        await tester.tap(primary);
        await _advanceNetwork(tester);
        await _awaitArtwork(tester);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey('bank-capture')),
          matchesGoldenFile('goldens/account_$variant.png'),
        );
        final dashboard = tester.widget<AccountDashboard>(
          find.byType(AccountDashboard),
        );
        final header = tester.widget<SliverPersistentHeader>(
          find.descendant(
            of: find.byType(AccountDashboard),
            matching: find.byType(SliverPersistentHeader),
          ),
        );
        dashboard.scrollController.jumpTo(
          header.delegate.maxExtent - header.delegate.minExtent,
        );
        await tester.pumpAndSettle();
        await _awaitArtwork(tester);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey('bank-capture')),
          matchesGoldenFile('goldens/account_collapsed_$variant.png'),
        );
        await tester.tap(find.byTooltip('Назад'));
        await tester.pumpAndSettle();

        await tester.tap(_navigation('Аналитика'));
        await _advanceNetwork(tester);
        await _awaitArtwork(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('Расходы за период'), findsOneWidget);
        await expectLater(
          find.byKey(const ValueKey('bank-capture')),
          matchesGoldenFile('goldens/analytics_$variant.png'),
        );
        await tester.ensureVisible(find.byType(DsBarChart));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey('bank-capture')),
          matchesGoldenFile('goldens/chart_$variant.png'),
        );

        await tester.tap(_navigation('Платежи'));
        await _advanceNetwork(tester);
        await _awaitArtwork(tester);
        expect(find.byType(DsServiceCard), findsNWidgets(4));
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey('bank-capture')),
          matchesGoldenFile('goldens/services_$variant.png'),
        );

        await tester.tap(_navigation('Профиль'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.ensureVisible(find.text('Дизайн-система'));
        await tester.tap(find.text('Дизайн-система'));
        await _advanceNetwork(tester);
        await _awaitArtwork(tester);
        expect(
          find.text('Компоненты, состояния и рабочие экраны'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey('bank-capture')),
          matchesGoldenFile('goldens/catalog_$variant.png'),
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        environment.dispose();
        await tester.pump();
      } finally {
        debugDisableShadows = previousShadows;
      }
    });
  }

  testWidgets('slow network leaves navigation interactive while data streams', (
    tester,
  ) async {
    final environment = _environment(profile: NetworkProfile.slow);
    addTearDown(environment.dispose);
    await tester.pumpWidget(BankExperience(environment: environment));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      environment.simulation.events.any((event) => event.phase == 'started'),
      true,
    );
    expect(
      environment.simulation.events.any((event) => event.phase == 'completed'),
      false,
    );
    await tester.tap(_navigation('Платежи'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Повседневные дела в одном месте'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    environment.dispose();
    await tester.pump();
  });

  testWidgets('offline failures retain working navigation and retry actions', (
    tester,
  ) async {
    final environment = _environment(profile: NetworkProfile.offline);
    addTearDown(environment.dispose);
    await tester.pumpWidget(BankExperience(environment: environment));
    await _advanceNetwork(tester);
    expect(find.text('Повторить'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.tap(_navigation('Платежи'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Повседневные дела в одном месте'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    environment.dispose();
    await tester.pump();
  });
}
