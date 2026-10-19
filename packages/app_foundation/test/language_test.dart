import 'package:app_foundation/app_foundation.dart';
import 'package:app_localizations/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:network_simulation/network_simulation.dart';

const _fastProfile = NetworkProfile(
  name: 'local-test',
  firstByteLatency: Duration.zero,
  jitter: Duration.zero,
  bytesPerSecond: 100000000,
  chunkBytes: 1048576,
);

AppEnvironment _environment({
  CacheStore? preferences,
  CacheStore? cache,
  List<Locale> systemLocales = const [Locale('ru')],
}) {
  final environment = AppEnvironment(
    cache: cache ?? MemoryCacheStore(),
    journal: MemoryCacheStore(durable: true),
    preferences: preferences,
    systemLocales: systemLocales,
    profile: _fastProfile,
  );
  addTearDown(environment.dispose);
  return environment;
}

void main() {
  test('the first supported device language is used, otherwise Russian', () {
    expect(
      _environment(systemLocales: const [Locale('de'), Locale('uz', 'UZ')])
          .language,
      AppLanguage.uz,
    );
    expect(
      _environment(systemLocales: const [Locale('en', 'GB')]).language,
      AppLanguage.en,
    );
    expect(
      _environment(systemLocales: const [Locale('de')]).language,
      AppLanguage.ru,
    );
  });

  test('a chosen language survives a restart and can follow the device '
      'again', () async {
    final preferences = MemoryCacheStore(durable: true);
    final first = _environment(
      preferences: preferences,
      systemLocales: const [Locale('en')],
    );
    await first.setLanguage(AppLanguage.uz);
    expect(first.language, AppLanguage.uz);
    expect(first.api.acceptLanguage, 'uz');

    final restarted = _environment(
      preferences: preferences,
      systemLocales: const [Locale('en')],
    );
    expect(restarted.language, AppLanguage.en);
    await restarted.restorePreferences();
    expect(restarted.chosenLanguage, AppLanguage.uz);
    expect(restarted.locale, const Locale('uz'));
    expect(restarted.api.acceptLanguage, 'uz');

    await restarted.setLanguage(null);
    expect(restarted.language, AppLanguage.en);
    final again = _environment(
      preferences: preferences,
      systemLocales: const [Locale('en')],
    );
    await again.restorePreferences();
    expect(again.chosenLanguage, isNull);
  });

  test('a language change is announced once and device changes are '
      'followed only without an explicit choice', () async {
    final environment = _environment(systemLocales: const [Locale('ru')]);
    var notifications = 0;
    environment.addListener(() => notifications++);
    final revision = environment.languageRevision;

    environment.updateSystemLocales(const [Locale('en')]);
    expect(environment.language, AppLanguage.en);
    expect(environment.languageRevision, revision + 1);

    await environment.setLanguage(AppLanguage.en);
    expect(environment.languageRevision, revision + 1, reason: 'unchanged');

    environment.updateSystemLocales(const [Locale('uz')]);
    expect(environment.language, AppLanguage.en, reason: 'explicit choice');
    expect(notifications, greaterThanOrEqualTo(3));
  });

  test('cached server responses are kept per content language', () async {
    final environment = _environment(systemLocales: const [Locale('ru')]);
    await environment.cache.write('accounts', {'name': 'Основной счёт'});
    await environment.setLanguage(AppLanguage.en);
    expect(await environment.cache.read('accounts'), isNull);
    await environment.cache.write('accounts', {'name': 'Main account'});
    await environment.setLanguage(AppLanguage.ru);
    expect(
      (await environment.cache.read('accounts'))!.value['name'],
      'Основной счёт',
    );
    await environment.clearCache();
    await environment.setLanguage(AppLanguage.en);
    expect(await environment.cache.read('accounts'), isNull);
  });

  test('the backend answers in the chosen language', () async {
    final environment = _environment(systemLocales: const [Locale('ru')]);
    Future<List<String>> names() async =>
        ((await environment.api.get('/v1/accounts'))['accounts'] as List)
            .map((account) => (account as Map)['name'] as String)
            .toList();
    expect(await names(), contains('Основной счёт'));
    await environment.setLanguage(AppLanguage.en);
    expect(await names(), containsAll(['Main account', 'UZS account']));
    await environment.setLanguage(AppLanguage.uz);
    expect(await names(), containsAll(['Asosiy hisob', 'Soʻm hisobi']));
  });
}
