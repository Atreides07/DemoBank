import 'package:app_foundation/app_foundation.dart';
import 'package:app_localizations/app_localizations.dart';
import 'package:bank_experience/bank_experience.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:local_storage/local_storage.dart';

final _cyrillic = RegExp('[Ѐ-ӿ]');

Future<void> _ready(WidgetTester tester) async {
  for (var n = 0; n < 24; n++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(tester.takeException(), isNull);
}

Future<AppEnvironment> _open(WidgetTester tester, AppLanguage language) async {
  final environment = AppEnvironment(
    cache: MemoryCacheStore(),
    journal: MemoryCacheStore(),
    language: language,
  )..reduceMotion = true;
  addTearDown(environment.dispose);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 2400);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(BankExperience(environment: environment));
  await _ready(tester);
  return environment;
}

/// Texts of every built text widget, including those scrolled out of view,
/// and whole amounts, which are laid out in several pieces but announced as
/// one label.
List<String> _texts(WidgetTester tester) => [
  for (final element
      in find
          .byWidgetPredicate(
            (widget) =>
                widget is Text ||
                widget is RichText ||
                widget is Semantics && widget.properties.label != null,
            skipOffstage: false,
          )
          .evaluate())
    switch (element.widget) {
      final Text text => text.data ?? text.textSpan?.toPlainText() ?? '',
      final RichText text => text.text.toPlainText(),
      final Semantics semantics => semantics.properties.label!,
      _ => '',
    },
];

const _nbsp = '\u00a0';

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(DsHomeHeader, skipOffstage: false)));

const _routes = [
  '/',
  '/analytics',
  '/services',
  '/profile',
  '/language',
  '/account/main',
  '/account/uzs',
  '/account/main/limits',
  '/account/main/requisites',
  '/account/main/pay',
  '/account/main/topup',
  '/history',
  '/drill',
  '/pay/mobile',
  '/pay/cinema',
  '/pay/fines',
  '/pay/utilities',
  '/discover/gift',
  '/discover/travel',
  '/cart',
  '/search',
  '/scan',
  '/environment',
  '/catalog',
];

void main() {
  for (final language in [AppLanguage.en, AppLanguage.uz]) {
    testWidgets('${language.code}: no screen shows Russian text', (
      tester,
    ) async {
      await _open(tester, language);
      final router = _router(tester);
      for (final route in _routes) {
        router.go(route);
        await _ready(tester);
        for (final text in _texts(tester)) {
          // The language picker names each language in itself.
          final checked = text.replaceAll(AppLanguage.ru.nativeName, '');
          expect(_cyrillic.hasMatch(checked), isFalse, reason: '$route: $text');
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('amounts follow the interface language', (tester) async {
    await _open(tester, AppLanguage.en);
    final texts = _texts(tester);
    expect(texts.any(RegExp(r'^₽\d{1,3}(,\d{3})*(\.\d\d)?$').hasMatch), isTrue);
    expect(texts.any((text) => text.startsWith('UZS$_nbsp')), isTrue);
    expect(texts, contains('UZS account'));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('switching the language replaces interface and server texts at '
      'once', (tester) async {
    final environment = await _open(tester, AppLanguage.ru);
    expect(find.text('Главная'), findsOneWidget);
    expect(find.text('Основной счёт', skipOffstage: false), findsWidgets);
    expect(find.text('Сумовый счёт', skipOffstage: false), findsOneWidget);

    await environment.setLanguage(AppLanguage.uz);
    await _ready(tester);
    expect(find.text('Bosh sahifa'), findsOneWidget);
    expect(find.text('Asosiy hisob', skipOffstage: false), findsWidgets);
    expect(find.text('Soʻm hisobi', skipOffstage: false), findsOneWidget);
    expect(
      find.textContaining('${_nbsp}soʻm', skipOffstage: false),
      findsWidgets,
    );
    final history = _texts(tester).where(_cyrillic.hasMatch).toList();
    expect(history, isEmpty, reason: 'server texts still in Russian');

    await environment.setLanguage(AppLanguage.ru);
    await _ready(tester);
    expect(find.text('Главная'), findsOneWidget);
    expect(find.byType(DsHomeHeader), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
