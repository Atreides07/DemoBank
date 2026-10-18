import 'package:accounts/accounts.dart';
import 'package:app_foundation/app_foundation.dart';
import 'package:app_localizations/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:network_simulation/network_simulation.dart';

const _profile = NetworkProfile(
  name: 'language-race',
  firstByteLatency: Duration(milliseconds: 20),
  jitter: Duration.zero,
  bytesPerSecond: 100000000,
  chunkBytes: 1048576,
);

void main() {
  test('a response that arrives after a language switch is cached under the '
      'language it was requested in', () async {
    final environment = AppEnvironment(
      cache: MemoryCacheStore(),
      journal: MemoryCacheStore(durable: true),
      language: AppLanguage.ru,
      profile: _profile,
    );
    addTearDown(environment.dispose);
    final repository = ApiAccountsRepository(
      environment.api,
      environment.cache,
    );
    Future<List<String>?> cachedNames() async =>
        (await repository.cachedAccounts())?.map((a) => a.name).toList();

    final inFlight = repository.accounts();
    await environment.setLanguage(AppLanguage.en);
    final names = (await inFlight).map((a) => a.name).toList();
    expect(names, contains('Основной счёт'), reason: 'requested in Russian');
    expect(
      await cachedNames(),
      isNull,
      reason: 'Russian names must not be served as English',
    );

    await environment.setLanguage(AppLanguage.ru);
    expect(await cachedNames(), contains('Основной счёт'));
  });
}
