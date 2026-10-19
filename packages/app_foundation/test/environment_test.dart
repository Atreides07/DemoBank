import 'dart:convert';

import 'package:app_foundation/app_foundation.dart';
import 'package:bank_core/bank_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:network_simulation/network_simulation.dart';
import 'package:payment_domain/payment_domain.dart';

/// A durable journal whose simulator snapshot cannot be decoded until deleted.
final class _UnreadableStateJournal implements CacheStore {
  final MemoryCacheStore _delegate = MemoryCacheStore(durable: true);
  bool corrupt = true;

  @override
  Future<CacheEntry?> read(String key) async {
    if (key == 'simulator_state' && corrupt) throw CorruptCacheEntry(key);
    return _delegate.read(key);
  }

  @override
  Future<void> write(
    String key,
    Map<String, dynamic> value, {
    Duration ttl = const Duration(minutes: 5),
    String? revision,
  }) => _delegate.write(key, value, ttl: ttl, revision: revision);

  @override
  Future<void> delete(String key) {
    if (key == 'simulator_state') corrupt = false;
    return _delegate.delete(key);
  }

  @override
  Future<String?> quarantine(String key) => _delegate.quarantine(key);

  @override
  Future<void> clear() => _delegate.clear();

  @override
  Future<void> expireAll() => _delegate.expireAll();

  @override
  Future<void> close() => _delegate.close();
}

/// Observes the resource boundary rather than its private implementation. The
/// delegate preserves serialization/copy semantics of the real cache contract.
final class _CountingStore implements CacheStore {
  final MemoryCacheStore _delegate = MemoryCacheStore();
  int reads = 0;
  int writes = 0;
  int deletions = 0;
  int clears = 0;
  int expirations = 0;
  int quarantines = 0;
  int closes = 0;

  int get ioCalls =>
      reads + writes + deletions + clears + expirations + quarantines;

  @override
  Future<CacheEntry?> read(String key) {
    reads++;
    return _delegate.read(key);
  }

  @override
  Future<void> write(
    String key,
    Map<String, dynamic> value, {
    Duration ttl = const Duration(minutes: 5),
    String? revision,
  }) {
    writes++;
    return _delegate.write(key, value, ttl: ttl, revision: revision);
  }

  @override
  Future<void> delete(String key) {
    deletions++;
    return _delegate.delete(key);
  }

  @override
  Future<String?> quarantine(String key) {
    quarantines++;
    return _delegate.quarantine(key);
  }

  @override
  Future<void> clear() {
    clears++;
    return _delegate.clear();
  }

  @override
  Future<void> expireAll() {
    expirations++;
    return _delegate.expireAll();
  }

  @override
  Future<void> close() {
    closes++;
    return _delegate.close();
  }
}

const _fastProfile = NetworkProfile(
  name: 'local-test',
  firstByteLatency: Duration.zero,
  jitter: Duration.zero,
  bytesPerSecond: 100000000,
  chunkBytes: 1048576,
);

PendingPayment _pending(String key) {
  final intent = PaymentIntent(
    kind: PaymentKind.mobile,
    accountId: 'main',
    recipient: 'Тестовый оператор',
    referenceIds: const [],
    amount: Money(12500),
    details: const {'phone': '79001234567'},
  );
  return PendingPayment(
    idempotencyKey: key,
    preparedAt: DateTime.utc(2026, 10, 16, 9),
    quote: PaymentQuote(
      id: 'quote-$key',
      intent: intent,
      amount: Money(12500),
      fee: Money(0),
      expiresAt: DateTime.utc(2026, 10, 16, 10),
      recipient: intent.recipient,
      description: 'Пополнение связи',
    ),
  );
}

void main() {
  test('HTTP persistence is opt-in configuration and preserves lazy scope', () {
    final normalCache = _CountingStore();
    final normalJournal = _CountingStore();
    final compatibleCache = _CountingStore();
    final compatibleJournal = _CountingStore();
    final normal = AppEnvironment(
      http: true,
      cache: normalCache,
      journal: normalJournal,
    );
    final compatible = AppEnvironment(
      http: true,
      httpKeepAlive: false,
      cache: compatibleCache,
      journal: compatibleJournal,
    );
    addTearDown(normal.dispose);
    addTearDown(compatible.dispose);
    expect(normal.httpKeepAlive, true);
    expect(normal.api.persistentConnection, true);
    expect(compatible.httpKeepAlive, false);
    expect(compatible.api.persistentConnection, false);
    expect(normal.scopeId, compatible.scopeId);
    expect(jsonDecode(normal.diagnosticJson())['httpKeepAlive'], true);
    expect(jsonDecode(compatible.diagnosticJson())['httpKeepAlive'], false);
    for (final store in [
      normalCache,
      normalJournal,
      compatibleCache,
      compatibleJournal,
    ]) {
      expect(store.ioCalls, 0);
    }
    expect(normal.apiEvents, isEmpty);
    expect(compatible.apiEvents, isEmpty);
  });

  test('simulation reports native HTTP persistence as not applicable', () {
    for (final keepAlive in [true, false]) {
      final environment = AppEnvironment(
        httpKeepAlive: keepAlive,
        cache: _CountingStore(),
        journal: _CountingStore(),
      );
      addTearDown(environment.dispose);
      expect(environment.api.persistentConnection, keepAlive);
      expect(jsonDecode(environment.diagnosticJson())['httpKeepAlive'], isNull);
      expect(environment.simulation.events, isEmpty);
    }
  });

  test('compile-time HTTP persistence reaches the constructed API', () {
    final environment = AppEnvironment.fromDefines();
    addTearDown(environment.dispose);
    // Run this test once normally and once with HTTP_KEEP_ALIVE=false. The
    // independent string expectation verifies both the factory and DI wiring.
    const configured = String.fromEnvironment(
      'HTTP_KEEP_ALIVE',
      defaultValue: 'true',
    );
    expect(environment.httpKeepAlive, configured == 'true');
    expect(environment.api.persistentConnection, configured == 'true');
    expect(
      jsonDecode(environment.diagnosticJson())['httpKeepAlive'],
      environment.http ? configured == 'true' : null,
    );
    expect(environment.apiEvents, isEmpty);
  });

  test(
    'optional API observer is isolated and sees actual completion',
    () async {
      final phases = <String>[];
      final environment = AppEnvironment(
        cache: MemoryCacheStore(),
        journal: MemoryCacheStore(),
        profile: _fastProfile,
        onApiEvent: (event) async {
          phases.add(event.phase.name);
          if (event.phase.name == 'completed') {
            throw StateError('Diagnostic consumer unavailable');
          }
        },
      );
      addTearDown(environment.dispose);
      final response = await environment.api.get('/v1/accounts');
      await Future<void>.delayed(Duration.zero);
      expect(response['accounts'], hasLength(6));
      expect(phases.first, 'started');
      expect(phases.last, 'completed');
      expect(
        phases,
        containsAllInOrder(['started', 'headers', 'chunk', 'completed']),
      );
      expect(environment.apiEvents.map((event) => event.phase.name), phases);
    },
  );

  for (final http in [false, true]) {
    test(
      'constructing the ${http ? 'HTTP' : 'simulation'} graph performs no storage or network I/O',
      () async {
        final cache = _CountingStore();
        final journal = _CountingStore();
        final scheduler = ManualSimulationScheduler();
        final simulation = SimulationAdapter(
          seed: 71,
          profile: NetworkProfile.slow,
          scheduler: scheduler,
        );
        final environment = AppEnvironment(
          cache: cache,
          journal: journal,
          simulation: simulation,
          seed: 999,
          profile: NetworkProfile.offline,
          http: http,
          baseUri: Uri.parse('https://unresolvable.invalid/v1'),
        );
        addTearDown(environment.dispose);

        // Flush queued startup work: even deferred eager access would be visible.
        await scheduler.elapse(Duration.zero);
        expect(cache.ioCalls, 0);
        expect(journal.ioCalls, 0);
        expect(cache.closes, 0);
        expect(journal.closes, 0);
        expect(simulation.events, isEmpty);
        expect(scheduler.pendingDelays, 0);
        expect(identical(environment.simulation, simulation), true);
        expect(
          identical(environment.simulation.profile, NetworkProfile.slow),
          true,
        );
        if (!http) expect(environment.scopeId, 'simulation_71');
      },
    );
  }

  test(
    'the environment closes distinct owned stores and its API exactly once',
    () async {
      final cache = _CountingStore();
      final journal = _CountingStore();
      final environment = AppEnvironment(cache: cache, journal: journal);
      environment.dispose();
      environment.dispose();
      environment.dispose();
      expect(cache.closes, 1);
      expect(journal.closes, 1);
      expect(cache.ioCalls, 0);
      expect(journal.ioCalls, 0);
      await expectLater(environment.api.get('/v1/accounts'), throwsStateError);
      expect(environment.simulation.events, isEmpty);
    },
  );

  test('a store injected into both resource slots is closed once', () async {
    final shared = _CountingStore();
    final environment = AppEnvironment(cache: shared, journal: shared);
    environment.dispose();
    environment.dispose();
    expect(shared.closes, 1);
    expect(shared.ioCalls, 0);
  });

  test(
    'discarding an unreadable payment journal sets it aside, not deletes it',
    () async {
      final journal = _CountingStore();
      final environment = AppEnvironment(
        cache: MemoryCacheStore(),
        journal: journal,
      );
      addTearDown(environment.dispose);
      await journal.write('pending_payment', {'value': 'not json'});
      final store = environment.checkout.pendingStore;
      await expectLater(
        store.load(),
        throwsA(
          isA<PaymentFailure>().having(
            (failure) => failure.code,
            'code',
            PaymentFailureCode.journalUnreadable,
          ),
        ),
      );
      await store.clear();
      expect(journal.quarantines, 1);
      expect(journal.deletions, 0);
      expect(await store.load(), isNull);
    },
  );

  test('reporting periods use the ledger demo calendar, not the device', () {
    final environment = AppEnvironment(
      cache: MemoryCacheStore(),
      journal: MemoryCacheStore(),
    );
    addTearDown(environment.dispose);
    expect(environment.now(), DemoApi.businessNow);
    final month = ReportingPeriod.month(environment.now());
    // Rows created during a session are dated seconds after businessNow.
    expect(
      month.to!.isAfter(DemoApi.businessNow.add(const Duration(hours: 8))),
      isTrue,
    );
  });

  test(
    'an unreadable simulator state is regenerated instead of breaking startup',
    () async {
      final journal = _UnreadableStateJournal();
      final environment = AppEnvironment(
        cache: MemoryCacheStore(),
        journal: journal,
        profile: _fastProfile,
      );
      addTearDown(environment.dispose);
      final response = await environment.api.get('/v1/accounts');
      expect(response['accounts'], hasLength(6));
      expect(journal.corrupt, isFalse);
    },
  );

  test('two graphs isolate settings, response data, simulator state and payment journals', () async {
    final cacheA = _CountingStore();
    final journalA = _CountingStore();
    final cacheB = _CountingStore();
    final journalB = _CountingStore();
    final first = AppEnvironment(
      cache: cacheA,
      journal: journalA,
      profile: _fastProfile,
    );
    final second = AppEnvironment(
      cache: cacheB,
      journal: journalB,
      profile: _fastProfile,
    );
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    first.setTheme(true);
    first.setReducedMotion(true);
    first.setComparison(true);
    expect(second.theme, ThemeMode.light);
    expect(second.reduceMotion, false);
    expect(second.motionComparison, false);

    await first.cache.write('accounts', {'owner': 'first'});
    expect(await second.cache.read('accounts'), isNull);
    await first.checkout.pendingStore.reserve(_pending('operation-A'));
    expect(await second.checkout.pendingStore.load(), isNull);
    await second.checkout.pendingStore.reserve(_pending('operation-B'));
    expect(
      (await first.checkout.pendingStore.load())?.idempotencyKey,
      'operation-A',
    );
    expect(
      (await second.checkout.pendingStore.load())?.idempotencyKey,
      'operation-B',
    );

    final beforeA = await first.api.get(
      '/v1/transactions',
      query: {'limit': 1},
    );
    final beforeB = await second.api.get(
      '/v1/transactions',
      query: {'limit': 1},
    );
    expect(beforeA['revision'], beforeB['revision']);
    await first.addActivity();
    final afterA = await first.api.get('/v1/transactions', query: {'limit': 1});
    final afterB = await second.api.get(
      '/v1/transactions',
      query: {'limit': 1},
    );
    expect(afterA['total'], (beforeA['total']! as int) + 1);
    expect(afterA['revision'], isNot(beforeA['revision']));
    expect(afterB['revision'], beforeB['revision']);
    expect(afterB['items'], beforeB['items']);
    expect(await journalA.read('simulator_state'), isNotNull);
    expect(await journalB.read('simulator_state'), isNull);
    expect(
      (await second.checkout.pendingStore.load())?.idempotencyKey,
      'operation-B',
    );
  });

  test('clearing response cache preserves recoverable payment and simulator journal', () async {
    final cache = _CountingStore();
    final journal = _CountingStore();
    final environment = AppEnvironment(
      cache: cache,
      journal: journal,
      profile: _fastProfile,
    );
    addTearDown(environment.dispose);
    await cache.write('accounts', {'cached': true});
    await environment.checkout.pendingStore.reserve(_pending('recover-me'));
    await environment.addActivity();
    final persistedState = (await journal.read('simulator_state'))!.value;

    await environment.clearCache();

    expect(cache.clears, 1);
    expect(await cache.read('accounts'), isNull);
    expect(journal.clears, 0);
    expect(journal.deletions, 0);
    expect(
      (await environment.checkout.pendingStore.load())?.idempotencyKey,
      'recover-me',
    );
    expect((await journal.read('simulator_state'))?.value, persistedState);
  });

  test('scope identifiers are restart compatible and partition sources, fixtures and backends', () {
    // Persisted namespace compatibility vectors: changing these requires a
    // deliberate migration, rather than silently losing a pending payment.
    expect(AppEnvironment.storageScope(http: false), 'simulation_42');
    expect(AppEnvironment.storageScope(http: true), 'http_a91b2b6f');
    expect(
      AppEnvironment.storageScope(
        http: true,
        baseUri: Uri.parse('https://api.example.test/v1'),
      ),
      'http_50b72a01',
    );

    final scopes = {
      AppEnvironment.storageScope(http: false),
      AppEnvironment.storageScope(http: false, seed: 7),
      AppEnvironment.storageScope(http: true),
      AppEnvironment.storageScope(
        http: true,
        baseUri: Uri.parse('https://api.example.test/v1'),
      ),
      AppEnvironment.storageScope(
        http: true,
        baseUri: Uri.parse('https://api.example.test/v2'),
      ),
      AppEnvironment.storageScope(
        http: true,
        baseUri: Uri.parse('https://api.example.test:8443/v1'),
      ),
      AppEnvironment.storageScope(
        http: true,
        baseUri: Uri.parse('http://api.example.test/v1'),
      ),
      AppEnvironment.storageScope(
        http: true,
        baseUri: Uri.parse('https://other.example.test/v1'),
      ),
    };
    expect(scopes, hasLength(8));
    expect(
      AppEnvironment.storageScope(
        http: true,
        baseUri: Uri.parse('https://api.example.test:443/v1'),
      ),
      'http_50b72a01',
    );
  });

  test(
    'changing a latency profile preserves scope, cache and pending operation',
    () async {
      final environment = AppEnvironment(
        cache: _CountingStore(),
        journal: _CountingStore(),
        seed: 19,
      );
      addTearDown(environment.dispose);
      final scope = environment.scopeId;
      await environment.cache.write('response', {'revision': 'r1'});
      await environment.checkout.pendingStore.reserve(
        _pending('same-operation'),
      );

      environment.setProfile(NetworkProfile.offline);

      expect(environment.scopeId, scope);
      expect(environment.simulation.profile, NetworkProfile.offline);
      expect(
        (await environment.cache.read('response'))?.value['revision'],
        'r1',
      );
      expect(
        (await environment.checkout.pendingStore.load())?.idempotencyKey,
        'same-operation',
      );
    },
  );

  test('offline activity reports an error state without throwing or mutating its journal', () async {
    final scheduler = ManualSimulationScheduler();
    final journal = _CountingStore();
    final environment = AppEnvironment(
      cache: _CountingStore(),
      journal: journal,
      simulation: SimulationAdapter(
        profile: NetworkProfile.offline,
        scheduler: scheduler,
      ),
    );
    addTearDown(environment.dispose);
    final phases = <bool>[];
    environment.addListener(() => phases.add(environment.activityInProgress));

    final operation = environment.addActivity();
    final completion = expectLater(operation, completes);
    expect(environment.activityInProgress, true);
    await scheduler.runUntilIdle();
    await completion;

    expect(phases, [true, false]);
    expect(environment.activityInProgress, false);
    expect(environment.activityOutcome, ActivityOutcome.failed);
    expect(
      environment.simulation.events.any((event) => event.phase == 'failed'),
      true,
    );
    expect(journal.writes, 0);
  });

  test('disposing during a request cancels it without notifications or late resource access', () async {
    final scheduler = ManualSimulationScheduler();
    final cache = _CountingStore();
    final journal = _CountingStore();
    final environment = AppEnvironment(
      cache: cache,
      journal: journal,
      simulation: SimulationAdapter(
        profile: NetworkProfile.slow,
        scheduler: scheduler,
      ),
    );
    addTearDown(environment.dispose);
    var notifications = 0;
    environment.addListener(() => notifications++);
    final operation = environment.addActivity();
    final completion = expectLater(operation, completes);
    await scheduler.elapse(Duration.zero);
    expect(scheduler.pendingDelays, 1);
    expect(notifications, 1);

    environment.dispose();
    environment.dispose();
    await scheduler.runUntilIdle();
    await completion;

    expect(notifications, 1);
    expect(environment.activityInProgress, false);
    expect(scheduler.pendingDelays, 0);
    expect(cache.closes, 1);
    expect(journal.closes, 1);
    expect(cache.ioCalls, 0);
    expect(journal.ioCalls, 0);
    expect(
      environment.simulation.events.any((event) => event.phase == 'cancelled'),
      true,
    );
  });
}
