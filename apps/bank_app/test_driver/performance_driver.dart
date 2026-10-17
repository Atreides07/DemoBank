import 'dart:io';
import 'dart:convert';
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  writeResponseOnFailure: true,
  responseDataCallback: (data) async {
    final output = Directory('../../.artifacts/performance');
    await output.create(recursive: true);
    await File(
      '${output.path}/android-profile.json',
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  },
);
