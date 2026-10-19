import 'dart:convert';
import 'dart:io';

/// Keep completed profiler traces losslessly, without retaining millions of
/// JSON map nodes on the application's UI isolate during subsequent scenarios.
/// Called only after traceAction has closed the measured frame window.
void compactProfileTrace(Map<String, dynamic> report, String key) {
  final trace = report[key] as Map<String, dynamic>;
  report[key] = {
    'traceStorage': 'gzip-base64-json-v1',
    'eventCount': (trace['traceEvents'] as List).length,
    'payload': base64Encode(gzip.encode(utf8.encode(jsonEncode(trace)))),
  };
}

/// The host restores the exact timeline before saving the ordinary audit JSON.
void restoreProfileTraces(Map<String, dynamic> report) {
  for (final key in report.keys.toList()) {
    final value = report[key];
    if (value is! Map || value['traceStorage'] != 'gzip-base64-json-v1') {
      continue;
    }
    final trace = jsonDecode(
      utf8.decode(gzip.decode(base64Decode(value['payload'] as String))),
    ) as Map<String, dynamic>;
    if ((trace['traceEvents'] as List).length != value['eventCount']) {
      throw StateError('Incomplete profile trace: $key');
    }
    report[key] = trace;
  }
}
