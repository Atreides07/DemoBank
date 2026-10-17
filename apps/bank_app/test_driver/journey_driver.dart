import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final directory = Directory(
    Platform.environment['JOURNEY_OUTPUT_DIR'] ??
        '../../.artifacts/journey-bank',
  );
  await directory.create(recursive: true);
  final captured = <Map<String, Object>>[];
  await integrationDriver(
    writeResponseOnFailure: true,
    onScreenshot: (name, bytes, [arguments]) async {
      if (bytes.length < 8 ||
          bytes[0] != 137 ||
          bytes[1] != 80 ||
          bytes[2] != 78 ||
          bytes[3] != 71) {
        return false;
      }
      final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file = File('${directory.path}/$safeName.png');
      await file.writeAsBytes(bytes, flush: true);
      captured.add({'name': name, 'file': file.path, 'bytes': bytes.length});
      return true;
    },
    responseDataCallback: (data) async {
      final report = <String, dynamic>{...?data, 'screenshots': captured};
      final journey = data?['journey'];
      final mode = journey is Map
          ? journey['buildMode']?.toString() ?? 'unknown'
          : 'unknown';
      await File('${directory.path}/bank-$mode-journey.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert(report),
        flush: true,
      );
    },
  );
}
