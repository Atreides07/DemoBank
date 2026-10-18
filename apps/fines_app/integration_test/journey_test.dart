import 'dart:async';
import 'dart:convert';

import 'package:app_foundation/app_foundation.dart';
import 'package:app_localizations/app_localizations.dart';
import 'package:bank_core/bank_core.dart';
import 'package:design_system/design_system.dart';
import 'package:fines_app/fines_application.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:network_simulation/network_simulation.dart';

const _mode = kReleaseMode
    ? 'release'
    : kProfileMode
    ? 'profile'
    : 'debug';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  _attachReleaseVerdict(binding);
  testWidgets(
    'standalone fines: document → details → payment → receipt → paid',
    (tester) async {
      final environment = AppEnvironment(
        cache: CacheStore(namespace: 'integration_fines_journey_responses'),
        journal: CacheStore(namespace: 'integration_fines_journey_journal'),
        http: const String.fromEnvironment('DATA_SOURCE') == 'http',
        httpKeepAlive: const bool.fromEnvironment(
          'HTTP_KEEP_ALIVE',
          defaultValue: true,
        ),
        baseUri: Uri.parse(
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'https://demo.invalid',
          ),
        ),
        seed: const int.fromEnvironment('NETWORK_SEED', defaultValue: 42),
        profile: switch (const String.fromEnvironment(
          'NETWORK_PROFILE',
          defaultValue: 'normal',
        )) {
          'slow' => NetworkProfile.slow,
          'unstable' => NetworkProfile.unstable,
          'offline' => NetworkProfile.offline,
          _ => NetworkProfile.normal,
        },
      );
      final watch = Stopwatch()..start();
      final completed = <Map<String, Object?>>[];
      final screenshots = <String>[];
      var stage = 'prepare isolated demo fixtures';
      var converted = false;
      void report(String status, {Object? error}) {
        binding.reportData = {
          ...?binding.reportData,
          'journey': {
            'app': 'fines',
            'buildMode': _mode,
            'status': status,
            'source': environment.sourceLabel,
            'httpKeepAlive': environment.http
                ? environment.api.persistentConnection
                : null,
            'networkProfile': environment.simulation.profile.toJson(),
            'cache': 'fresh isolated native Drift namespaces',
            'httpPrecondition': environment.http
                ? 'externally reset demo fixtures'
                : null,
            'elapsedMs': watch.elapsedMilliseconds,
            'currentStage': stage,
            'completedScenarios': completed,
            'capturedScreenshots': screenshots,
            if (error != null) 'failure': error.toString(),
            'evidenceScope':
                'physical standalone UI journey; no frame-performance claim',
          },
        };
        if (status == 'passed' || status == 'failed') {
          _releaseReport({
            'app': 'fines',
            'buildMode': _mode,
            'status': status,
            'source': environment.http ? 'http' : 'simulation',
            'httpKeepAlive': environment.http
                ? environment.api.persistentConnection
                : null,
            'networkProfile': environment.simulation.profile.name,
            'elapsedMs': watch.elapsedMilliseconds,
            'stage': stage,
            if (error != null) 'failureType': error.runtimeType.toString(),
            'completedScenarios': [
              for (final scenario in completed)
                {
                  'scenario': scenario['scenario'],
                  'status': scenario['status'],
                },
            ],
          });
        }
      }

      Future<void> capture(String name) async {
        if (!const bool.fromEnvironment(
          'JOURNEY_SCREENSHOTS',
          defaultValue: true,
        )) {
          return;
        }
        if (!converted && defaultTargetPlatform == TargetPlatform.android) {
          await binding.convertFlutterSurfaceToImage();
          converted = true;
          await tester.pump();
        }
        final fullName = 'fines_${_mode}_$name';
        await binding.takeScreenshot(fullName);
        screenshots.add(fullName);
        report('running');
      }

      try {
        // Register after binding.reset so IME injection captures the real client
        // ID in AOT. This journey does not test the system keyboard itself.
        binding.testTextInput.register();
        await environment.cache.clear();
        await environment.journal.clear();
        if (!environment.http) await environment.simulation.resetData();
        report('running');
        await tester.pumpWidget(FinesApplication(environment: environment));
        await _waitFor(tester, find.byType(TextField));
        await _ready(tester);
        expect(find.byType(DsNavigationBar), findsNothing);
        await capture('search');

        stage = 'document search and fine details';
        final documentField = find.byType(TextField);
        const document = '7712345678';
        await tester.enterText(documentField, document);
        await tester.pump();
        final editable = tester.state<EditableTextState>(
          find.descendant(
            of: documentField,
            matching: find.byType(EditableText),
            matchRoot: true,
          ),
        );
        expect(
          editable.widget.controller.text,
          document,
          reason: 'IME injection must update the actual editable field',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await _press(tester, find.text('Найти штрафы'));
        await _waitFor(tester, find.text('Превышение скорости'));
        await _press(tester, find.text('Превышение скорости'));
        expect(find.text('УИН'), findsOneWidget);
        expect(find.text('fine-001'), findsOneWidget);
        await capture('fine_details');
        completed.add({
          'scenario': 'standalone_fine_search_and_details',
          'status': 'passed',
          'fine': 'fine-001',
        });
        report('running');

        stage = 'shared checkout and server receipt';
        await _press(tester, find.text('Перейти к оплате'));
        await _waitFor(tester, find.text('Подтвердить оплату'));
        await _ready(tester);
        final summary = tester.widget<DsPaymentSummary>(
          find.byType(DsPaymentSummary),
        );
        expect(summary.amount, AppFormats('ru').money(const Money(75000)));
        expect(
          summary.details.singleWhere((item) => item.label == 'Комиссия').value,
          AppFormats('ru').money(const Money(0)),
        );
        await _press(tester, find.text('Подтвердить оплату'));
        await _waitFor(tester, find.text('Оплата выполнена'));
        final success = tester.widget<DsStatus>(
          find.byWidgetPredicate(
            (widget) =>
                widget is DsStatus && widget.title == 'Оплата выполнена',
          ),
        );
        expect(success.message, startsWith('Квитанция № '));
        await tester.ensureVisible(find.text('Оплата выполнена'));
        await tester.pumpAndSettle();
        await capture('receipt');
        completed.add({
          'scenario': 'standalone_fine_receipt',
          'status': 'passed',
          'serverReceipt': success.message,
          'totalMinor': 75000,
          'feeMinor': 0,
        });
        report('running');

        stage = 'paid bill and empty pending journal after return';
        await _press(tester, find.text('Готово'));
        await _waitFor(tester, find.text('Оплачен'));
        expect(await environment.checkout.pendingStore.load(), isNull);
        if (!environment.http) {
          expect(
            environment.simulation.events.where(
              (event) =>
                  event.method == 'POST' &&
                  event.path == '/checkout/payments' &&
                  event.phase == 'started',
            ),
            hasLength(1),
          );
        }
        expect(find.byType(DsNavigationBar), findsNothing);
        expect(tester.takeException(), isNull);
        completed.add({
          'scenario': 'standalone_paid_status_and_journal',
          'status': 'passed',
          'journalEmpty': true,
          'bankNavigationAbsent': true,
        });
        await capture('paid_bill');
        report('passed');
      } catch (error) {
        report('failed', error: error);
        rethrow;
      } finally {
        try {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          environment.dispose();
        } finally {
          binding.testTextInput.unregister();
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

final _releaseRunId = DateTime.now().microsecondsSinceEpoch.toRadixString(16);

void _attachReleaseVerdict(IntegrationTestWidgetsFlutterBinding binding) {
  if (!const bool.fromEnvironment('JOURNEY_RELEASE_LOG')) return;
  unawaited(
    binding.allTestsPassed.future.then((passed) {
      _releaseLine(
        'DBJ1 VERDICT id=$_releaseRunId status=${passed ? 'passed' : 'failed'} '
        '${passed ? 'All tests passed' : 'Some tests failed'}',
      );
    }),
  );
}

void _releaseReport(Map<String, Object?> safeReport) {
  if (!const bool.fromEnvironment('JOURNEY_RELEASE_LOG')) return;
  final bytes = utf8.encode(
    jsonEncode({'protocolVersion': 1, 'runId': _releaseRunId, ...safeReport}),
  );
  var checksum = 0x811c9dc5;
  for (final byte in bytes) {
    checksum = ((checksum ^ byte) * 0x01000193) & 0xffffffff;
  }
  final hash = checksum.toRadixString(16).padLeft(8, '0');
  final encoded = base64Encode(bytes);
  const chunkWidth = 640;
  final count = (encoded.length + chunkWidth - 1) ~/ chunkWidth;
  _releaseLine(
    'DBJ1 BEGIN id=$_releaseRunId app=${safeReport['app']} '
    'count=$count length=${bytes.length} checksum=$hash',
  );
  for (var sequence = 0; sequence < count; sequence++) {
    final start = sequence * chunkWidth;
    final end = start + chunkWidth < encoded.length
        ? start + chunkWidth
        : encoded.length;
    _releaseLine(
      'DBJ1 CHUNK id=$_releaseRunId seq=$sequence count=$count '
      'data=${encoded.substring(start, end)}',
    );
  }
  _releaseLine(
    'DBJ1 COMPLETE id=$_releaseRunId count=$count length=${bytes.length} '
    'checksum=$hash status=${safeReport['status']}',
  );
}

void _releaseLine(String line) {
  // ignore: avoid_print
  print(line);
}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsWidgets);
  expect(tester.takeException(), isNull);
}

Future<void> _ready(WidgetTester tester) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (find.byType(CircularProgressIndicator).evaluate().isNotEmpty &&
      DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(find.byType(CircularProgressIndicator), findsNothing);
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 10),
  );
  expect(tester.takeException(), isNull);
}

Future<void> _press(WidgetTester tester, Finder finder) async {
  await _waitFor(tester, finder);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
  await _ready(tester);
}
