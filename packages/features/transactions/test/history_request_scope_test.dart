import 'package:network_client/network_client.dart';
import 'package:bank_core/bank_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:network_simulation/network_simulation.dart';
import 'package:transactions/transactions.dart';

void main() {
  test('rapid history filter changes cancel obsolete requests', () async {
    final clock = ManualSimulationScheduler();
    final adapter = SimulationAdapter(
      scheduler: clock,
      profile: NetworkProfile.slow,
    );
    final api = ApiClient(
      baseUri: Uri.parse('https://demo.invalid'),
      adapter: adapter,
    );
    final cache = MemoryCacheStore();
    final cubit = HistoryCubit(ApiHistoryRepository(api, cache));
    await adapter.api.warmUp();
    final initial = cubit.load();
    await clock.runUntilIdle();
    await initial;
    adapter.transport.clearLog();
    final one = cubit.load(filter: LedgerFilter(category: 'groceries'));
    await clock.elapse(Duration.zero);
    final two = cubit.load(filter: LedgerFilter(category: 'dining'));
    await clock.elapse(Duration.zero);
    final three = cubit.load(filter: LedgerFilter(category: 'transport'));
    await clock.elapse(Duration.zero);
    await clock.runUntilIdle();
    await Future.wait([one, two, three]);
    final events = adapter.events;
    final started = events.where((e) => e.phase == 'started').length;
    final completed = events.where((e) => e.phase == 'completed').length;
    final cancelled = events.where((e) => e.phase == 'cancelled').length;
    expect(started, 3);
    expect(completed, 1);
    expect(cancelled, 2);
    expect(cubit.state.filter.category, 'transport');
    await cubit.close();
    api.close();
    await cache.close();
  });
  test('closing one history consumer leaves another consumer alive', () async {
    final clock = ManualSimulationScheduler();
    final adapter = SimulationAdapter(
      scheduler: clock,
      profile: NetworkProfile.slow,
    );
    final api = ApiClient(
      baseUri: Uri.parse('https://demo.invalid'),
      adapter: adapter,
    );
    final cache = MemoryCacheStore();
    await adapter.api.warmUp();
    final repository = ApiHistoryRepository(api, cache);
    final first = HistoryCubit(repository), second = HistoryCubit(repository);
    final a = first.load(), b = second.load();
    await clock.elapse(Duration.zero);
    await first.close();
    await clock.runUntilIdle();
    await Future.wait([a, b]);
    expect(second.state.failed, isFalse);
    expect(second.state.rowCount, 30);
    expect(adapter.events.where((e) => e.phase == 'cancelled'), hasLength(1));
    await second.close();
    api.close();
    await cache.close();
  });
}
