library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:accounts/accounts.dart';
import 'package:app_foundation/app_foundation.dart';
import 'package:app_localizations/app_localizations.dart';
import 'package:bank_core/bank_core.dart';
import 'package:bank_artwork/bank_artwork.dart';
import 'package:cinema/cinema.dart';
import 'package:design_system/design_system.dart';
import 'package:fines/fines.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/mobile.dart';
import 'package:spending_analytics/spending_analytics.dart';
import 'package:transactions/transactions.dart';
import 'package:utilities/utilities.dart';

part 'src/reference_home.dart';
part 'src/reference_account.dart';
part 'src/card_management.dart';
part 'src/discovery.dart';

GoRoute _flowRoute({
  required String path,
  required Widget Function(BuildContext, GoRouterState) builder,
}) => GoRoute(
  path: path,
  pageBuilder: (context, state) => DsTransitionPage<void>(
    key: state.pageKey,
    child: builder(context, state),
  ),
);

/// Bank and catalog hosts share composition. Standalone fines never imports this.
class BankExperience extends StatefulWidget {
  const BankExperience({super.key, this.environment, this.catalog = false});
  final AppEnvironment? environment;
  final bool catalog;
  @override
  State<BankExperience> createState() => _BankExperienceState();
}

class _BankExperienceState extends State<BankExperience>
    with WidgetsBindingObserver {
  late final AppEnvironment _environment;
  late final AccountsCubit _accounts;
  late final HistoryCubit _history;
  late final ApiHistoryRepository _historyReader;
  late final ApiAnalyticsRepository _analytics;
  late final AnalyticsCubit _overview;
  final _cart = _DemoCart();
  late final AccountOperationJournal _operationJournal;
  late final GoRouter _router;
  final _dataRevision = ValueNotifier<int>(0);

  /// Notified when the content language changes; screens holding server
  /// texts reload them.
  final _languageChanges = ValueNotifier<int>(0);
  int _activityRevision = 0;
  int _languageRevision = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _environment = widget.environment ?? AppEnvironment.fromDefines();
    _operationJournal = CachedAccountOperationJournal(_environment.journal);
    _activityRevision = _environment.activityRevision;
    _languageRevision = _environment.languageRevision;
    _environment.addListener(_onEnvironmentChanged);
    _accounts = AccountsCubit(
      ApiAccountsRepository(_environment.api, _environment.cache),
    );
    _historyReader = ApiHistoryRepository(_environment.api, _environment.cache);
    _history = HistoryCubit(_historyReader);
    _analytics = ApiAnalyticsRepository(_environment.api, _environment.cache);
    _overview = AnalyticsCubit(
      _analytics,
      filter: ReportingPeriod.month(_environment.now()),
    );
    _router = GoRouter(
      initialLocation: widget.catalog ? '/catalog' : '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => Scaffold(
            body: shell,
            bottomNavigationBar: DsNavigationBar(
              selectedIndex: shell.currentIndex,
              onSelected: (index) =>
                  _environment.navigate(() => shell.goBranch(index)),
              destinations: [
                DsDestination(label: context.l10n.navHome, icon: DsIcons.bank),
                DsDestination(
                  label: context.l10n.navPayments,
                  icon: DsIcons.services,
                ),
                DsDestination(
                  label: context.l10n.navAnalytics,
                  icon: DsIcons.analytics,
                ),
                DsDestination(
                  label: context.l10n.navProfile,
                  icon: DsIcons.settings,
                ),
              ],
            ),
          ),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => _HomePage(
                    accounts: _accounts,
                    history: _history,
                    overview: _overview,
                    onAccount: (account) =>
                        context.push('/account/${account.id}'),
                    onHistory: () => context.push('/history'),
                    onTransfer: () => context.push('/account/main/phone'),
                    onTopUp: () => context.push('/account/main/topup'),
                    onQr: () => context.push('/scan'),
                    onProfile: () => context.go('/profile'),
                    onSearch: () => context.push('/search'),
                    onRewards: () => context.push('/discover/daily-cashback'),
                    onDiscover: (id) => context.push('/discover/$id'),
                    environment: _environment,
                    onAnalytics: () => context.go('/analytics'),
                    onServices: () => context.go('/services'),
                    onEntry: (entry) =>
                        context.push('/transaction', extra: entry),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/services',
                  builder: (context, state) => _ServicesPage(
                    onOpen: (name) => context.push('/pay/$name'),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/analytics',
                  builder: (context, state) =>
                      BlocBuilder<AccountsCubit, AccountsState>(
                        bloc: _accounts,
                        builder: (context, state) => AnalyticsPage(
                          reader: _analytics,
                          now: _environment.now,
                          accounts: state.accounts,
                          refreshSignal: _dataRevision,
                          onDrill: (filter) =>
                              context.push('/drill', extra: filter),
                        ),
                      ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (context, state) => ListenableBuilder(
                    listenable: _environment,
                    builder: (context, _) => DsPage(
                      title: context.l10n.profileTitle,
                      children: [
                        DsCard(
                          tone: DsCardTone.dark,
                          child: DsColumn(
                            children: [
                              const DsText(
                                'DemoBank',
                                style: DsTextStyle.headline,
                                tone: DsTone.inverse,
                              ),
                              DsText(
                                environmentSourceLabel(
                                  context.l10n,
                                  _environment,
                                ),
                                tone: DsTone.inverse,
                              ),
                            ],
                          ),
                        ),
                        DsListTile(
                          title: context.l10n.languageTitle,
                          subtitle: _environment.chosenLanguage == null
                              ? context.l10n.languageSystem(
                                  _environment.language.nativeName,
                                )
                              : _environment.language.nativeName,
                          icon: DsIcons.language,
                          onTap: () => context.push('/language'),
                        ),
                        DsListTile(
                          title: context.l10n.profileDemoSettings,
                          subtitle: context.l10n.profileDemoSettingsHint,
                          icon: DsIcons.settings,
                          onTap: () => context.push('/environment'),
                        ),
                        DsListTile(
                          title: context.l10n.profileDesignSystem,
                          subtitle: context.l10n.profileDesignSystemHint,
                          icon: DsIcons.design,
                          onTap: () => context.push('/catalog'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        _flowRoute(
          path: '/account/:id',
          builder: (context, state) => _AccountWorkspace(
            accountId: state.pathParameters['id']!,
            environment: _environment,
            accounts: _accounts,
            analytics: _analytics,
            onChanged: _refresh,
          ),
        ),
        _flowRoute(
          path: '/account/:id/:action',
          builder: (context, state) => _AccountActionPage(
            dataRevision: _dataRevision,
            accountId: state.pathParameters['id']!,
            action: state.pathParameters['action']!,
            operationJournal: _operationJournal,
            cardId: state.uri.queryParameters['card'],
            environment: _environment,
            accounts: _accounts,
            onChanged: _refresh,
          ),
        ),
        _flowRoute(
          path: '/account-services/:id',
          builder: (context, state) => _ServicesPage(
            onOpen: (name) => context.push(
              '/pay/$name?account=${state.pathParameters['id']}',
            ),
          ),
        ),
        _flowRoute(
          path: '/account-analytics/:id',
          builder: (context, state) => AnalyticsPage(
            reader: _analytics,
            now: _environment.now,
            accounts: _accounts.state.accounts,
            initialFilter: ReportingPeriod.month(_environment.now())
                .copyWith(accounts: [state.pathParameters['id']!]),
            refreshSignal: _dataRevision,
            onDrill: (filter) => context.push('/drill', extra: filter),
          ),
        ),
        _flowRoute(
          path: '/history',
          builder: (context, state) => HistoryScreen(
            title:
                state.extra is LedgerFilter &&
                    (state.extra! as LedgerFilter).cardId != null
                ? context.l10n.cardTransactions
                : null,
            reader: _historyReader,
            reloadSignal: _languageChanges,
            filter: state.extra is LedgerFilter
                ? state.extra! as LedgerFilter
                : null,
            onAnalytics: () {
              final filter = state.extra is LedgerFilter
                  ? state.extra! as LedgerFilter
                  : null;
              if (filter != null && filter.accounts.isNotEmpty) {
                context.push('/account-analytics/${filter.accounts.first}');
              } else {
                context.go('/analytics');
              }
            },
            onEntry: (entry) => context.push('/transaction', extra: entry),
          ),
        ),
        _flowRoute(
          path: '/discover/:id',
          builder: (context, state) =>
              _DiscoveryPage(id: state.pathParameters['id']!, cart: _cart),
        ),
        _flowRoute(
          path: '/cart',
          builder: (context, state) => _CartPage(cart: _cart),
        ),
        _flowRoute(
          path: '/scan',
          builder: (context, state) =>
              _QrDemoPage(accounts: _accounts.state.accounts),
        ),
        _flowRoute(
          path: '/search',
          builder: (context, state) =>
              _SearchPage(accounts: _accounts.state.accounts),
        ),
        _flowRoute(
          path: '/environment',
          builder: (context, state) =>
              EnvironmentPage(environment: _environment),
        ),
        _flowRoute(
          path: '/language',
          builder: (context, state) =>
              LanguageSettingsPage(environment: _environment),
        ),
        _flowRoute(
          path: '/catalog',
          builder: (context, state) => _CatalogPage(environment: _environment),
        ),
        _flowRoute(
          path: '/transaction',
          builder: (context, state) => state.extra is LedgerEntry
              ? TransactionDetails(
                  entry: state.extra! as LedgerEntry,
                  accountLabel: _accountLabel(
                    (state.extra! as LedgerEntry).accountId,
                  ),
                )
              : DsPage(
                  title: context.l10n.transactionMissingTitle,
                  children: [DsText(context.l10n.transactionMissingMessage)],
                ),
        ),
        _flowRoute(
          path: '/drill',
          builder: (context, state) => _DrillPage(
            filter:
                (state.extra is LedgerFilter
                        ? state.extra! as LedgerFilter
                        : ReportingPeriod.month(_environment.now()))
                    .copyWith(kind: EntryKind.expense),
            accounts: _accounts.state.accounts,
            history: _historyReader,
            analytics: _analytics,
            reloadSignal: _languageChanges,
            onEntry: (entry) => context.push('/transaction', extra: entry),
            onMerchant: (filter) => context.push('/drill', extra: filter),
          ),
        ),
        _flowRoute(
          path: '/pay/fines',
          builder: (context, state) => FinesFeature(
            repository: ApiFinesRepository(_environment.api),
            checkout: _environment.checkout.withAccountLabel(_accountLabel),
            accountId: state.uri.queryParameters['account'] ?? 'main',
            onPaymentChanged: (_) => _refresh(),
          ),
        ),
        _flowRoute(
          path: '/pay/utilities',
          builder: (context, state) => UtilitiesFeature(
            repository: ApiUtilitiesRepository(_environment.api),
            checkout: _environment.checkout.withAccountLabel(_accountLabel),
            accountId: state.uri.queryParameters['account'] ?? 'main',
            onPaymentChanged: (_) => _refresh(),
          ),
        ),
        _flowRoute(
          path: '/pay/mobile',
          builder: (context, state) => MobileFeature(
            repository: ApiMobileRepository(_environment.api),
            checkout: _environment.checkout.withAccountLabel(_accountLabel),
            accountId: state.uri.queryParameters['account'] ?? 'main',
            onPaymentChanged: (_) => _refresh(),
          ),
        ),
        _flowRoute(
          path: '/pay/cinema',
          builder: (context, state) => CinemaFeature(
            repository: ApiCinemaRepository(_environment.api),
            checkout: _environment.checkout.withAccountLabel(_accountLabel),
            accountId: state.uri.queryParameters['account'] ?? 'main',
            onPaymentChanged: (_) => _refresh(),
          ),
        ),
      ],
    );
    unawaited(_accounts.load());
    unawaited(_history.load());
    unawaited(_overview.load());
  }

  /// `null` lets the screen use a generic name in the interface language.
  String? _accountLabel(String id) {
    for (final account in _accounts.state.accounts) {
      if (account.id == id) return account.name;
    }
    return null;
  }

  /// [background] keeps a reader's place when new operations arrive; a
  /// language change replaces server texts at once instead.
  void _refresh({bool background = true}) {
    _analytics.invalidate();
    _dataRevision.value++;
    unawaited(_overview.load());
    unawaited(_accounts.load());
    unawaited(_history.load(background: background));
  }

  void _onEnvironmentChanged() {
    if (_languageRevision != _environment.languageRevision) {
      _languageRevision = _environment.languageRevision;
      _activityRevision = _environment.activityRevision;
      _languageChanges.value++;
      _refresh(background: false);
    } else if (_activityRevision != _environment.activityRevision) {
      _activityRevision = _environment.activityRevision;
      _refresh();
    }
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (locales != null) _environment.updateSystemLocales(locales);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _environment.removeListener(_onEnvironmentChanged);
    _dataRevision.dispose();
    _languageChanges.dispose();
    _cart.dispose();
    unawaited(_overview.close());
    _router.dispose();
    unawaited(_accounts.close());
    unawaited(_history.close());
    if (widget.environment == null) _environment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _environment,
    builder: (context, _) => MaterialApp.router(
      title: 'DemoBank',
      debugShowCheckedModeBanner: false,
      theme: DsAppTheme.light(),
      darkTheme: DsAppTheme.dark(),
      themeMode: _environment.theme,
      routerConfig: _router,
      onGenerateTitle: (context) => context.l10n.appTitle,
      locale: _environment.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        DsLocalizations.delegate,
      ],
      builder: (context, child) => DsArtworkSource(
        package: bankArtworkPackage,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations:
                MediaQuery.disableAnimationsOf(context) ||
                _environment.reduceMotion,
          ),
          child: child!,
        ),
      ),
    ),
  );
}

class _ServicesPage extends StatelessWidget {
  const _ServicesPage({required this.onOpen});
  final ValueChanged<String> onOpen;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DsPage(
      title: l10n.navPayments,
      subtitle: l10n.servicesSubtitle,
      children: [
        DsActionGrid(
          children: [
            for (final service in [
              (
                'utilities',
                l10n.servicesUtilities,
                l10n.servicesUtilitiesHint,
                DsIcons.home,
                DsTone.accent,
              ),
              (
                'mobile',
                l10n.mobileTitle,
                l10n.servicesMobileHint,
                DsIcons.mobile,
                DsTone.success,
              ),
              (
                'fines',
                l10n.servicesFines,
                l10n.servicesFinesHint,
                DsIcons.fines,
                DsTone.warning,
              ),
              (
                'cinema',
                l10n.cinemaTitle,
                l10n.servicesCinemaHint,
                DsIcons.cinema,
                DsTone.danger,
              ),
            ])
              DsServiceCard(
                title: service.$2,
                subtitle: service.$3,
                icon: service.$4,
                tone: service.$5,
                onTap: () => onOpen(service.$1),
              ),
          ],
        ),
        DsCard(tone: DsCardTone.subtle, child: DsText(l10n.servicesNotice)),
      ],
    );
  }
}

class _DrillPage extends StatefulWidget {
  const _DrillPage({
    required this.filter,
    required this.history,
    required this.analytics,
    required this.onEntry,
    required this.onMerchant,
    required this.accounts,
    required this.reloadSignal,
  });
  final LedgerFilter filter;
  final Listenable reloadSignal;
  final HistoryReader history;
  final AnalyticsReader analytics;
  final ValueChanged<LedgerEntry> onEntry;
  final ValueChanged<LedgerFilter> onMerchant;
  final List<Account> accounts;
  @override
  State<_DrillPage> createState() => _DrillPageState();
}

class _DrillPageState extends State<_DrillPage> {
  late final HistoryCubit _history;
  late final AnalyticsCubit _analytics;
  final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    _history = HistoryCubit(widget.history, filter: widget.filter);
    _analytics = AnalyticsCubit(widget.analytics, filter: widget.filter);
    unawaited(_history.load());
    unawaited(_analytics.load());
    _scroll.addListener(_more);
    widget.reloadSignal.addListener(_reload);
  }

  void _reload() {
    unawaited(_history.load());
    unawaited(_analytics.load());
  }

  void _more() {
    if (_scroll.position.extentAfter < _scroll.position.viewportDimension) {
      unawaited(_history.loadNext());
    }
  }

  @override
  void dispose() {
    widget.reloadSignal.removeListener(_reload);
    _scroll.removeListener(_more);
    _scroll.dispose();
    unawaited(_history.close());
    unawaited(_analytics.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final formats = context.formats;
    final filter = widget.filter;
    return DsScaffold(
      title: l10n.drillTitle,
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverToBoxAdapter(
            child: DsConstrained(
              child: DsPadding(
                child: DsColumn(
                  children: [
                    DsScreenHeader(
                      title: switch (filter.category) {
                        final category? => l10n.category(category, category),
                        null => l10n.drillComposition,
                      },
                      subtitle: filter.from != null && filter.to != null
                          ? formats.period(filter.from!, filter.to!)
                          : l10n.analyticsAllTime,
                    ),
                    DsText(
                      l10n.drillScope(
                        filter.currency,
                        l10n.commonMoscowTime,
                        filter.accounts.isEmpty
                            ? l10n.commonAllAccounts
                            : filter.accounts
                                  .map(
                                    (id) =>
                                        widget.accounts
                                            .where(
                                              (account) => account.id == id,
                                            )
                                            .firstOrNull
                                            ?.name ??
                                        id,
                                  )
                                  .join(', '),
                      ),
                      style: DsTextStyle.caption,
                    ),
                    BlocBuilder<AnalyticsCubit, AnalyticsState>(
                      bloc: _analytics,
                      builder: (context, state) {
                        final summary = state.summary;
                        return DsColumn(
                          children: [
                            if (widget.filter.merchant case final merchant?)
                              DsText(
                                l10n.drillMerchant(
                                  summary?.merchants
                                          .where(
                                            (point) => point.id == merchant,
                                          )
                                          .firstOrNull
                                          ?.label ??
                                      merchant,
                                ),
                                style: DsTextStyle.label,
                              ),
                            if (summary != null)
                              DsCard(
                                child: DsMetric(
                                  label: l10n.drillTotal,
                                  value: formats.money(summary.total),
                                  detail: l10n.drillTotalDetail(
                                    l10n.commonOperationsCount(summary.count),
                                  ),
                                ),
                              ),
                            if (state.failed)
                              DsStatus(
                                title: l10n.analyticsFailed,
                                kind: DsStatusKind.error,
                                action: DsButton(
                                  label: l10n.commonRetry,
                                  onPressed: () =>
                                      unawaited(_analytics.retry()),
                                ),
                              ),
                            if (summary != null &&
                                widget.filter.merchant == null)
                              DsSection(
                                title: l10n.analyticsMerchants,
                                child: DsFlow(
                                  children: [
                                    for (final merchant in summary.merchants)
                                      DsChoice(
                                        label: merchant.label,
                                        selected: false,
                                        onSelected: (_) => widget.onMerchant(
                                          widget.filter.copyWith(
                                            merchant: merchant.id,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    DsButton(
                      label: l10n.drillReset,
                      variant: DsButtonVariant.quiet,
                      onPressed: () => widget.onMerchant(
                        widget.filter.copyWith(
                          clearCategory: true,
                          clearMerchant: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          HistorySliver(
            cubit: _history,
            controller: _scroll,
            onEntry: widget.onEntry,
            showFilters: false,
          ),
        ],
      ),
    );
  }
}

class _CatalogPage extends StatelessWidget {
  const _CatalogPage({required this.environment});
  final AppEnvironment environment;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final formats = context.formats;
    return DsPage(
      title: l10n.profileDesignSystem,
      subtitle: l10n.catalogSubtitle,
      children: [
        DsFlow(
          children: [
            DsButton(
              label: l10n.catalogSetUp,
              onPressed: () => context.push('/environment'),
            ),
            DsButton(
              label: l10n.catalogOpenBank,
              variant: DsButtonVariant.secondary,
              onPressed: () => context.go('/'),
            ),
          ],
        ),
        DsSection(
          title: l10n.catalogTypography,
          child: DsColumn(
            children: [
              DsText(l10n.catalogDisplay, style: DsTextStyle.display),
              DsText(l10n.catalogHeadline, style: DsTextStyle.headline),
              DsText(l10n.catalogBody),
              DsText(l10n.catalogCaption, style: DsTextStyle.caption),
            ],
          ),
        ),
        DsSection(
          title: l10n.catalogActions,
          child: DsFlow(
            children: [
              for (final variant in DsButtonVariant.values)
                DsButton(
                  label: variant.name,
                  variant: variant,
                  onPressed: () {},
                ),
              DsButton(label: l10n.catalogDisabled, onPressed: null),
            ],
          ),
        ),
        DsSection(
          title: l10n.catalogInput,
          child: DsColumn(
            children: [
              DsField(
                label: l10n.utilitiesAccountLabel,
                hint: l10n.catalogEnterNumber,
              ),
              DsField(
                label: l10n.catalogInputError,
                hint: l10n.paymentErrorValidation,
              ),
            ],
          ),
        ),
        DsSection(
          title: l10n.catalogStates,
          child: DsColumn(
            children: [
              DsStatus(
                title: DsLocalizations.of(context).loadingData,
                kind: DsStatusKind.loading,
              ),
              DsStatus(title: l10n.historyEmptyTitle, kind: DsStatusKind.empty),
              DsStatus(
                title: l10n.errorOffline,
                message: l10n.commonRetry,
                kind: DsStatusKind.error,
              ),
              DsStatus(
                title: l10n.checkoutSucceeded,
                kind: DsStatusKind.success,
              ),
            ],
          ),
        ),
        DsSection(
          title: l10n.catalogScenarios,
          child: DsColumn(
            children: [
              for (final route in [
                ('/history', l10n.catalogScenarioHistory),
                ('/account/main', l10n.catalogScenarioAccount),
                ('/discover/shopping', l10n.catalogScenarioShop),
                ('/analytics', l10n.catalogScenarioAnalytics),
                ('/pay/utilities', l10n.servicesUtilities),
                ('/pay/mobile', l10n.mobileTitle),
                ('/pay/fines', l10n.servicesFines),
                ('/pay/cinema', l10n.cinemaTitle),
              ])
                DsListTile(
                  title: route.$2,
                  icon: DsIcons.open,
                  onTap: () => context.push(route.$1),
                ),
            ],
          ),
        ),
        DsSection(
          title: l10n.catalogCards,
          child: DsColumn(
            children: [
              DsOverviewCard(
                title: l10n.accountOperations,
                value: formats.money(const Money(8632045)),
                detail: l10n.catalogExample,
                footer: DsSpendingStrip(
                  points: [
                    DsChartPoint(
                      id: 'a',
                      label: l10n.categoryName('shopping'),
                      value: 6,
                    ),
                    DsChartPoint(
                      id: 'b',
                      label: l10n.categoryName('dining'),
                      value: 3,
                    ),
                    DsChartPoint(
                      id: 'c',
                      label: l10n.categoryName('transport'),
                      value: 1,
                    ),
                  ],
                ),
                onTap: () => context.push('/history'),
              ),
              DsAccountProduct(
                title: l10n.catalogDemoCard,
                balance: formats.money(const Money(5632040)),
                cards: const [DsBankCardData('demo-card', '0000')],
                onTap: () => context.push('/account/main'),
              ),
              DsShortcutBar(
                actions: [
                  DsShortcut(
                    l10n.accountTopUp,
                    DsIcons.add,
                    () => context.push('/account/main/topup'),
                  ),
                  DsShortcut(
                    l10n.catalogTransfer,
                    DsIcons.transfer,
                    () => context.push('/account/main/pay'),
                  ),
                ],
              ),
              DsLimitRow(
                title: l10n.catalogLimit,
                detail: l10n.commonAvailableAmount(
                  formats.money(const Money(7500000)),
                ),
                fraction: .75,
              ),
              DsOfferBanner(
                title: l10n.catalogGifts,
                detail: l10n.catalogBanner,
                art: DsArt.gift,
                onTap: () => context.push('/discover/gift'),
              ),
            ],
          ),
        ),
        DsCard(tone: DsCardTone.subtle, child: DsText(l10n.catalogTokens)),
      ],
    );
  }
}
