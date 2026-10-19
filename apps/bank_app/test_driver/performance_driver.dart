import 'dart:io';
import 'dart:convert';

import 'package:integration_test/integration_test_driver.dart';

import '../integration_test/support/profile_trace_storage.dart';

Future<void> main() => integrationDriver(
  writeResponseOnFailure: true,
  responseDataCallback: (data) async {
    if (data != null) restoreProfileTraces(data);
    final output = Directory('../../.artifacts/performance');
    await output.create(recursive: true);
    await File(
      Platform.environment['PERFORMANCE_OUTPUT_FILE'] ??
          '${output.path}/android-profile.json',
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  },
);
