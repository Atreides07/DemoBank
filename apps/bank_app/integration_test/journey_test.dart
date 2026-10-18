import 'dart:async';
import 'package:accounts/accounts.dart';
import 'dart:convert';

import 'package:app_foundation/app_foundation.dart';
import 'package:app_localizations/app_localizations.dart';
import 'package:bank_core/bank_core.dart';
import 'package:bank_experience/bank_experience.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:network_simulation/network_simulation.dart';
import 'package:transactions/transactions.dart';

import 'support/journey_readiness.dart';

const _buildMode = kReleaseMode
    ? 'release'
    : kProfileMode
    ? 'profile'
    : 'debug';

/// Real application, native Drift, production repositories and the ordinary
/// transport. Only the fixture/cache namespaces differ from a normal launch.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  _attachReleaseVerdict(binding);
  testWidgets(
    'bank: four payments and analytical drill-down preserve reading context',
    (tester) async {
      final journey = _Journey(tester, binding);
      final environment = _environment();
      final cache = environment.cache;
      final journal = environment.journal;
      try {
        // Register after binding.reset so IME injection captures the real client
        // ID in AOT. This journey does not test the system keyboard itself.
        binding.testTextInput.register();
        journey.stage = 'prepare isolated demo fixtures';
        // These namespaces belong exclusively to this integration test.
        await cache.clear();
        await journal.clear();
        if (!environment.http) await environment.simulation.resetData();
        journey.start(environment);

        await tester.pumpWidget(BankExperience(environment: environment));
        await journey.waitFor(find.byType(DsHomeHeader));
        await journey.waitFor(find.text('Основной счёт'));
        await journey.ready();
        await journey.capture('home');
        journey.passed('home_loaded', {
          'primaryAccounts': ['Основной счёт', 'Накопительный счёт'],
          'fixtureRows': 12000,
        });

        await _referenceJourney(journey);
        await journey.navigation('Платежи');
        await journey.openService('ЖКХ');
        await journey.type(find.byType(TextField), '1234567890');
        await journey.pressText('Получить начисления');
        await journey.waitFor(find.byType(CheckboxListTile));
        await journey.ready();
        await journey.press(find.byType(CheckboxListTile).first);
        await journey.pressText('Продолжить');
        await journey.confirmAndCapture(
          'utilities',
          total: const Money(685320),
          fee: const Money(1000),
        );
        await journey.pressText('Готово');
        await journey.waitFor(find.text('Оплачен'));
        expect(find.byType(CheckboxListTile), findsOneWidget);
        journey.passed('utilities_paid_bill_after_return', {
          'paidBills': 1,
          'remainingSelectableBills': 1,
        });
        await journey.backToServices();

        await journey.openService('Мобильная связь');
        await journey.type(find.byType(TextField).first, '+7 916 123-45-67');
        await journey.pressText('Определить оператора');
        await journey.waitFor(find.text('МТС'));
        await journey.ready();
        await journey.type(find.byType(TextField).last, '155,55');
        await journey.pressText('Продолжить');
        await journey.confirmAndCapture(
          'mobile',
          total: const Money(15555),
          fee: const Money(0),
        );
        await journey.pressText('Готово');
        await journey.waitFor(find.text('Определить оператора'));
        await journey.backToServices();

        await journey.openService('Кино');
        await journey.waitFor(find.text('Орбита света'));
        await journey.pressText('Орбита света');
        await journey.waitFor(find.byIcon(DsIcons.schedule));
        await journey.ready();
        await journey.press(find.byIcon(DsIcons.schedule).first);
        await journey.waitFor(find.text('Ряд 1 · место 1'));
        await journey.ready();
        await journey.pressText('Ряд 1 · место 1');
        await journey.pressText('Перейти к оплате');
        await journey.confirmAndCapture(
          'cinema',
          total: const Money(65000),
          fee: const Money(0),
          ticket: true,
        );
        await journey.pressText('Готово');
        await journey.waitFor(find.text('Ряд 1 · место 1 · занято'));
        expect(find.text('Ваш выбор'), findsNothing);
        journey.passed('cinema_paid_seat_unavailable_after_return', {
          'seat': 'Ряд 1 · место 1',
          'session': 'movie-001-evening',
        });
        await journey.backToServices();

        await journey.openService('Штрафы');
        await journey.type(find.byType(TextField), '7712345678');
        await journey.pressText('Найти штрафы');
        await journey.waitFor(find.text('Превышение скорости'));
        await journey.pressText('Превышение скорости');
        await journey.pressText('Перейти к оплате');
        await journey.confirmAndCapture(
          'fines',
          total: const Money(75000),
          fee: const Money(0),
        );
        await journey.pressText('Готово');
        await journey.waitFor(find.text('Оплачен'));
        await journey.backToServices();

        expect(await environment.checkout.pendingStore.load(), isNull);
        if (!environment.http) {
          final submissions = environment.simulation.events.where(
            (event) =>
                event.method == 'POST' &&
                event.path == '/checkout/payments' &&
                event.phase == 'started',
          );
          expect(submissions, hasLength(4));
        }
        journey.passed('four_payments_without_unresolved_journal', {
          'confirmedPayments': 4,
          'journalEmpty': true,
        });

        await _analyticsJourney(journey);
        expect(tester.takeException(), isNull);
        journey.finish(environment);
      } catch (error) {
        journey.failed(error);
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
    timeout: const Timeout(Duration(minutes: 12)),
  );
}

Future<void> _referenceJourney(_Journey journey) async {
  final tester = journey.tester;
  journey.stage = 'reference account and pinned navigation';
  await journey.press(find.byKey(const ValueKey('home-account-main')));
  await journey.waitFor(find.byType(AccountDashboard));
  await journey.ready();
  final account = tester.widget<AccountDashboard>(
    find.byType(AccountDashboard),
  );
  expect(account.scrollController.offset, 0);
  await journey.capture('account_expanded');
  await tester.scrollUntilVisible(
    find.text('Управление картами'),
    280,
    scrollable: find
        .byWidgetPredicate(
          (w) =>
              w is Scrollable &&
              axisDirectionToAxis(w.axisDirection) == Axis.vertical,
        )
        .first,
    maxScrolls: 35,
  );
  await journey.reveal(find.text('Управление картами'));
  expect(find.byTooltip('Назад').hitTestable(), findsOneWidget);
  expect(account.scrollController.offset, greaterThan(208));
  await journey.capture('account_collapsed_bottom');
  await journey.press(find.byTooltip('Назад'));
  await journey.waitFor(find.byType(DsHomeHeader));
  journey.passed('reference_account_expanded_collapsed_pinned_back', {
    'account': 'main',
    'pinnedBackAtEnd': true,
  });
  journey.stage = 'reference synthetic topup';
  await journey.pressText('Пополнить');
  await journey.waitFor(find.byType(TextField));
  await journey.ready();
  await journey.type(find.byType(TextField), '12,34');
  await journey.pressText('Продолжить');
  await journey.pressText('Подтвердить');
  await journey.waitFor(find.text('Счёт пополнен'));
  await journey.capture('account_topup_result');
  await journey.pressText('К счёту');
  await journey.ready();
  journey.stage = 'reference topup income in history';
  // Returning from a flow preserves Home's position. Reach the overview by
  // scrolling, just as a user would, before looking up its offscreen action.
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('home-operations')),
    -200,
    scrollable: find
        .descendant(
          of: find.byKey(const PageStorageKey('home')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await journey.press(find.byKey(const ValueKey('home-operations')));
  await journey.waitFor(find.byType(HistoryScreen));
  await journey.ready();
  final history = tester
      .widget<HistorySliver>(find.byType(HistorySliver))
      .cubit;
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (history.state.loading && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(history.state.loading, isFalse);
  expect(
    history.state.pages.values
        .expand((p) => p.items)
        .any(
          (r) =>
              r.title == 'Пополнение с демо-карты' &&
              r.amount == const Money(1234),
        ),
    isTrue,
  );
  await journey.capture('reference_history');
  await journey.press(find.byTooltip('Назад'));
  await journey.ready();
  journey.passed('reference_topup_confirmation_and_history', {
    'amountMinor': 1234,
    'confirmedBeforeMutation': true,
    'incomeVisibleInHistory': true,
  });
}

AppEnvironment _environment() => AppEnvironment(
  cache: CacheStore(namespace: 'integration_bank_journey_responses'),
  journal: CacheStore(namespace: 'integration_bank_journey_journal'),
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

Future<void> _analyticsJourney(_Journey journey) async {
  final tester = journey.tester;
  journey.stage = 'analytics period and account filters';
  await journey.navigation('Аналитика');
  await journey.waitFor(find.byType(DsRankedBars));
  await journey.ready();
  await journey.pressText('Прошлый месяц');
  await journey.ready();
  await journey.pressText('Основной счёт');
  await journey.ready();
  expect(_choice(tester, 'Прошлый месяц').selected, isTrue);
  expect(_choice(tester, 'Основной счёт').selected, isTrue);
  expect(_choice(tester, 'Все счета').selected, isFalse);

  final period = tester
      .widget<DsText>(
        find.byWidgetPredicate(
          (widget) => widget is DsText && widget.text.contains('RUB · Москва'),
        ),
      )
      .text;
  final total = tester
      .widget<DsMetric>(
        find.byWidgetPredicate(
          (widget) => widget is DsMetric && widget.label == 'Расходы за период',
        ),
      )
      .value;
  final chart = tester.widget<DsRankedBars>(find.byType(DsRankedBars));
  final index = chart.points.indexWhere((point) => point.id == 'groceries');
  expect(
    index,
    isNonNegative,
    reason: 'Seeded previous month includes groceries',
  );
  final category = chart.points[index];
  final categoryLabel = '${index + 1}. ${category.label}';
  await journey.reveal(find.text(categoryLabel));
  final overviewScroll = journey.scrollPosition;
  await journey.capture('analytics_overview');
  await journey.pressText(categoryLabel);

  journey.stage = 'analytics category and merchant drill-down';
  await journey.waitFor(find.text('Детализация расходов'));
  await journey.waitFor(find.byType(DsChoice));
  await journey.ready();
  expect(find.text(category.label), findsWidgets);
  final drillPeriod = period.split(' · RUB').first;
  expect(find.text(drillPeriod), findsOneWidget);
  final merchantFinder = find.byType(DsChoice).first;
  final merchant = tester.widget<DsChoice>(merchantFinder).label;
  await journey.reveal(merchantFinder);
  final categoryScroll = journey.scrollPosition;
  await journey.capture('analytics_category');
  await journey.press(merchantFinder);
  await journey.waitFor(find.text('Детализация расходов'));
  await journey.ready();
  expect(find.text(drillPeriod), findsOneWidget);
  expect(
    find.byType(DsChoice),
    findsNothing,
    reason: 'A merchant drill-down must retain the merchant restriction',
  );

  final rowFinder = find.byType(DsTransactionTile).first;
  await tester.scrollUntilVisible(
    rowFinder,
    280,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 25,
  );
  await journey.reveal(rowFinder);
  final row = tester.widget<DsTransactionTile>(rowFinder);
  expect(row.title, merchant);
  final rowKey = row.key;
  expect(rowKey, isNotNull);
  final merchantScroll = journey.scrollPosition;
  final merchantFilter = tester
      .widget<HistorySliver>(find.byType(HistorySliver))
      .cubit
      .state
      .filter;
  await journey.capture('analytics_merchant');
  await journey.press(rowFinder);

  journey.stage = 'transaction details and preserved return context';
  await journey.waitFor(find.text('Детали операции'));
  expect(find.text(merchant), findsWidgets);
  expect(find.text(category.label), findsWidgets);
  expect(find.text('Основной счёт'), findsOneWidget);
  expect(find.text('Проведено'), findsOneWidget);
  await journey.capture('analytics_transaction');
  await journey.press(find.byTooltip('Назад'));
  await journey.waitFor(find.text('Детализация расходов'));
  await journey.ready();
  expect(find.byKey(rowKey!), findsOneWidget);
  expect(journey.scrollPosition, closeTo(merchantScroll, 2));
  // A restored scroll may put the period above the viewport. Verify the actual
  // value filter without moving the viewport away from the restored row.
  expect(
    tester.widget<HistorySliver>(find.byType(HistorySliver)).cubit.state.filter,
    merchantFilter,
  );

  await journey.platformBack();
  await journey.waitFor(find.byType(DsChoice));
  await journey.ready();
  expect(_choice(tester, merchant).label, merchant);
  expect(journey.scrollPosition, closeTo(categoryScroll, 2));
  await journey.platformBack();
  await journey.waitFor(find.byType(DsRankedBars));
  await journey.ready();
  final returned = tester.widget<DsRankedBars>(find.byType(DsRankedBars));
  expect(returned.selectedId, 'groceries');
  expect(_choice(tester, 'Прошлый месяц').selected, isTrue);
  expect(_choice(tester, 'Основной счёт').selected, isTrue);
  expect(journey.scrollPosition, closeTo(overviewScroll, 2));
  expect(
    tester
        .widget<DsText>(
          find.byWidgetPredicate(
            (widget) =>
                widget is DsText && widget.text.contains('RUB · Москва'),
          ),
        )
        .text,
    period,
  );
  expect(
    tester
        .widget<DsMetric>(
          find.byWidgetPredicate(
            (widget) =>
                widget is DsMetric && widget.label == 'Расходы за период',
          ),
        )
        .value,
    total,
  );
  await journey.capture('analytics_restored');
  journey.passed('analytics_category_merchant_transaction_return', {
    'period': period,
    'account': 'main',
    'category': category.id,
    'merchant': merchant,
    'transactionKey': rowKey.toString(),
    'totalBeforeAndAfter': total,
    'selectedCategoryRestored': true,
    'periodAndAccountRestored': true,
    'scrollRestoredAtAllLevels': true,
  });
}

DsChoice _choice(WidgetTester tester, String label) => tester.widget<DsChoice>(
  find.byWidgetPredicate(
    (widget) => widget is DsChoice && widget.label == label,
  ),
);

final class _Journey {
  _Journey(this.tester, this.binding);
  final WidgetTester tester;
  final IntegrationTestWidgetsFlutterBinding binding;
  final Stopwatch _watch = Stopwatch()..start();
  final List<Map<String, Object?>> _completed = [];
  final List<String> _screenshots = [];
  Map<String, Object?> _context = {};
  bool _surfaceConverted = false;
  String stage = 'initialization';

  double get scrollPosition => tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .pixels;

  void start(AppEnvironment environment) {
    _context = {
      'app': 'bank',
      'buildMode': _buildMode,
      'startedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'source': environment.sourceLabel,
      'httpKeepAlive': environment.http
          ? environment.api.persistentConnection
          : null,
      'networkProfile': environment.simulation.profile.toJson(),
      'cache': 'fresh isolated native Drift namespaces',
      'httpPrecondition': environment.http
          ? 'externally reset demo fixtures'
          : null,
    };
    _publish('running');
  }

  void passed(String scenario, Map<String, Object?> evidence) {
    _completed.add({
      'scenario': scenario,
      'status': 'passed',
      'elapsedMs': _watch.elapsedMilliseconds,
      'evidence': evidence,
    });
    _publish('running');
  }

  void finish(AppEnvironment environment) {
    _context = {
      ..._context,
      'finishedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'requestEvents': environment.http
          ? null
          : environment.simulation.events
                .map((event) => event.toJson())
                .toList(growable: false),
    };
    _publish('passed');
    _releaseReport({
      'app': 'bank',
      'buildMode': _buildMode,
      'status': 'passed',
      'source': environment.http ? 'http' : 'simulation',
      'httpKeepAlive': environment.http
          ? environment.api.persistentConnection
          : null,
      'networkProfile': environment.simulation.profile.name,
      'elapsedMs': _watch.elapsedMilliseconds,
      'stage': stage,
      'completedScenarios': [
        for (final scenario in _completed)
          {
            'scenario': scenario['scenario'],
            'status': scenario['status'],
            'elapsedMs': scenario['elapsedMs'],
          },
      ],
    });
  }

  void failed(Object error) {
    _context = {..._context, 'failedStage': stage, 'failure': error.toString()};
    _publish('failed');
    _releaseReport({
      'app': 'bank',
      'buildMode': _buildMode,
      'status': 'failed',
      'httpKeepAlive': _context['httpKeepAlive'],
      'elapsedMs': _watch.elapsedMilliseconds,
      'stage': stage,
      'failureType': error.runtimeType.toString(),
      'completedScenarios': [
        for (final scenario in _completed)
          {
            'scenario': scenario['scenario'],
            'status': scenario['status'],
            'elapsedMs': scenario['elapsedMs'],
          },
      ],
    });
  }

  void _publish(String status) => binding.reportData = {
    ...?binding.reportData,
    'journey': {
      ..._context,
      'status': status,
      'currentStage': stage,
      'elapsedMs': _watch.elapsedMilliseconds,
      'completedScenarios': _completed,
      'capturedScreenshots': _screenshots,
      'evidenceScope': 'physical UI journey; no frame-performance claim',
    },
  };

  Future<void> waitFor(Finder finder) async {
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      finder,
      findsWidgets,
      reason: 'Stage "$stage" did not reach $finder',
    );
    expect(tester.takeException(), isNull);
  }

  Future<void> ready() => waitForJourneyReadiness(tester, stage: stage);

  Future<void> reveal(Finder finder) async {
    await waitFor(finder);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> press(Finder finder) async {
    await reveal(finder);
    await tester.tap(finder);
    await tester.pump();
    await ready();
  }

  Future<void> pressText(String text) => press(find.text(text));

  Future<void> type(Finder finder, String text) async {
    await reveal(finder);
    await tester.enterText(finder, text);
    await tester.pump();
    final editable = tester.state<EditableTextState>(
      find.descendant(
        of: finder,
        matching: find.byType(EditableText),
        matchRoot: true,
      ),
    );
    expect(
      editable.widget.controller.text,
      text,
      reason: 'IME injection must update the actual editable field',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  Future<void> navigation(String label) async {
    stage = 'navigation: $label';
    final destination = find.descendant(
      of: find.byType(DsNavigationBar),
      matching: find.text(label),
    );
    await tester.tap(destination);
    await tester.pump();
    await ready();
  }

  Future<void> openService(String title) async {
    stage = 'service: $title';
    await pressText(title);
  }

  Future<void> platformBack() async {
    await tester.binding.handlePopRoute();
    await tester.pump();
    await ready();
  }

  Future<void> backToServices() async {
    final services = find.text('Повседневные дела в одном месте');
    // Cinema now traverses seats -> sessions -> movies -> service catalog.
    // Each system-back action must finish its real local step before the next.
    for (var step = 0; step < 3 && services.evaluate().isEmpty; step++) {
      await platformBack();
    }
    expect(
      services,
      findsOneWidget,
      reason: 'Three logical back steps must reach the payment catalog',
    );
  }

  Future<void> confirmAndCapture(
    String kind, {
    required Money total,
    required Money fee,
    bool ticket = false,
  }) async {
    stage = '$kind: confirmation and receipt';
    await waitFor(find.text('Подтвердить оплату'));
    await ready();
    final summary = tester.widget<DsPaymentSummary>(
      find.byType(DsPaymentSummary),
    );
    expect(summary.amount, AppFormats('ru').money(total));
    expect(
      summary.details.singleWhere((item) => item.label == 'Комиссия').value,
      AppFormats('ru').money(fee),
    );
    await pressText('Подтвердить оплату');
    await waitFor(find.text('Оплата выполнена'));
    if (ticket) {
      expect(find.text('Ваш билет'), findsOneWidget);
      expect(find.textContaining('seat-1'), findsWidgets);
    } else {
      expect(find.text('Квитанция'), findsOneWidget);
    }
    final result = tester.widget<DsStatus>(
      find.byWidgetPredicate(
        (widget) => widget is DsStatus && widget.title == 'Оплата выполнена',
      ),
    );
    expect(result.message, startsWith('Квитанция № '));
    await reveal(find.text('Оплата выполнена'));
    await capture('${kind}_${ticket ? 'ticket' : 'receipt'}');
    passed('${kind}_confirmed_${ticket ? 'ticket' : 'receipt'}', {
      'totalMinor': total.minor,
      'feeMinor': fee.minor,
      'currency': total.currency,
      'serverReceipt': result.message,
      'ticketShown': ticket,
    });
  }

  Future<void> capture(String name) async {
    if (!const bool.fromEnvironment(
      'JOURNEY_SCREENSHOTS',
      defaultValue: true,
    )) {
      return;
    }
    if (!_surfaceConverted && defaultTargetPlatform == TargetPlatform.android) {
      await binding.convertFlutterSurfaceToImage();
      _surfaceConverted = true;
      await tester.pump();
    }
    final screenshotName = 'bank_${_buildMode}_$name';
    await binding.takeScreenshot(screenshotName);
    _screenshots.add(screenshotName);
    _publish('running');
  }
}

// This intentionally excludes request data, amounts, recipients and exception
// messages. The AOT runner verifies framing/integrity and the framework verdict.
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
