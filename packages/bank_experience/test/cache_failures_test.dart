import 'package:accounts/accounts.dart';
import 'package:app_foundation/app_foundation.dart';
import 'package:bank_core/bank_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:network_simulation/network_simulation.dart';
import 'package:spending_analytics/spending_analytics.dart';
import 'package:transactions/transactions.dart';

final class _InstantScheduler implements SimulationScheduler {
  @override
  Duration get elapsed => Duration.zero;
  @override
  Future<void> delay(
    Duration duration,
    SimulationCancellation cancellation,
  ) async => cancellation.throwIfCancelled();
}

final class _FailingWrites implements CacheStore {
  final store = MemoryCacheStore();
  int writes = 0;
  bool failReads = false;
  @override
  Future<CacheEntry?> read(String key) {
    if (failReads) throw StateError('storage unavailable');
    return store.read(key);
  }

  @override
  Future<void> write(
    String key,
    Map<String, dynamic> value, {
    Duration ttl = const Duration(minutes: 5),
    String? revision,
  }) async {
    writes++;
    throw StateError('disk full');
  }

  @override
  Future<void> delete(String key) => store.delete(key);
  @override
  Future<String?> quarantine(String key) => store.quarantine(key);
  @override
  Future<void> clear() => store.clear();
  @override
  Future<void> expireAll() => store.expireAll();
  @override
  Future<void> close() => store.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('response cache write failures preserve server reads and saved preferences', () async {
    final cache = _FailingWrites();
    final environment = AppEnvironment(
      cache: cache,
      journal: MemoryCacheStore(durable: true),
      simulation: SimulationAdapter(scheduler: _InstantScheduler()),
    );
    addTearDown(environment.dispose);
    final accounts = await ApiAccountsRepository(
      environment.api,
      environment.cache,
    ).accounts();
    final account = accounts.first;
    final profile = ApiAccountManagement(environment.api, environment.cache);
    addTearDown(profile.close);
    expect((await profile.profile(account.id)).id, account.id);
    final controller = AccountManagementCubit(profile, account.id);
    addTearDown(controller.close);
    expect(
      await controller.update(const AccountPreferences(name: 'Saved name')),
      isTrue,
    );
    expect(controller.state.profile!.name, 'Saved name');
    expect((await profile.profile(account.id)).name, 'Saved name');
    final filter = LedgerFilter(
      accounts: [account.id],
      currency: account.balance.currency,
    );
    final history = ApiHistoryRepository(environment.api, environment.cache);
    final page = await history.page(filter);
    expect(page.items, isNotEmpty);
    expect(
      (await history.around(
        filter.copyWith(revision: page.revision),
        page.items.first.id,
      )).items,
      isNotEmpty,
    );
    expect(
      (await ApiAnalyticsRepository(
        environment.api,
        environment.cache,
      ).summary(filter)).revision,
      isNotEmpty,
    );
    expect(cache.writes, 7);
    // Recovery writes remain mandatory, even with the response-cache extension.
    await expectLater(cache.write('journal', {}), throwsStateError);
  });

  test(
    'invalid or unreadable profile cache never blocks a fresh server profile',
    () async {
      final cache = _FailingWrites();
      final environment = AppEnvironment(
        cache: cache,
        journal: MemoryCacheStore(durable: true),
        simulation: SimulationAdapter(scheduler: _InstantScheduler()),
      );
      addTearDown(environment.dispose);
      final reader = ApiAccountManagement(environment.api, environment.cache);
      addTearDown(reader.close);
      final key = '${environment.language.code}:account-profile:main';
      await cache.store.write(key, {'id': 'main'});
      expect(await reader.cachedProfile('main'), isNull);
      expect(await cache.store.read(key), isNull);
      cache.failReads = true;
      final cubit = AccountManagementCubit(reader, 'main');
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.profile!.id, 'main');
      expect(cubit.state.problem, isNull);
      expect(cubit.state.stale, isFalse);
    },
  );
}
