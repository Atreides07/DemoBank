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
      title: item.title(context.l10n),
      detail: item.description(context.l10n, context.formats),
      art: item.art,
      onTap: () => widget.onDiscover(id),
      onDismiss: () => setState(() => _dismissed.add(id)),
    );
  }

  Widget _imageOffer(String id, {bool rail = false}) {
    final item = _discoveryById(id);
    return DsImageOffer(
      title: item.title(context.l10n),
      detail: item.description(context.l10n, context.formats),
      art: item.art,
      style: rail ? DsImageOfferStyle.rail : DsImageOfferStyle.hero,
      button: context.l10n.homeView,
      onTap: () => widget.onDiscover(id),
    );
  }

  Widget _product(_Discovery item) => DsProductTile(
    title: item.title(context.l10n),
    price: context.formats.money(item.price!),
    oldPrice: item.oldPrice == null
        ? null
        : context.formats.money(item.oldPrice!),
    reward: '+${context.l10n.bonusPoints(item.price!.minor ~/ 1000)}',
    art: item.art,
    onTap: () => widget.onDiscover(item.id),
  );
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final formats = context.formats;
    final surface = DsSliverPage(
      scrollKey: const PageStorageKey('home'),
      controller: _scroll,
      white: Theme.of(context).brightness == Brightness.light,
      onRefresh: _refresh,
      slivers: [
        DsHomeHeader(
          name: l10n.commonCustomerName,
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
                    title: _discoveryById(id).title(l10n),
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
                    title: l10n.accountOperations,
                    value: state.summary == null
                        ? l10n.commonLoadingEllipsis
                        : formats.money(state.summary!.total),
                    detail: state.failed
                        ? l10n.homeRetryInHistory
                        : l10n.spentInMonth(
                            AppFormats.monthKey(
                              formats
                                  .reporting(
                                    state.filter.from ??
                                        widget.environment.now(),
                                  )
                                  .month,
                            ),
                          ),
                    footer: state.summary == null
                        ? null
                        : DsSpendingStrip(
                            points: spendingChartPoints(
                              context,
                              state.summary!,
                            ),
                          ),
                    onTap: widget.onHistory,
                  ),
                  DsOverviewCard(
                    title: DsLocalizations.of(context).rewards,
                    value: l10n.homeUpTo(
                      formats.percent(30, fractionDigits: 0),
                    ),
                    footer: DsBadge(l10n.homeOffersCount(2)),
                    onTap: widget.onRewards,
                  ),
                ],
              ),
            ),
            DsShortcutBar(
              actions: [
                DsShortcut(
                  l10n.catalogTransfer,
                  DsIcons.transfer,
                  widget.onTransfer,
                ),
                DsShortcut(l10n.accountTopUp, DsIcons.add, widget.onTopUp),
                DsShortcut(l10n.homeScan, DsIcons.qr, widget.onQr),
              ],
            ),
            BlocBuilder<AccountsCubit, AccountsState>(
              bloc: widget.accounts,
              builder: (context, state) => DsColumn(
                gap: DsSpace.section,
                children: [
                  if (state.failed)
                    DsStatus(
                      title: l10n.homeAccountsFailed,
                      kind: DsStatusKind.error,
                      action: DsButton(
                        label: l10n.commonRetry,
                        onPressed: widget.accounts.load,
                      ),
                    ),
                  if (state.accounts.isEmpty && !state.failed)
                    DsStatus(
                      title: l10n.homeAccountsLoading,
                      kind: DsStatusKind.loading,
                    ),
                  for (final a in state.accounts.where((a) => a.id == 'main'))
                    DsAccountProduct(
                      key: ValueKey('home-account-${a.id}'),
                      title: a.name,
                      balance: formats.money(a.balance),
                      cashback: formats.money(const Money(12480)),
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
                      balance: formats.money(a.balance),
                      cards: [DsBankCardData('${a.id}-card-0', a.lastDigits)],
                      icon: switch (a.balance.currency) {
                        'USD' => DsIcons.currencyUsd,
                        'GBP' => DsIcons.currencyGbp,
                        'RUB' => DsIcons.ruble,
                        _ => DsIcons.wallet,
                      },
                      onTap: () => widget.onAccount(a),
                    ),
                ],
              ),
            ),
            DsAccountProduct(
              title: l10n.homeGiftGoal,
              balance: l10n.homeGoalProgress(
                formats.money(const Money(175000)),
                formats.money(const Money(500000)),
              ),
              icon: DsIcons.gift,
              onTap: () => widget.onDiscover('goal'),
            ),
            DsAccountProduct(
              title: l10n.discoveryTitle('investments'),
              balance: formats.money(const Money(2864052)),
              cashback: l10n.homeYearChange(
                formats.percent(12.4, signed: true),
              ),
              icon: DsIcons.investments,
              onTap: () => widget.onDiscover('investments'),
            ),
            DsAccountProduct(
              title: l10n.homeAnyGoal,
              balance: l10n.homeUpTo(formats.money(const Money(70000000))),
              icon: DsIcons.add,
              onTap: () => widget.onDiscover('borrow'),
            ),
            if (!_dismissed.contains('insurance')) _offer('insurance'),
            DsActionGrid(
              children: [
                for (final id in ['borrow', 'saving', 'investments', 'card'])
                  DsArtTile(
                    title: _discoveryById(id).title(l10n),
                    art: _discoveryById(id).art,
                    onTap: () => widget.onDiscover(id),
                  ),
              ],
            ),
            DsShowcaseHeading(l10n.homeHome, center: true),
            _imageOffer('home'),
            DsShowcaseHeading(l10n.homeTravel, center: true),
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
              label: l10n.homeGoTravel,
              onPressed: () => widget.onDiscover('travel'),
            ),
            DsShowcaseHeading(l10n.categoryName('shopping'), center: true),
            _imageOffer('shopping'),
            DsShowcaseHeading(
              l10n.homeCategories,
              action: DsButton(
                label: l10n.commonAll,
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
                    title: _discoveryById(id).title(l10n),
                    art: _discoveryById(id).art,
                    onTap: () => widget.onDiscover(id),
                  ),
              ],
            ),
            DsShowcaseHeading(l10n.homePopular),
            DsActionGrid(
              children: [for (final item in _products.take(2)) _product(item)],
            ),
            DsPanel(
              child: DsColumn(
                children: [
                  DsText(l10n.homeWeekOffer, style: DsTextStyle.title),
                  DsRail(
                    id: 'home-products',
                    style: DsRailStyle.products,
                    children: [
                      for (final item in _products.skip(2)) _product(item),
                    ],
                  ),
                  DsButton(
                    label: l10n.homeViewAll,
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
              label: l10n.homeGoShopping,
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
                message: l10n.homeHistoryUpdated,
                action: DsButton(
                  label: DsLocalizations.of(context).showUpdates,
                  onPressed: widget.history.applyUpdate,
                ),
              )
            : null,
        child: surface,
      ),
    );
  }
}
