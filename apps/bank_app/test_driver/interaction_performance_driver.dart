import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

import '../integration_test/support/profile_trace_storage.dart';

/// Launch with flutter drive --profile --no-dds. This driver never starts a
/// device or substitutes simulated timing for engine/HTTP measurements.
Future<void> main() => integrationDriver(
  writeResponseOnFailure: true,
  responseDataCallback: (data) async {
    if (data != null) restoreProfileTraces(data);
    final file = File(
      Platform.environment['INTERACTION_PROFILE_FILE'] ??
          '../../.artifacts/performance/interaction-profile.json',
    );
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );
  },
);
