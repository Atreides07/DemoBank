part of '../bank_experience.dart';

class _HomePage extends StatefulWidget {
  const _HomePage({
    required this.accounts,
    required this.history,
    required this.overview,
    required this.environment,
    required this.onAccount,
    required this.onHistory,
    required this.onAnalytics,
    required this.onServices,
    required this.onEntry,
    required this.onTransfer,
    required this.onTopUp,
    required this.onQr,
    required this.onProfile,
    required this.onSearch,
    required this.onRewards,
    required this.onDiscover,
  });
  final AccountsCubit accounts;
  final HistoryCubit history;
  final AnalyticsCubit overview;
  final AppEnvironment environment;
  final ValueChanged<Account> onAccount;
  final VoidCallback onHistory,
      onAnalytics,
      onServices,
      onTransfer,
      onTopUp,
      onQr,
      onProfile,
      onSearch,
      onRewards;
  final ValueChanged<LedgerEntry> onEntry;
  final ValueChanged<String> onDiscover;
  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  final _scroll = ScrollController();
  final _dismissed = <String>{};
  late bool _motionComparison;
  @override
  void initState() {
    super.initState();
    _motionComparison = widget.environment.motionComparison;
    widget.environment.addListener(_onEnvironment);
    _scroll.addListener(_onScroll);
  }

  void _onEnvironment() {
    if (_motionComparison != widget.environment.motionComparison) {
      setState(() => _motionComparison = widget.environment.motionComparison);
    }
  }

  void _onScroll() {
    widget.history.userIsReading =
        _scroll.offset > _scroll.position.viewportDimension;
    if (_scroll.position.extentAfter < _scroll.position.viewportDimension) {
      unawaited(widget.history.loadNext());
    }
  }

  Future<void> _refresh() async => Future.wait([
    widget.accounts.load(),
    widget.overview.load(),
    widget.history.load(background: true),
  ]);
  @override
  void dispose() {
    widget.environment.removeListener(_onEnvironment);
    _scroll.dispose();
    super.dispose();
  }

  Widget _offer(String id) {
    final item = _discoveryById(id);
    return DsOfferBanner(
      title: item.title,
      detail: item.description,
      art: item.art,
      onTap: () => widget.onDiscover(id),
      onDismiss: () => setState(() => _dismissed.add(id)),
    );
  }

  Widget _imageOffer(String id, {bool rail = false}) {
    final item = _discoveryById(id);
    return DsImageOffer(
      title: item.title,
      detail: item.description,
      art: item.art,
      style: rail ? DsImageOfferStyle.rail : DsImageOfferStyle.hero,
      button: 'Посмотреть',
      onTap: () => widget.onDiscover(id),
    );
  }

  Widget _product(_Discovery item) => DsProductTile(
    title: item.title,
    price: item.price!.format(),
    oldPrice: item.oldPrice?.format(),
    reward: '+${item.price!.minor ~/ 1000} бонусов',
    art: item.art,
    onTap: () => widget.onDiscover(item.id),
  );
  @override
  Widget build(BuildContext context) {
    final surface = DsSliverPage(
      scrollKey: const PageStorageKey('home'),
      controller: _scroll,
      white: true,
      onRefresh: _refresh,
      slivers: [
        DsHomeHeader(
          name: 'Алексей',
          onProfile: widget.onProfile,
          onSearch: widget.onSearch,
          onRewards: widget.onRewards,
        ),
        DsSliverSections(
          children: [
            DsRail(
              id: 'home-stories',
              style: DsRailStyle.stories,
              children: [
                for (final id in ['daily-cashback', 'gift', 'books', 'travel'])
                  DsStory(
                    title: _discoveryById(id).title,
                    art: _discoveryById(id).art,
                    onTap: () => widget.onDiscover(id),
                  ),
              ],
            ),
            BlocBuilder<AnalyticsCubit, AnalyticsState>(
              bloc: widget.overview,
              builder: (context, state) => DsActionGrid(
                children: [
                  DsOverviewCard(
                    key: const ValueKey('home-operations'),
                    title: 'Операции',
                    value: state.summary?.total.format() ?? 'Загружаем…',
                    detail: state.error != null
                        ? 'Повторите в истории'
                        : 'Потрачено в октябре',
                    footer: state.summary == null
                        ? null
                        : DsSpendingStrip(
                            points: spendingChartPoints(state.summary!),
                          ),
                    onTap: widget.onHistory,
                  ),
                  DsOverviewCard(
                    title: 'Кэшбэк и бонусы',
                    value: 'До 30%',
                    footer: const DsBadge('2 предложения'),
                    onTap: widget.onRewards,
                  ),
                ],
              ),
            ),
            DsShortcutBar(
              actions: [
                DsShortcut('Перевести', DsIcons.transfer, widget.onTransfer),
                DsShortcut('Пополнить', DsIcons.add, widget.onTopUp),
                DsShortcut('Сканировать', DsIcons.qr, widget.onQr),
              ],
            ),
            BlocBuilder<AccountsCubit, AccountsState>(
              bloc: widget.accounts,
              builder: (context, state) => DsColumn(
                gap: DsSpace.section,
                children: [
                  if (state.error != null)
                    DsStatus(
                      title: state.error!,
                      kind: DsStatusKind.error,
                      action: DsButton(
                        label: 'Повторить',
                        onPressed: widget.accounts.load,
                      ),
                    ),
                  if (state.accounts.isEmpty)
                    const DsStatus(
                      title: 'Загружаем счета',
                      kind: DsStatusKind.loading,
                    ),
                  for (final a in state.accounts.where((a) => a.id == 'main'))
                    DsAccountProduct(
                      key: ValueKey('home-account-${a.id}'),
                      title: a.name,
                      balance: a.balance.format(),
                      cashback: '124,80 ₽',
                      cards: [
                        DsBankCardData('${a.id}-card-0', a.lastDigits),
                        const DsBankCardData('main-card-1', '9364'),
                      ],
                      onTap: () => widget.onAccount(a),
                    ),
                ],
              ),
            ),
            if (!_dismissed.contains('education')) _offer('education'),
            BlocBuilder<AccountsCubit, AccountsState>(
              bloc: widget.accounts,
              builder: (context, state) => DsColumn(
                gap: DsSpace.section,
                children: [
                  for (final a in state.accounts.where((a) => a.id != 'main'))
                    DsAccountProduct(
                      key: ValueKey('home-account-${a.id}'),
                      title: a.name,
                      balance: a.balance.format(),
                      cards: [DsBankCardData('${a.id}-card-0', a.lastDigits)],
                      icon: switch (a.balance.currency) {
                        'USD' => DsIcons.currencyUsd,
                        'GBP' => DsIcons.currencyGbp,
                        _ => DsIcons.ruble,
                      },
                      onTap: () => widget.onAccount(a),
                    ),
                ],
              ),
            ),
            DsAccountProduct(
              title: 'Собираем на подарок',
              balance: '1 750 ₽ из 5 000 ₽',
              icon: DsIcons.gift,
              onTap: () => widget.onDiscover('goal'),
            ),
            DsAccountProduct(
              title: 'Инвестиции',
              balance: '28 640,52 ₽',
              cashback: '+12,4% за год',
              icon: DsIcons.investments,
              onTap: () => widget.onDiscover('investments'),
            ),
            DsAccountProduct(
              title: 'На любые цели',
              balance: 'До 700 000 ₽',
              icon: DsIcons.add,
              onTap: () => widget.onDiscover('borrow'),
            ),
            if (!_dismissed.contains('insurance')) _offer('insurance'),
            DsActionGrid(
              children: [
                for (final id in ['borrow', 'saving', 'investments', 'card'])
                  DsArtTile(
                    title: _discoveryById(id).title,
                    art: _discoveryById(id).art,
                    onTap: () => widget.onDiscover(id),
                  ),
              ],
            ),
            const DsShowcaseHeading('Дом', center: true),
            _imageOffer('home'),
            const DsShowcaseHeading('Путешествия', center: true),
            _imageOffer('travel'),
            DsRail(
              id: 'home-offers',
              style: DsRailStyle.offers,
              children: [
                for (final id in ['coast', 'hotel'])
                  _imageOffer(id, rail: true),
              ],
            ),
            DsButton(
              label: 'В путешествие',
              onPressed: () => widget.onDiscover('travel'),
            ),
            const DsShowcaseHeading('Покупки', center: true),
            _imageOffer('shopping'),
            DsShowcaseHeading(
              'Категории',
              action: DsButton(
                label: 'Все',
                variant: DsButtonVariant.quiet,
                onPressed: () => widget.onDiscover('shopping'),
              ),
            ),
            DsRail(
              id: 'home-categories',
              style: DsRailStyle.categories,
              children: [
                for (final id in [
                  'electronics',
                  'cosmetics',
                  'clothes',
                  'appliances',
                ])
                  DsCategoryTile(
                    title: _discoveryById(id).title,
                    art: _discoveryById(id).art,
                    onTap: () => widget.onDiscover(id),
                  ),
              ],
            ),
            const DsShowcaseHeading('Популярное'),
            DsActionGrid(
              children: [for (final item in _products.take(2)) _product(item)],
            ),
            DsPanel(
              child: DsColumn(
                children: [
                  const DsText('Предложение недели', style: DsTextStyle.title),
                  DsRail(
                    id: 'home-products',
                    style: DsRailStyle.products,
                    children: [
                      for (final item in _products.skip(2)) _product(item),
                    ],
                  ),
                  DsButton(
                    label: 'Посмотреть все',
                    variant: DsButtonVariant.secondary,
                    onPressed: () => widget.onDiscover('shopping'),
                  ),
                ],
              ),
            ),
            DsActionGrid(
              children: [for (final item in _products.skip(2)) _product(item)],
            ),
            DsButton(
              label: 'За покупками',
              onPressed: () => widget.onDiscover('shopping'),
            ),
          ],
        ),
        HistorySliver(
          density: DsDensity.compact,
          cubit: widget.history,
          controller: _scroll,
          onEntry: widget.onEntry,
          showUpdateAction: false,
          animate: !_motionComparison,
        ),
      ],
    );
    return BlocSelector<HistoryCubit, HistoryState, bool>(
      bloc: widget.history,
      selector: (s) => s.pendingUpdate != null,
      builder: (context, pending) => DsReadingSurface(
        notice: pending
            ? DsNotice(
                message: 'История обновилась. Место чтения сохранено.',
                action: DsButton(
                  label: 'Показать обновления',
                  onPressed: widget.history.applyUpdate,
                ),
              )
            : null,
        child: surface,
      ),
    );
  }
}
