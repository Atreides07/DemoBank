import 'dart:async';

final class SimulationCancelled implements Exception {
  const SimulationCancelled();
}

final class SimulationCancellation {
  final Completer<void> _completion = Completer<void>();

  bool get isCancelled => _completion.isCompleted;
  Future<void> get whenCancelled => _completion.future;

  void cancel() {
    if (!isCancelled) _completion.complete();
  }

  void throwIfCancelled() {
    if (isCancelled) throw const SimulationCancelled();
  }
}

abstract interface class SimulationScheduler {
  Duration get elapsed;
  Future<void> delay(Duration duration, SimulationCancellation cancellation);
}

final class RealSimulationScheduler implements SimulationScheduler {
  RealSimulationScheduler() : _watch = Stopwatch()..start();

  final Stopwatch _watch;

  @override
  Duration get elapsed => _watch.elapsed;

  @override
  Future<void> delay(Duration duration, SimulationCancellation cancellation) {
    cancellation.throwIfCancelled();
    final result = Completer<void>();
    final timer = Timer(duration, result.complete);
    unawaited(
      cancellation.whenCancelled.then((_) {
        timer.cancel();
        if (!result.isCompleted) {
          result.complete();
        }
      }),
    );
    return result.future;
  }
}

/// A virtual clock: streamed bodies and cancellation run through the same
/// scheduler as real latency, without making tests wait real seconds.
final class ManualSimulationScheduler implements SimulationScheduler {
  Duration _elapsed = Duration.zero;
  final List<_ScheduledDelay> _scheduled = [];

  @override
  Duration get elapsed => _elapsed;
  int get pendingDelays => _scheduled.length;

  @override
  Future<void> delay(Duration duration, SimulationCancellation cancellation) {
    cancellation.throwIfCancelled();
    final item = _ScheduledDelay(_elapsed + duration);
    _scheduled.add(item);
    unawaited(
      cancellation.whenCancelled.then((_) {
        _scheduled.remove(item);
        if (!item.completion.isCompleted) {
          item.completion.complete();
        }
      }),
    );
    return item.completion.future;
  }

  Future<void> elapse(Duration duration) async {
    final target = _elapsed + duration;
    await _flush();
    while (true) {
      _scheduled.sort((a, b) => a.at.compareTo(b.at));
      if (_scheduled.isEmpty || _scheduled.first.at > target) break;
      final first = _scheduled.removeAt(0);
      _elapsed = first.at;
      if (!first.completion.isCompleted) first.completion.complete();
      await _flush();
    }
    _elapsed = target;
    await _flush();
  }

  Future<void> runUntilIdle({int maxSteps = 10000}) async {
    await _flush();
    for (var step = 0; _scheduled.isNotEmpty; step++) {
      if (step >= maxSteps) throw StateError('Simulation did not become idle');
      _scheduled.sort((a, b) => a.at.compareTo(b.at));
      await elapse(_scheduled.first.at - _elapsed);
    }
  }

  Future<void> _flush() async {
    // Dio's queued interceptors advance through event turns as well as
    // microtasks. Yield those turns without advancing virtual network time.
    for (var turn = 0; turn < 12; turn++) {
      await Future<void>.delayed(Duration.zero);
      for (var index = 0; index < 8; index++) {
        await Future<void>.value();
      }
    }
  }
}

final class _ScheduledDelay {
  _ScheduledDelay(this.at);

  final Duration at;
  final Completer<void> completion = Completer<void>();
}
