import 'package:app_foundation/app_foundation.dart';
import 'package:bank_experience/bank_experience.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';

Future<void> _ready(WidgetTester tester) async {
  for (var n = 0; n < 30; n++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    final font = FontLoader('packages/design_system/DsSans');
    for (final weight in ['Regular', 'Medium', 'Bold']) {
      font.addFont(
        rootBundle.load(
          'packages/design_system/assets/fonts/Roboto-$weight.ttf',
        ),
      );
    }
    await font.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final size in [
    const Size(360, 780),
    const Size(320, 640),
    const Size(390, 844),
  ]) {
    testWidgets(
      'reference home $size exposes overview, shortcuts and primary account',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final environment = AppEnvironment(
          cache: MemoryCacheStore(),
          journal: MemoryCacheStore(),
        )..reduceMotion = true;
        addTearDown(environment.dispose);
        await tester.pumpWidget(BankExperience(environment: environment));
        await _ready(tester);
        final finder = find.byKey(const PageStorageKey('home'));
        final home = tester.widget<CustomScrollView>(finder);
        expect(home.controller!.offset, 0);
        expect(
          find.byKey(const ValueKey('home-operations')).hitTestable(),
          findsOneWidget,
        );
        expect(find.text('Перевести').hitTestable(), findsOneWidget);
        expect(find.text('Пополнить').hitTestable(), findsOneWidget);
        expect(find.text('Сканировать').hitTestable(), findsOneWidget);
        final account = find.byKey(const ValueKey('home-account-main'));
        final bottom = tester.getTopLeft(find.byType(DsNavigationBar)).dy;
        expect(
          tester.getTopLeft(account).dy,
          lessThan(bottom),
          reason: 'Account must begin above navigation',
        );
        final header = tester.widget<SliverPersistentHeader>(
          find.byType(SliverPersistentHeader),
        );
        expect(
          header.delegate.maxExtent - header.delegate.minExtent,
          greaterThan(40),
        );
        final searchTop = tester.getTopLeft(find.text('Поиск')).dy;
        home.controller!.jumpTo(
          header.delegate.maxExtent - header.delegate.minExtent,
        );
        await tester.pump();
        expect(find.text('Поиск').hitTestable(), findsNothing);
        expect(find.byTooltip('Поиск по банку').hitTestable(), findsOneWidget);
        home.controller!.jumpTo(0);
        await tester.pump();
        expect(tester.getTopLeft(find.text('Поиск')).dy, searchTop);
        if (account.hitTestable().evaluate().isEmpty) {
          await tester.ensureVisible(account);
          await tester.pump();
        }
        final beforeOpen = home.controller!.offset;
        await tester.tap(account);
        await _ready(tester);
        expect(find.byType(DsAccountHeader), findsOneWidget);
        expect(find.byTooltip('Назад').hitTestable(), findsOneWidget);
        await tester.tap(find.byTooltip('Назад'));
        await tester.pumpAndSettle();
        expect(home.controller!.offset, beforeOpen);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }
}
