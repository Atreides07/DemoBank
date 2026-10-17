library;

import 'dart:async';
import 'dart:convert';
import 'package:checkout/checkout.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_storage/local_storage.dart';
import 'package:network_client/network_client.dart';
import 'package:network_simulation/network_simulation.dart';
import 'package:payment_domain/payment_domain.dart';

export 'src/error_reporting.dart';

/// Application-scoped resources; contains no bank-specific feature dependency.
final class AppEnvironment extends ChangeNotifier {
  AppEnvironment({
    CacheStore? cache,
    CacheStore? journal,
    SimulationAdapter? simulation,
    NetworkProfile profile = NetworkProfile.normal,
    int seed = 42,
    this.http = false,
    this.httpKeepAlive = true,
    Uri? baseUri,
    ApiRequestObserver? onApiEvent,
  }) : scopeId = storageScope(
         http: http,
         baseUri: baseUri,
         seed: simulation?.transport.seed ?? seed,
       ),
       cache =
           cache ??
           CacheStore(
             namespace:
                 '${storageScope(http: http, baseUri: baseUri, seed: simulation?.transport.seed ?? seed)}_responses',
           ),
       // Recovery data is never evicted and never silently discarded.
       journal =
           journal ??
           CacheStore(
             namespace:
                 '${storageScope(http: http, baseUri: baseUri, seed: simulation?.transport.seed ?? seed)}_journal',
             durable: true,
           ) {
    this.simulation =
        simulation ??
        SimulationAdapter(
          seed: seed,
          profile: profile,
          api: DemoApi(
            loadState: _loadSimulatorState,
            saveState: (state) => this.journal.write(
              'simulator_state',
              state,
              ttl: const Duration(days: 365),
            ),
          ),
        );
    api = ApiClient(
      baseUri: baseUri ?? Uri.parse('https://demo.invalid'),
      adapter: http ? null : this.simulation,
      persistentConnection: httpKeepAlive,
      onEvent: (event) {
        _apiEvents.add(event);
        if (_apiEvents.length > 1000) _apiEvents.removeAt(0);
        return onApiEvent?.call(event);
      },
    );
    checkout = CheckoutDependencies(
      gateway: ApiPaymentGateway(api),
      pendingStore: CallbackPendingPaymentStore(
        read: () async {
          final entry = await this.journal.read('pending_payment');
          if (entry == null) return null;
          final value = entry.value['value'];
          if (value is! String) {
            throw const FormatException('Pending payment journal entry');
          }
          return value;
        },
        write: (value) async {
          if (value == null) {
            await this.journal.delete('pending_payment');
          } else {
            await this.journal.write('pending_payment', {
              'value': value,
            }, ttl: const Duration(days: 365));
          }
        },
        quarantine: () => this.journal.quarantine('pending_payment'),
      ),
      clock: const SystemPaymentClock(),
      keyFactory: SecureIdempotencyKeyFactory(),
    );
  }
  factory AppEnvironment.fromDefines({ApiRequestObserver? onApiEvent}) =>
      AppEnvironment(
        onApiEvent: onApiEvent,
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
  final CacheStore cache;
  final CacheStore journal;
  final String scopeId;
  late final SimulationAdapter simulation;
  final bool http;
  final bool httpKeepAlive;
  late final ApiClient api;
  late final CheckoutDependencies checkout;
  final List<ApiRequestEvent> _apiEvents = [];
  List<ApiRequestEvent> get apiEvents => List.unmodifiable(_apiEvents);
  ThemeMode theme = ThemeMode.light;
  bool reduceMotion = false;
  bool motionComparison = false;
  String cacheMessage = 'Кеш используется автоматически';
  String? activityMessage;
  bool activityInProgress = false;
  int activityRevision = 0;
  final List<double> navigationFirstFrameMs = [];
  bool _disposed = false;
  String get sourceLabel => http
      ? 'Сетевой транспорт · тестовый сервер'
      : 'Локальный симулятор · seed ${simulation.transport.seed}';

  /// The demo calendar shared with the ledger backend; see
  /// [DemoApi.businessNow]. Reporting periods computed from it include every
  /// payment and operation created during the session.
  DateTime now() => DemoApi.businessNow;

  /// Simulator state is synthetic and can be regenerated, unlike the payment
  /// journal: an unreadable copy is replaced by fresh fixtures instead of
  /// leaving the local backend unable to start.
  Future<Map<String, dynamic>?> _loadSimulatorState() async {
    try {
      return (await journal.read('simulator_state'))?.value;
    } on FormatException {
      await journal.delete('simulator_state');
      return null;
    }
  }

  /// Stable across process restarts and distinct for every backend or fixture.
  /// A pending simulated payment can never be restored against an HTTP server.
  static String storageScope({
    required bool http,
    Uri? baseUri,
    int seed = 42,
  }) {
    if (!http) return 'simulation_$seed';
    final uri = baseUri ?? Uri.parse('https://demo.invalid');
    final origin = '${uri.scheme}://${uri.host}:${uri.port}${uri.path}';
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(origin)) {
      hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
    }
    return 'http_${hash.toRadixString(16)}';
  }

  /// Enabled only in a profile benchmark. Measures the real navigation handler
  /// through the first framework frame, without test-driver dispatch overhead.
  void navigate(VoidCallback action) {
    if (!kProfileMode || !const bool.fromEnvironment('PERF_PROBE')) {
      action();
      return;
    }
    final watch = Stopwatch()..start();
    action();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigationFirstFrameMs.add(watch.elapsedMicroseconds / 1000);
    });
  }

  void setTheme(bool dark) {
    theme = dark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void setReducedMotion(bool value) {
    reduceMotion = value;
    notifyListeners();
  }

  void setComparison(bool value) {
    motionComparison = value;
    notifyListeners();
  }

  void setProfile(NetworkProfile value) {
    simulation.profile = value;
    notifyListeners();
  }

  Future<void> clearCache() async {
    try {
      await cache.clear();
      cacheMessage = 'Кеш очищен. Откройте экран заново для холодной загрузки.';
    } on Exception {
      cacheMessage = 'Не удалось очистить кеш. Повторите действие.';
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> expireCache() async {
    try {
      await cache.expireAll();
      cacheMessage = 'Кеш помечен устаревшим.';
    } on Exception {
      cacheMessage =
          'Не удалось изменить актуальность кеша. Повторите действие.';
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> addActivity() async {
    if (activityInProgress) return;
    activityInProgress = true;
    activityMessage = null;
    notifyListeners();
    try {
      await api.post('/v1/demo/activity', data: {'changeStatus': true});
      activityRevision++;
      activityMessage = 'Операция добавлена. Обновите историю для применения.';
    } on ApiFailure catch (error) {
      activityMessage = error.message;
    } on Exception {
      activityMessage = 'Не удалось добавить операцию. Повторите действие.';
    } finally {
      activityInProgress = false;
      if (!_disposed) notifyListeners();
    }
  }

  String diagnosticJson() => const JsonEncoder.withIndent('  ').convert({
    'source': sourceLabel,
    'httpKeepAlive': http && !kIsWeb ? api.persistentConnection : null,
    'profile': simulation.profile.toJson(),
    'events': apiEvents.map((event) => event.toJson()).toList(),
    if (!http)
      'simulatedTransportEvents': simulation.events
          .map((event) => event.toJson())
          .toList(),
  });
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    api.close();
    unawaited(cache.close());
    if (!identical(cache, journal)) unawaited(journal.close());
    super.dispose();
  }
}

class EnvironmentPage extends StatelessWidget {
  const EnvironmentPage({super.key, required this.environment});
  final AppEnvironment environment;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: environment,
    builder: (context, _) => DsPage(
      title: 'Среда демонстрации',
      subtitle: environment.sourceLabel,
      children: [
        DsSection(
          title: 'Сеть',
          subtitle: 'Профиль меняет транспорт, сохраняя состояние данных',
          child: DsFlow(
            children: [
              for (final profile in [
                NetworkProfile.normal,
                NetworkProfile.slow,
                NetworkProfile.unstable,
                NetworkProfile.offline,
              ])
                DsChoice(
                  label: switch (profile.name) {
                    'normal' => 'Обычная',
                    'slow' => 'Медленная',
                    'unstable' => 'Нестабильная',
                    _ => 'Нет связи',
                  },
                  selected: environment.simulation.profile == profile,
                  onSelected: environment.http
                      ? null
                      : (_) => environment.setProfile(profile),
                ),
            ],
          ),
        ),
        DsCard(
          child: DsColumn(
            children: [
              DsText('Внешний вид', style: DsTextStyle.title),
              DsCheckbox(
                label: 'Тёмная тема',
                value: environment.theme == ThemeMode.dark,
                onChanged: environment.setTheme,
              ),
              DsCheckbox(
                label: 'Уменьшить движение',
                value: environment.reduceMotion,
                onChanged: environment.setReducedMotion,
              ),
              DsCheckbox(
                label: 'Сравнить историю без перехода',
                value: environment.motionComparison,
                onChanged: environment.setComparison,
              ),
            ],
          ),
        ),
        DsSection(
          title: 'Состояние кеша',
          subtitle: environment.cacheMessage,
          child: DsFlow(
            children: [
              DsButton(
                label: 'Пустой кеш',
                onPressed: () => unawaited(environment.clearCache()),
              ),
              DsButton(
                label: 'Устаревший кеш',
                variant: DsButtonVariant.secondary,
                onPressed: () => unawaited(environment.expireCache()),
              ),
            ],
          ),
        ),
        DsCard(
          tone: DsCardTone.subtle,
          child: DsColumn(
            children: [
              const DsText('Тестовые события', style: DsTextStyle.title),
              const DsText(
                'Добавьте операцию, вернитесь в историю и обновите её во время чтения. Действие «Есть новые операции» применит изменения с сохранением контекста.',
              ),
              DsButton(
                label: 'Новая операция и смена статуса',
                icon: DsIcons.add,
                onPressed: environment.activityInProgress
                    ? null
                    : () => unawaited(environment.addActivity()),
              ),
              if (environment.activityMessage case final message?)
                DsText(message),
            ],
          ),
        ),
        DsSection(
          title: 'Диагностика',
          subtitle: 'Без реквизитов и содержимого запросов',
          child: DsColumn(
            children: [
              DsText(
                'Сетевых событий: ${environment.apiEvents.length} · профиль ${environment.simulation.profile.name}',
              ),
              DsButton(
                label: 'Показать журнал',
                variant: DsButtonVariant.quiet,
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Сетевые события'),
                    content: SingleChildScrollView(
                      child: SelectableText(environment.diagnosticJson()),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Закрыть'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const DsText(
          'Для реального HTTPS-стенда приложение запускается с DATA_SOURCE=http и API_BASE_URL. Настройка выполняется в оболочке, код фич остаётся общим.',
        ),
      ],
    ),
  );
}
