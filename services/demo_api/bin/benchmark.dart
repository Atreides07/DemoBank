import 'dart:convert';
import 'dart:io';

import 'package:network_simulation/network_simulation.dart';

/// This checks fixture computation and payload budgets, independently from
/// simulated bandwidth or UI/device frame measurements.
Future<void> main() async {
  final api = DemoApi();
  final startup = Stopwatch()..start();
  await api.warmUp();
  startup.stop();
  final measurements = <Map<String, Object>>[];
  for (final path in [
    '/accounts',
    '/transactions?from=2026-10-01&to=2026-10-16&limit=30',
    '/analytics?from=2026-10-01&to=2026-10-16',
    '/analytics',
  ]) {
    final elapsed = <int>[];
    var bytes = 0;
    for (var iteration = 0; iteration < 25; iteration++) {
      final watch = Stopwatch()..start();
      final response = await api.handle(
        SimulatedRequest(
          method: 'GET',
          uri: Uri.parse('https://demo.invalid/v1$path'),
        ),
      );
      final encoded = utf8.encode(jsonEncode(response.body));
      watch.stop();
      if (response.statusCode != 200) throw StateError('$path failed');
      bytes = encoded.length;
      elapsed.add(watch.elapsedMicroseconds);
    }
    elapsed.sort();
    measurements.add({
      'route': path,
      'iterations': elapsed.length,
      'medianUs': elapsed[elapsed.length ~/ 2],
      'p95Us': elapsed[(elapsed.length * 0.95).floor()],
      'maxUs': elapsed.last,
      'jsonBytes': bytes,
    });
  }
  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert({
      'scope': 'route-engine-and-json-only',
      'uiOrAndroidPerformanceProof': false,
      'os': Platform.operatingSystem,
      'sdk': Platform.version,
      'datasetSize': DemoApi.datasetSize,
      'fixtureWarmupUs': startup.elapsedMicroseconds,
      'measurements': measurements,
    }),
  );
}
