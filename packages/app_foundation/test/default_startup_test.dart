import 'dart:io';

import 'package:app_foundation/app_foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_simulation/network_simulation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'default startup loads fresh demo data without HTTP or a server',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'demobank-startup-',
      );
      addTearDown(() => directory.delete(recursive: true));
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'getApplicationSupportDirectory');
        return directory.path;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      await HttpOverrides.runZoned(
        () async {
          final environment = AppEnvironment.fromDefines();
          addTearDown(() async {
            await Future.wait([
              environment.cache.close(),
              environment.journal.close(),
              environment.preferences.close(),
            ]);
            environment.dispose();
          });

          expect(environment.http, isFalse);
          expect(environment.simulation.profile, NetworkProfile.normal);
          await environment.restorePreferences();
          expect(environment.chosenLanguage, isNull);

          final accounts = await environment.api.get('/v1/accounts');
          expect(accounts['accounts'], hasLength(6));
          final history = await environment.api.get(
            '/v1/transactions',
            query: {'limit': 1},
          );
          expect(history['total'], DemoApi.datasetSize);
          expect(history['items'], hasLength(1));
        },
        createHttpClient: (_) =>
            throw StateError('Default startup must not create an HTTP client'),
      );
    },
  );
}
