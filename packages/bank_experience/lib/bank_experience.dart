library;

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:accounts/accounts.dart';
import 'package:app_foundation/app_foundation.dart';
import 'package:bank_core/bank_core.dart';
import 'package:bank_artwork/bank_artwork.dart';
import 'package:cinema/cinema.dart';
import 'package:design_system/design_system.dart';
import 'package:fines/fines.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/mobile.dart';
import 'package:spending_analytics/spending_analytics.dart';
import 'package:transactions/transactions.dart';
import 'package:utilities/utilities.dart';

part 'src/reference_home.dart';
part 'src/reference_account.dart';
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

class _BankExperienceState extends State<BankExperience> {
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
  int _activityRevision = 0;
  @override
  void initState() {
    super.initState();
    _environment = widget.environment ?? AppEnvironment.fromDefines();
    _operationJournal = CachedAccountOperationJournal(_environment.journal);
    _activityRevision = _environment.activityRevision;
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
              destinations: const [
                DsDestination(label: 'Главная', icon: DsIcons.dashboard),
                DsDestination(label: 'Аналитика', icon: DsIcons.analytics),
                DsDestination(label: 'Платежи', icon: DsIcons.services),
                DsDestination(label: 'Профиль', icon: DsIcons.settings),
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
                  path: '/profile',
                  builder: (context, state) => DsPage(
                    title: 'Ваше пространство',
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
                              _environment.sourceLabel,
                              tone: DsTone.inverse,
                            ),
                          ],
                        ),
                      ),
                      DsListTile(
                        title: 'Настройки демонстрации',
                        subtitle: 'Сеть, темы, кеш и движение',
                        icon: DsIcons.settings,
                        onTap: () => context.push('/environment'),
                      ),
                      DsListTile(
                        title: 'Дизайн-система',
                        subtitle: 'Компоненты и отдельный просмотр экранов',
                        icon: DsIcons.design,
                        onTap: () => context.push('/catalog'),
                      ),
                    ],
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
            initialFilter: ReportingPeriod.month(
              _environment.now(),
            ).copyWith(accounts: [state.pathParameters['id']!]),
            onDrill: (filter) => context.push('/drill', extra: filter),
          ),
        ),
        _flowRoute(
          path: '/history',
          builder: (context, state) => HistoryScreen(
            reader: _historyReader,
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
              : const DsPage(
                  title: 'Операция не выбрана',
                  children: [DsText('Откройте операцию из истории.')],
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

  String _accountLabel(String id) {
    for (final account in _accounts.state.accounts) {
      if (account.id == id) return account.name;
    }
    return 'Банковский счёт';
  }

  void _refresh() {
    _dataRevision.value++;
    unawaited(_overview.load());
    unawaited(_accounts.load());
    unawaited(_history.load(background: true));
  }

  void _onEnvironmentChanged() {
    if (_activityRevision != _environment.activityRevision) {
      _activityRevision = _environment.activityRevision;
      _refresh();
    }
  }

  @override
  void dispose() {
    _environment.removeListener(_onEnvironmentChanged);
    _dataRevision.dispose();
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
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
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
  Widget build(BuildContext context) => DsPage(
    title: 'Платежи',
    subtitle: 'Повседневные дела в одном месте',
    children: [
      DsActionGrid(
        children: [
          for (final service in const [
            ('utilities', 'ЖКХ', 'Счета за дом', DsIcons.home, DsTone.accent),
            (
              'mobile',
              'Мобильная связь',
              'Пополнить номер',
              DsIcons.mobile,
              DsTone.success,
            ),
            (
              'fines',
              'Штрафы',
              'Проверить и оплатить',
              DsIcons.fines,
              DsTone.warning,
            ),
            (
              'cinema',
              'Кино',
              'Билеты на сеанс',
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
      const DsCard(
        tone: DsCardTone.subtle,
        child: DsText(
          'Все платежи используют общий процесс подтверждения. Комиссия и итоговая сумма видны до оплаты.',
        ),
      ),
    ],
  );
}

class _DrillPage extends StatefulWidget {
  const _DrillPage({
    required this.filter,
    required this.history,
    required this.analytics,
    required this.onEntry,
    required this.onMerchant,
    required this.accounts,
  });
  final LedgerFilter filter;
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
  }

  void _more() {
    if (_scroll.position.extentAfter < _scroll.position.viewportDimension) {
      unawaited(_history.loadNext());
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_more);
    _scroll.dispose();
    unawaited(_history.close());
    unawaited(_analytics.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DsScaffold(
    title: 'Детализация расходов',
    body: CustomScrollView(
      controller: _scroll,
      slivers: [
        SliverToBoxAdapter(
          child: DsConstrained(
            child: DsPadding(
              child: DsColumn(
                children: [
                  DsScreenHeader(
                    title:
                        categoryLabels[widget.filter.category] ??
                        'Состав расходов',
                    subtitle: ReportingPeriod.label(widget.filter),
                  ),
                  DsText(
                    '${widget.filter.currency} · Москва · ${widget.filter.accounts.isEmpty ? 'Все счета' : widget.filter.accounts.map((id) => widget.accounts.where((account) => account.id == id).firstOrNull?.name ?? id).join(', ')}',
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
                              'Получатель: ${summary?.merchants.where((point) => point.id == merchant).firstOrNull?.label ?? merchant}',
                              style: DsTextStyle.label,
                            ),
                          if (summary != null)
                            DsCard(
                              child: DsMetric(
                                label: 'Всего по выбранным условиям',
                                value: summary.total.format(),
                                detail:
                                    '${summary.count} операций · полная выборка',
                              ),
                            ),
                          if (state.error != null)
                            DsStatus(
                              title: state.error!,
                              kind: DsStatusKind.error,
                              action: DsButton(
                                label: 'Повторить',
                                onPressed: () => unawaited(_analytics.load()),
                              ),
                            ),
                          if (summary != null && widget.filter.merchant == null)
                            DsSection(
                              title: 'Получатели',
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
                    label: 'Сбросить уточнение',
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

class _CatalogPage extends StatelessWidget {
  const _CatalogPage({required this.environment});
  final AppEnvironment environment;
  @override
  Widget build(BuildContext context) => DsPage(
    title: 'Дизайн-система',
    subtitle: 'Компоненты, состояния и рабочие экраны',
    children: [
      DsFlow(
        children: [
          DsButton(
            label: 'Настроить тему и сеть',
            onPressed: () => context.push('/environment'),
          ),
          DsButton(
            label: 'Открыть банк',
            variant: DsButtonVariant.secondary,
            onPressed: () => context.go('/'),
          ),
        ],
      ),
      const DsSection(
        title: 'Типографика',
        child: DsColumn(
          children: [
            DsText('Деньги под контролем', style: DsTextStyle.display),
            DsText(
              'Интерфейс с понятной иерархией',
              style: DsTextStyle.headline,
            ),
            DsText('Основной текст и доступные подписи'),
            DsText(
              'Описание · метаданные · подсказки',
              style: DsTextStyle.caption,
            ),
          ],
        ),
      ),
      DsSection(
        title: 'Действия',
        child: DsFlow(
          children: [
            for (final variant in DsButtonVariant.values)
              DsButton(label: variant.name, variant: variant, onPressed: () {}),
            const DsButton(label: 'Недоступно', onPressed: null),
          ],
        ),
      ),
      const DsSection(
        title: 'Ввод',
        child: DsColumn(
          children: [
            DsField(label: 'Лицевой счёт', hint: 'Введите номер'),
            DsField(label: 'Ошибка ввода', hint: 'Проверьте реквизиты'),
          ],
        ),
      ),
      const DsSection(
        title: 'Состояния',
        child: DsColumn(
          children: [
            DsStatus(title: 'Загружаем данные', kind: DsStatusKind.loading),
            DsStatus(title: 'Пока нет операций', kind: DsStatusKind.empty),
            DsStatus(
              title: 'Нет связи',
              message: 'Повторите запрос',
              kind: DsStatusKind.error,
            ),
            DsStatus(title: 'Платёж выполнен', kind: DsStatusKind.success),
          ],
        ),
      ),
      DsSection(
        title: 'Рабочие сценарии',
        child: DsColumn(
          children: [
            for (final route in const [
              ('/history', 'История и мотивированная анимация'),
              ('/account/main', 'Счёт и управление картами'),
              ('/discover/shopping', 'Витрина и корзина'),
              ('/analytics', 'Инфографика и детализация'),
              ('/pay/utilities', 'Коммунальные услуги'),
              ('/pay/mobile', 'Связь'),
              ('/pay/fines', 'Штрафы'),
              ('/pay/cinema', 'Кино'),
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
        title: 'Карточки нового интерфейса',
        child: DsColumn(
          children: [
            DsOverviewCard(
              title: 'Расходы октября',
              value: '86 320,45 ₽',
              detail: 'Учебный пример',
              footer: const DsSpendingStrip(
                points: [
                  DsChartPoint(id: 'a', label: 'Покупки', value: 6),
                  DsChartPoint(id: 'b', label: 'Кафе', value: 3),
                  DsChartPoint(id: 'c', label: 'Транспорт', value: 1),
                ],
              ),
              onTap: () => context.push('/history'),
            ),
            DsAccountProduct(
              title: 'Демо-карта',
              balance: '56 320,40 ₽',
              cards: const [DsBankCardData('demo-card', '0000')],
              onTap: () => context.push('/account/main'),
            ),
            DsShortcutBar(
              actions: [
                DsShortcut(
                  'Пополнить',
                  DsIcons.add,
                  () => context.push('/account/main/topup'),
                ),
                DsShortcut(
                  'Перевести',
                  DsIcons.transfer,
                  () => context.push('/account/main/pay'),
                ),
              ],
            ),
            const DsLimitRow(
              title: 'Учебный лимит',
              detail: 'Доступно 75 000 ₽',
              fraction: .75,
            ),
            DsOfferBanner(
              title: 'Подарки за покупки',
              detail: 'Пример баннера',
              art: DsArt.gift,
              onTap: () => context.push('/discover/gift'),
            ),
          ],
        ),
      ),
      const DsCard(
        tone: DsCardTone.subtle,
        child: DsText(
          'Компоненты используют семантические токены. Размеры, отступы, цвета и движение задаются внутри дизайн-системы; экраны описывают структуру и данные.',
        ),
      ),
    ],
  );
}
