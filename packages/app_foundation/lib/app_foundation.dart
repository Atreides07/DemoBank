library;

import 'dart:async';
import 'dart:convert';

import 'package:app_localizations/app_localizations.dart';
import 'package:checkout/checkout.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_storage/local_storage.dart';
import 'package:network_client/network_client.dart';
import 'package:network_simulation/network_simulation.dart';
import 'package:payment_domain/payment_domain.dart';

import 'src/language_scoped_cache.dart';

export 'src/environment_page.dart';
export 'src/error_reporting.dart';
export 'src/language_settings.dart';

/// Result of the last cache action requested on the demo settings screen.
enum CacheNotice { automatic, cleared, clearFailed, expired, expireFailed }

/// Result of the last demo activity request.
enum ActivityOutcome { added, failed }

/// Application-scoped resources; contains no bank-specific feature dependency.
final class AppEnvironment extends ChangeNotifier {
  /// [preferences] keeps choices that belong to the device rather than to a
  /// backend, such as the interface language; by default it is in memory, and
  /// [AppEnvironment.fromDefines] makes it durable. [systemLocales] are the
  /// device language preferences used while no language has been chosen.
  AppEnvironment({
    CacheStore? cache,
    CacheStore? journal,
    CacheStore? preferences,
    SimulationAdapter? simulation,
    NetworkProfile profile = NetworkProfile.normal,
    int seed = 42,
    this.http = false,
    this.httpKeepAlive = true,
    Uri? baseUri,
    ApiRequestObserver? onApiEvent,
    AppLanguage? language,
    List<Locale> systemLocales = const [Locale('ru')],
  }) : scopeId = storageScope(
         http: http,
         baseUri: baseUri,
         seed: simulation?.transport.seed ?? seed,
       ),
       _responses =
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
           ),
       preferences = preferences ?? MemoryCacheStore(durable: true),
       _chosenLanguage = language,
       _systemLocales = List.unmodifiable(systemLocales) {
    this.cache = LanguageScopedCache(_responses, () => this.language.code);
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
      acceptLanguage: this.language.code,
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

  /// Application composition defaults to local demo data without a server.
  /// `--dart-define=DATA_SOURCE=http` explicitly enables the real transport.
  /// Durable preferences use the device language list.
  /// `--dart-define=APP_LANGUAGE=en` pins a language,
  /// as does [language] (used by device tests that assert on text).
  factory AppEnvironment.fromDefines({
    ApiRequestObserver? onApiEvent,
    AppLanguage? language,
  }) => AppEnvironment(
    onApiEvent: onApiEvent,
    preferences: CacheStore(namespace: 'preferences', durable: true),
    language:
        language ??
        AppLanguage.tryParse(const String.fromEnvironment('APP_LANGUAGE')),
    systemLocales: PlatformDispatcher.instance.locales,
    http:
        const String.fromEnvironment(
          'DATA_SOURCE',
          defaultValue: 'simulation',
        ) ==
        'http',
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

  /// Responses in the current content language. Server texts (names,
  /// descriptions, rejection messages) follow `Accept-Language`, so cached
  /// copies are kept per language; clearing applies to all of them.
  late final CacheStore cache;
  final CacheStore _responses;
  final CacheStore journal;
  final CacheStore preferences;
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
  CacheNotice cacheNotice = CacheNotice.automatic;
  ActivityOutcome? activityOutcome;
  ApiFailure? activityFailure;
  bool activityInProgress = false;
  int activityRevision = 0;
  final List<double> navigationFirstFrameMs = [];
  bool _disposed = false;

  AppLanguage? _chosenLanguage;
  List<Locale> _systemLocales;

  /// Incremented whenever the effective language changes, so hosts can reload
  /// server content that was received in the previous language.
  int languageRevision = 0;

  /// The interface and content language in effect.
  AppLanguage get language =>
      _chosenLanguage ?? AppLanguage.resolve(_systemLocales);

  /// The explicit choice, or `null` while following the device language.
  AppLanguage? get chosenLanguage => _chosenLanguage;

  /// The language the device prefers, when it is supported.
  AppLanguage get systemLanguage => AppLanguage.resolve(_systemLocales);

  Locale get locale => language.locale;

  /// Language-neutral description of the data source for diagnostics and
  /// device reports. Screens describe the source in the current language.
  String get sourceLabel =>
      http ? 'http' : 'simulation · seed ${simulation.transport.seed}';

  /// The demo calendar shared with the ledger backend; see
  /// [DemoApi.businessNow]. Reporting periods computed from it include every
  /// payment and operation created during the session.
  DateTime now() => DemoApi.businessNow;

  /// Applies a stored language choice. Call before the first frame so the
  /// interface never flashes in a different language.
  Future<void> restorePreferences() async {
    try {
      final entry = await preferences.read('language');
      final stored = AppLanguage.tryParse(entry?.value['code'] as String?);
      if (stored == null || stored == _chosenLanguage) return;
      final before = language;
      _chosenLanguage = stored;
      _languageChanged(before);
    } on Object catch (error, stackTrace) {
      // A missing preference only means the device language is used.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'app_foundation',
          context: ErrorDescription('while restoring preferences'),
        ),
      );
    }
  }

  /// Chooses a language, or follows the device again when [language] is null.
  /// The interface switches immediately; the choice is then persisted.
  Future<void> setLanguage(AppLanguage? language) async {
    final before = this.language;
    _chosenLanguage = language;
    _languageChanged(before);
    try {
      if (language == null) {
        await preferences.delete('language');
      } else {
        await preferences.write('language', {
          'code': language.code,
        }, ttl: const Duration(days: 3650));
      }
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'app_foundation',
          context: ErrorDescription('while saving the language choice'),
        ),
      );
    }
  }

  /// Device language preferences changed (Android per-app or system setting).
  void updateSystemLocales(List<Locale> locales) {
    final before = language;
    _systemLocales = List.unmodifiable(locales);
    _languageChanged(before);
  }

  void _languageChanged(AppLanguage before) {
    if (_disposed) return;
    api.acceptLanguage = language.code;
    if (language == before) {
      notifyListeners();
      return;
    }
    languageRevision++;
    notifyListeners();
  }

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
      cacheNotice = CacheNotice.cleared;
    } on Exception {
      cacheNotice = CacheNotice.clearFailed;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> expireCache() async {
    try {
      await cache.expireAll();
      cacheNotice = CacheNotice.expired;
    } on Exception {
      cacheNotice = CacheNotice.expireFailed;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> addActivity() async {
    if (activityInProgress) return;
    activityInProgress = true;
    activityOutcome = null;
    activityFailure = null;
    notifyListeners();
    try {
      await api.post('/v1/demo/activity', data: {'changeStatus': true});
      activityRevision++;
      activityOutcome = ActivityOutcome.added;
    } on ApiFailure catch (error) {
      activityOutcome = ActivityOutcome.failed;
      activityFailure = error;
    } on Exception {
      activityOutcome = ActivityOutcome.failed;
    } finally {
      activityInProgress = false;
      if (!_disposed) notifyListeners();
    }
  }

  String diagnosticJson() => const JsonEncoder.withIndent('  ').convert({
    'source': sourceLabel,
    'language': language.code,
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
    final stores = <CacheStore>[];
    for (final store in [_responses, journal, preferences]) {
      if (!stores.any((known) => identical(known, store))) stores.add(store);
    }
    for (final store in stores) {
      unawaited(store.close());
    }
    super.dispose();
  }
}
