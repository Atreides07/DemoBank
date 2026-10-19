part of '../bank_experience.dart';

class _AccountWorkspace extends StatefulWidget {
  const _AccountWorkspace({
    required this.accountId,
    required this.environment,
    required this.accounts,
    required this.analytics,
    required this.onChanged,
  });
  final String accountId;
  final AppEnvironment environment;
  final AccountsCubit accounts;
  final AnalyticsReader analytics;
  final VoidCallback onChanged;
  @override
  State<_AccountWorkspace> createState() => _AccountWorkspaceState();
}

class _AccountWorkspaceState extends State<_AccountWorkspace> {
  late final AccountManagementCubit _profile;
  late final AnalyticsCubit _overview;
  final _scroll = ScrollController();
  bool _coupon = true;
  late int _languageRevision;
  @override
  void initState() {
    super.initState();
    _languageRevision = widget.environment.languageRevision;
    widget.environment.addListener(_onEnvironment);
    _profile = AccountManagementCubit(
      ApiAccountManagement(widget.environment.api, widget.environment.cache),
      widget.accountId,
    );
    final currency =
        widget.accounts.state.accounts
            .where((a) => a.id == widget.accountId)
            .firstOrNull
            ?.balance
            .currency ??
        'RUB';
    _overview = AnalyticsCubit(
      widget.analytics,
      filter: ReportingPeriod.month(widget.environment.now())
          .copyWith(accounts: [widget.accountId], currency: currency),
    );
    unawaited(_profile.load());
    unawaited(_overview.load());
  }

  /// Account names, limits and categories come from the server in the
  /// interface language.
  void _onEnvironment() {
    if (_languageRevision == widget.environment.languageRevision) return;
    _languageRevision = widget.environment.languageRevision;
    unawaited(_profile.load());
    unawaited(_overview.load());
  }

  Future<void> _refresh() async {
    await Future.wait([
      _profile.load(),
      _overview.load(),
      widget.accounts.load(),
    ]);
  }

  Future<void> _open(AccountAction action) async {
    if (action == AccountAction.activity) {
      final currency =
          widget.accounts.state.accounts
              .where((a) => a.id == widget.accountId)
              .firstOrNull
              ?.balance
              .currency ??
          'RUB';
      await context.push(
        '/history',
        extra: LedgerFilter(accounts: [widget.accountId], currency: currency),
      );
    } else {
      await context.push(
        '/account/${widget.accountId}/${action == AccountAction.topUp ? 'topup' : action.name}',
      );
    }
    if (mounted) await _refresh();
  }

  Future<void> _card(String id) async {
    await context.push(
      '/account/${widget.accountId}/freezeCard?card=${Uri.encodeComponent(id)}',
    );
    if (mounted) unawaited(_profile.load());
  }

  @override
  void dispose() {
    widget.environment.removeListener(_onEnvironment);
    _scroll.dispose();
    unawaited(_profile.close());
    unawaited(_overview.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: BlocBuilder<AccountsCubit, AccountsState>(
      bloc: widget.accounts,
      builder: (context, accounts) {
        final account = accounts.accounts
            .where((a) => a.id == widget.accountId)
            .firstOrNull;
        if (account == null) {
          return _AccountUnavailable(
            accounts: accounts,
            onRetry: widget.accounts.load,
          );
        }
        return BlocBuilder<AccountManagementCubit, AccountManagementState>(
          bloc: _profile,
          builder: (context, state) =>
              BlocBuilder<AnalyticsCubit, AnalyticsState>(
                bloc: _overview,
                builder: (context, overview) => AccountDashboard(
                  account: account,
                  profile: state.profile,
                  scrollController: _scroll,
                  onBack: () => context.pop(),
                  onAction: (a) => unawaited(_open(a)),
                  onCard: (id) => unawaited(_card(id)),
                  onRefresh: _refresh,
                  summary: overview.summary,
                  spendingMonth: overview.filter.from,
                  spendingPoints: overview.summary == null
                      ? const []
                      : spendingChartPoints(context, overview.summary!),
                  error: switch (state.problem) {
                    AccountManagementProblem.loadFailed =>
                      context.l10n.loadFailure(
                        state.failure,
                        context.l10n.accountLoadFailed,
                      ),
                    AccountManagementProblem.saveFailed =>
                      context.l10n.loadFailure(
                        state.failure,
                        context.l10n.accountSaveFailed,
                      ),
                    null =>
                      overview.failed ? context.l10n.analyticsFailed : null,
                  },
                  loading: state.loading,
                  couponVisible: _coupon,
                  onDismissCoupon: () => setState(() => _coupon = false),
                ),
              ),
        );
      },
    ),
  );
}

/// An account route whose account is not in the list: still loading, the
/// list could not be loaded (offline with nothing saved), or it is gone.
class _AccountUnavailable extends StatelessWidget {
  const _AccountUnavailable({required this.accounts, required this.onRetry});
  final AccountsState accounts;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DsPage(
      title: l10n.detailsAccount,
      onBack: () => context.canPop() ? context.pop() : context.go('/'),
      children: [
        if (accounts.loading)
          DsStatus(title: l10n.accountLoading, kind: DsStatusKind.loading)
        else if (accounts.failed)
          DsStatus(
            title: l10n.accountListUnavailable,
            message: l10n.loadFailure(accounts.failure, l10n.accountLoadFailed),
            kind: DsStatusKind.error,
            action: DsButton(label: l10n.commonRetry, onPressed: onRetry),
          )
        else
          DsStatus(title: l10n.accountNotFound, kind: DsStatusKind.error),
      ],
    );
  }
}

class _AccountActionPage extends StatefulWidget {
  const _AccountActionPage({
    required this.accountId,
    required this.dataRevision,
    required this.action,
    required this.environment,
    required this.accounts,
    required this.onChanged,
    required this.operationJournal,
    this.cardId,
  });
  final ValueNotifier<int> dataRevision;
  final String accountId, action;
  final String? cardId;
  final AccountOperationJournal operationJournal;
  final AppEnvironment environment;
  final AccountsCubit accounts;
  final VoidCallback onChanged;
  @override
  State<_AccountActionPage> createState() => _AccountActionPageState();
}

class _AccountActionPageState extends State<_AccountActionPage> {
  late final AccountManagementCubit _profile;
  late final ApiAccountManagement _management;
  final _name = TextEditingController();
  final _cardHistory =
      <String, ({Future<LedgerPage> page, DateTime expiresAt})>{};

  void _invalidateCardHistory() => setState(_cardHistory.clear);

  Future<LedgerPage> _loadCardHistory(
    Account account,
    AccountCard card, {
    bool refresh = false,
  }) {
    final key = '${account.balance.currency}:${card.id}';
    final cached = _cardHistory[key];
    if (!refresh &&
        cached != null &&
        DateTime.now().isBefore(cached.expiresAt)) {
      return cached.page;
    }
    late final Future<LedgerPage> page;
    page =
        ApiHistoryRepository(widget.environment.api, widget.environment.cache)
            .page(
              LedgerFilter(
                accounts: [account.id],
                cardId: card.id,
                currency: account.balance.currency,
              ),
              limit: 5,
            )
            .then(
              (value) => value,
              onError: (Object error, StackTrace stack) {
                if (identical(_cardHistory[key]?.page, page)) {
                  _cardHistory.remove(key);
                }
                Error.throwWithStackTrace(error, stack);
              },
            );
    _cardHistory[key] = (
      page: page,
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );
    return page;
  }

  bool _saved = false;
  bool _certificate = false;
  bool _copied = false;
  @override
  void initState() {
    super.initState();
    widget.dataRevision.addListener(_invalidateCardHistory);
    _management = ApiAccountManagement(
      widget.environment.api,
      widget.environment.cache,
    );
    _profile = AccountManagementCubit(_management, widget.accountId);
    unawaited(_profile.load());
  }

  @override
  void dispose() {
    widget.dataRevision.removeListener(_invalidateCardHistory);
    _cardHistory.clear();
    _name.dispose();
    unawaited(_profile.close());
    super.dispose();
  }

  Future<bool> _save(AccountPreferences value) async {
    setState(() => _saved = false);
    if (widget.action == 'freezeCard') {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
    final saved = await _profile.update(value);
    if (!mounted) return false;
    if (saved) {
      widget.onChanged();
      setState(() => _saved = true);
      if (widget.action == 'freezeCard') {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.accountSaved)));
      }
    }
    return saved;
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) setState(() => _copied = true);
  }

  /// Route segments are identifiers, so they double as catalogue select cases.
  String _title(AppLocalizations l10n, String action) =>
      l10n.accountActionTitle(action);
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<AccountsCubit, AccountsState>(
    bloc: widget.accounts,
    builder: (context, accounts) {
      final account = accounts.accounts
          .where((a) => a.id == widget.accountId)
          .firstOrNull;
      final l10n = context.l10n;
      final formats = context.formats;
      if (account == null) {
        return _AccountUnavailable(
          accounts: accounts,
          onRetry: widget.accounts.load,
        );
      }
      if (widget.action == 'topup' ||
          widget.action == 'transfer' ||
          widget.action == 'phone') {
        return _AccountOperationPage(
          account: account,
          accounts: accounts.accounts,
          kind: widget.action == 'topup'
              ? AccountOperationKind.topUp
              : widget.action == 'phone'
              ? AccountOperationKind.phoneTransfer
              : AccountOperationKind.transfer,
          journal: widget.operationJournal,
          environment: widget.environment,
          onChanged: widget.onChanged,
        );
      }
      return BlocBuilder<AccountManagementCubit, AccountManagementState>(
        bloc: _profile,
        builder: (context, state) {
          final p = state.profile;
          final action = widget.action;
          final link = Uri(
            scheme: 'demobank',
            host: 'topup',
            pathSegments: [account.id],
            queryParameters: {'name': p?.name ?? account.name},
          ).toString();
          final card =
              p?.cards.where((c) => c.id == widget.cardId).firstOrNull ??
              p?.cards.firstOrNull;
          final children = <Widget>[
            if (action != 'freezeCard')
              DsText(p?.name ?? account.name, style: DsTextStyle.title),
            if (state.problem case final problem?)
              DsStatus(
                title: switch (problem) {
                  AccountManagementProblem.loadFailed => l10n.loadFailure(
                    state.failure,
                    l10n.accountLoadFailed,
                  ),
                  AccountManagementProblem.saveFailed => l10n.loadFailure(
                    state.failure,
                    l10n.accountSaveFailed,
                  ),
                },
                kind: DsStatusKind.error,
                action: DsButton(
                  label: l10n.commonRefresh,
                  onPressed: _profile.load,
                ),
              ),
            if (state.saving)
              DsStatus(title: l10n.accountSaving, kind: DsStatusKind.loading),
            if (_saved && action != 'freezeCard')
              DsStatus(title: l10n.accountSaved, kind: DsStatusKind.success),
            if (p == null && state.problem == null && action != 'pay')
              DsStatus(
                title: l10n.accountLoadingSettings,
                kind: DsStatusKind.loading,
              ),
          ];
          if (action == 'pay') {
            children.addAll([
              DsPanel(
                child: DsColumn(
                  children: [
                    DsText(
                      l10n.commonAvailableAmount(
                        formats.money(account.available),
                      ),
                      style: DsTextStyle.headline,
                    ),
                    DsButton(
                      label: l10n.accountBetweenOwn,
                      icon: DsIcons.transfer,
                      onPressed: () =>
                          context.push('/account/${account.id}/transfer'),
                    ),
                  ],
                ),
              ),
              if (account.balance.currency == 'RUB')
                DsButton(
                  label: l10n.accountByPhone,
                  icon: DsIcons.mobile,
                  onPressed: () => context.push('/account/${account.id}/phone'),
                ),
              if (account.balance.currency == 'RUB')
                DsButton(
                  label: l10n.accountPayService,
                  icon: DsIcons.services,
                  onPressed: () =>
                      context.push('/account-services/${account.id}'),
                ),
              DsButton(
                label: l10n.accountTopUpAccount,
                icon: DsIcons.add,
                variant: DsButtonVariant.secondary,
                onPressed: () => context.push('/account/${account.id}/topup'),
              ),
            ]);
          } else if (p != null) {
            switch (action) {
              case 'rename':
                children.addAll([
                  DsField(
                    label: l10n.accountNewName,
                    hint: p.name,
                    controller: _name,
                  ),
                  DsText(
                    l10n.accountNameLength(
                      formats.number(1),
                      formats.number(32),
                    ),
                    style: DsTextStyle.caption,
                    tone: DsTone.muted,
                  ),
                  DsButton(
                    label: l10n.accountSaveName,
                    onPressed: state.saving
                        ? null
                        : () => _save(AccountPreferences(name: _name.text)),
                  ),
                ]);
              case 'autoTopUp':
                children.addAll([
                  DsText(
                    l10n.accountAutoTopUpRule(
                      formats.money(
                        Money(100000, currency: account.balance.currency),
                      ),
                      formats.money(
                        Money(50000, currency: account.balance.currency),
                      ),
                    ),
                  ),
                  DsSwitchRow(
                    title: l10n.accountAutoTopUp,
                    value: p.autoTopUp,
                    onChanged: state.saving
                        ? null
                        : (v) => _save(AccountPreferences(autoTopUp: v)),
                  ),
                ]);
              case 'roundUp':
                children.addAll([
                  DsText(
                    l10n.accountRoundUpRule(
                      formats.money(
                        Money(10000, currency: account.balance.currency),
                      ),
                    ),
                  ),
                  DsSwitchRow(
                    title: l10n.accountRoundUpSwitch,
                    value: p.roundUp,
                    onChanged: state.saving
                        ? null
                        : (v) => _save(AccountPreferences(roundUp: v)),
                  ),
                ]);
              case 'cashback':
                children.addAll([
                  DsText(l10n.accountChooseCashbackAccount),
                  for (final a in accounts.accounts.where(
                    (a) => a.balance.currency == account.balance.currency,
                  ))
                    DsChoice(
                      label: a.name,
                      selected: p.cashbackDestination == a.id && !p.charity,
                      onSelected: state.saving
                          ? null
                          : (_) => _save(
                              AccountPreferences(
                                cashbackDestination: a.id,
                                charity: false,
                              ),
                            ),
                    ),
                  DsSwitchRow(
                    title: l10n.accountCharity,
                    subtitle: l10n.accountCharityHint,
                    value: p.charity,
                    onChanged: state.saving
                        ? null
                        : (v) => _save(AccountPreferences(charity: v)),
                  ),
                ]);
              case 'addCard':
                children.addAll([
                  const DsFeatureArtwork(DsArt.cardPromo),
                  DsText(l10n.accountExtraCardHint),
                  if (p.cards.any((c) => c.lastDigits == '6057'))
                    DsStatus(
                      title: l10n.accountCardAdded('6057'),
                      kind: DsStatusKind.success,
                    )
                  else
                    DsButton(
                      label: l10n.accountIssueCard,
                      onPressed: state.saving
                          ? null
                          : () => _save(
                              const AccountPreferences(extraCard: true),
                            ),
                    ),
                ]);
              case 'freezeCard':
                children.addAll([
                  DsBankCardCarousel(
                    cards: [
                      for (final c in p.cards)
                        DsBankCardData(c.id, c.lastDigits, frozen: c.frozen),
                    ],
                    selectedId: card?.id ?? '',
                    onCard: state.saving
                        ? null
                        : (id) {
                            setState(() => _saved = false);
                            context.replace(
                              '/account/${account.id}/freezeCard?card=${Uri.encodeComponent(id)}',
                            );
                          },
                  ),
                  if (card != null)
                    _CardWorkspace(
                      key: ValueKey((card.id, widget.dataRevision.value)),
                      account: account,
                      card: card,
                      saving: state.saving,
                      loadHistory: ({bool refresh = false}) =>
                          _loadCardHistory(account, card, refresh: refresh),
                      onSave: _save,
                      loadRequisites: () =>
                          _management.cardRequisites(account.id, card.id),
                    ),
                ]);
              case 'limits':
                children.addAll([
                  for (final l in p.limits)
                    DsPanel(
                      child: DsColumn(
                        children: [
                          DsLimitRow(
                            title: l.title,
                            detail: l10n.commonAvailableAmount(
                              formats.money(l.remaining),
                            ),
                            fraction: l.remaining.minor / l.limit.minor,
                          ),
                          DsKeyValue(
                            label: l10n.accountMonthlyLimit,
                            value: formats.money(l.limit),
                          ),
                        ],
                      ),
                    ),
                ]);
              case 'requisites':
              case 'salary':
              case 'pension':
              case 'social':
                children.addAll([
                  DsText(l10n.accountRequisitesHint, tone: DsTone.muted),
                  for (final r in p.requisites.entries)
                    DsKeyValue(label: r.key, value: r.value),
                  DsButton(
                    label: _copied
                        ? l10n.accountCopied
                        : l10n.accountCopyRequisites,
                    icon: DsIcons.copy,
                    onPressed: () => _copy(
                      p.requisites.entries
                          .map((e) => '${e.key}: ${e.value}')
                          .join('\n'),
                    ),
                  ),
                ]);
              case 'qr':
              case 'link':
                children.addAll([
                  DsQrCode(data: link),
                  DsText(l10n.accountLinkHint, tone: DsTone.muted),
                  DsKeyValue(label: l10n.accountLinkLabel, value: link),
                  DsButton(
                    label: _copied
                        ? l10n.accountLinkCopied
                        : l10n.accountCopyLink,
                    icon: DsIcons.copy,
                    onPressed: () => _copy(link),
                  ),
                ]);
              case 'linkedServices':
                children.addAll([
                  DsText(l10n.accountLinkedServicesHint),
                  if (p.linkedServicesEnabled) ...[
                    for (final service in const [
                      'market',
                      'music',
                      'homeCinema',
                      'parking',
                      'coffee',
                      'delivery',
                    ])
                      DsListTile(
                        title: l10n.accountLinkedService(service),
                        subtitle: l10n.accountCard(account.lastDigits),
                      ),
                  ],
                  DsSwitchRow(
                    title: l10n.accountAllowLinkedServices,
                    value: p.linkedServicesEnabled,
                    onChanged: state.saving
                        ? null
                        : (v) => _save(
                            AccountPreferences(linkedServicesEnabled: v),
                          ),
                  ),
                ]);
              case 'plan':
                children.add(
                  DsPanel(
                    child: DsColumn(
                      children: [
                        DsText(
                          l10n.accountPlanName,
                          style: DsTextStyle.headline,
                        ),
                        DsKeyValue(
                          label: l10n.accountPlanService,
                          value: l10n.accountPlanFree,
                        ),
                        DsKeyValue(
                          label: l10n.accountCashback,
                          value: l10n.accountPlanCashback(
                            formats.percent(30, fractionDigits: 0),
                          ),
                        ),
                        DsKeyValue(
                          label: l10n.accountPlanTransfers,
                          value: l10n.accountPlanNoFee,
                        ),
                      ],
                    ),
                  ),
                );
              case 'statement':
                children.addAll([
                  DsText(l10n.accountStatementHint),
                  DsButton(
                    label: l10n.accountOpenStatement,
                    onPressed: () => context.push(
                      '/history',
                      extra: LedgerFilter(
                        accounts: [account.id],
                        currency: account.balance.currency,
                      ),
                    ),
                  ),
                ]);
              case 'certificate':
                final text = l10n.accountCertificateText(
                  l10n.commonCustomerFullName,
                  p.name,
                  formats.money(account.balance),
                  p.contract,
                );
                children.addAll([
                  DsText(l10n.accountCertificateHint),
                  if (_certificate) DsPanel(child: DsText(text)),
                  DsButton(
                    label: _certificate
                        ? (_copied
                              ? l10n.accountCertificateCopied
                              : l10n.accountCopyCertificate)
                        : l10n.accountMakeCertificate,
                    onPressed: () {
                      if (_certificate) {
                        unawaited(_copy(text));
                      } else {
                        setState(() => _certificate = true);
                      }
                    },
                  ),
                ]);
              case 'services':
                children.addAll([
                  DsListTile(
                    title: l10n.accountAutoTopUp,
                    subtitle: p.autoTopUp ? l10n.commonOn : l10n.commonOff,
                    onTap: () =>
                        context.push('/account/${account.id}/autoTopUp'),
                  ),
                  DsListTile(
                    title: l10n.accountRoundUp,
                    subtitle: p.roundUp ? l10n.commonOn : l10n.commonOff,
                    onTap: () => context.push('/account/${account.id}/roundUp'),
                  ),
                  DsListTile(
                    title: l10n.accountLinkedServices,
                    onTap: () =>
                        context.push('/account/${account.id}/linkedServices'),
                  ),
                ]);
              case 'rewards':
                children.addAll([
                  DsMoneyText(formats.money(p.cashback)),
                  DsText(
                    l10n.accountCashbackPending(
                      formats.dayMonthLong(p.cashbackDate),
                    ),
                  ),
                  DsButton(
                    label: l10n.accountChooseCashbackCategories,
                    onPressed: () => context.push('/discover/daily-cashback'),
                  ),
                  DsButton(
                    label: l10n.accountGiftsForBonuses,
                    variant: DsButtonVariant.secondary,
                    onPressed: () => context.push('/discover/gift'),
                  ),
                  DsButton(
                    label: l10n.analyticsForAccount,
                    variant: DsButtonVariant.quiet,
                    onPressed: () =>
                        context.push('/account-analytics/${account.id}'),
                  ),
                ]);
              default:
                children.add(DsText(l10n.accountChooseAction));
            }
          }
          return DsPage(title: _title(l10n, action), children: children);
        },
      );
    },
  );
}

class _AccountOperationPage extends StatefulWidget {
  const _AccountOperationPage({
    required this.account,
    required this.accounts,
    required this.kind,
    required this.journal,
    required this.environment,
    required this.onChanged,
  });
  final Account account;
  final List<Account> accounts;
  final AccountOperationKind kind;
  final AccountOperationJournal journal;
  final AppEnvironment environment;
  final VoidCallback onChanged;
  @override
  State<_AccountOperationPage> createState() => _AccountOperationPageState();
}

class _AccountOperationPageState extends State<_AccountOperationPage> {
  late final AccountOperationCubit _cubit;
  final _amount = TextEditingController();
  String? _destination;
  @override
  void initState() {
    super.initState();
    _cubit = AccountOperationCubit(
      reader: ApiAccountManagement(
        widget.environment.api,
        widget.environment.cache,
      ),
      account: widget.account,
      kind: widget.kind,
      accounts: widget.accounts,
      nextId: widget.environment.checkout.keyFactory.next,
      journal: widget.journal,
    );
    unawaited(_cubit.restore());
  }

  @override
  void dispose() {
    _amount.dispose();
    unawaited(_cubit.close());
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<AccountOperationCubit, AccountOperationState>(
    bloc: _cubit,
    builder: (context, state) {
      final l10n = context.l10n;
      final formats = context.formats;
      final currency = widget.account.balance.currency;
      final topUp =
          (state.operation?.kind ?? widget.kind) == AccountOperationKind.topUp;
      final phone =
          (state.operation?.kind ?? widget.kind) ==
          AccountOperationKind.phoneTransfer;
      final restoring = state.step == AccountOperationStep.restoring;
      final busy = state.step == AccountOperationStep.submitting;
      final success = state.step == AccountOperationStep.succeeded;
      final editing = state.step == AccountOperationStep.editing;
      final destination = widget.accounts
          .where(
            (a) => a.id == (state.operation?.destinationId ?? _destination),
          )
          .firstOrNull;
      return DsPage(
        title: topUp
            ? l10n.accountTopUpAccount
            : phone
            ? l10n.accountByPhone
            : l10n.accountBetweenOwn,
        backEnabled: !busy,
        children: [
          DsPanel(
            child: DsColumn(
              children: [
                DsKeyValue(
                  label: topUp ? l10n.operationTo : l10n.operationFrom,
                  value: widget.account.name,
                ),
                // Holds and pending debits are not spendable.
                DsKeyValue(
                  label: l10n.commonAvailable,
                  value: formats.money(widget.account.available),
                ),
              ],
            ),
          ),
          if (restoring)
            DsStatus(
              title: l10n.operationRestoring,
              kind: state.problem == null
                  ? DsStatusKind.loading
                  : DsStatusKind.error,
              action: state.problem == null
                  ? null
                  : DsButton(
                      label: l10n.operationRetryRestore,
                      onPressed: _cubit.restore,
                    ),
            )
          else if (editing) ...[
            if (topUp) DsText(l10n.operationTopUpSource),
            if (phone) ...[
              DsText(l10n.operationChooseContact),
              if (state.loadingRecipients)
                DsLoading(label: l10n.operationLoadingContacts),
              for (final r in _cubit.recipients)
                DsChoice(
                  label: l10n.operationRecipient(r.name, r.bank, r.phone),
                  selected: _destination == r.id,
                  onSelected: (_) => setState(() => _destination = r.id),
                ),
            ],
            if (!topUp && !phone) ...[
              DsText(l10n.operationToOwn),
              for (final a in widget.accounts.where(
                (a) =>
                    a.id != widget.account.id &&
                    a.balance.currency == widget.account.balance.currency,
              ))
                DsChoice(
                  label: l10n.discoveryPair(a.name, formats.money(a.balance)),
                  selected: _destination == a.id,
                  onSelected: (_) => setState(() => _destination = a.id),
                ),
              if (!widget.accounts.any(
                (a) =>
                    a.id != widget.account.id &&
                    a.balance.currency == widget.account.balance.currency,
              ))
                DsStatus(
                  title: l10n.operationNoSecondAccount,
                  kind: DsStatusKind.empty,
                ),
            ],
            DsField(
              label: l10n.operationAmount(formats.currencySymbol(currency)),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            DsButton(
              label: l10n.commonContinue,
              onPressed: () => _cubit.review(
                formats.parseAmount(_amount.text, maxIntegerDigits: 7),
                _destination,
              ),
            ),
          ] else ...[
            DsMoneyText(formats.money(state.operation!.amount)),
            if (!topUp)
              DsKeyValue(
                label: phone
                    ? l10n.operationRecipientLabel
                    : l10n.operationToAccount,
                value: phone
                    ? _cubit.recipients
                              .where(
                                (r) => r.id == state.operation?.destinationId,
                              )
                              .firstOrNull
                              ?.name ??
                          state.operation?.destinationId ??
                          l10n.operationSampleContact
                    : destination?.name ?? '—',
              ),
            DsKeyValue(
              label: l10n.commonFee,
              value: formats.money(Money(0, currency: currency)),
            ),
            if (success)
              DsStatus(
                title: topUp
                    ? l10n.operationToppedUp
                    : l10n.operationTransferred,
                message: l10n.operationSaved,
                kind: DsStatusKind.success,
              )
            else ...[
              DsButton(
                label: busy
                    ? l10n.operationRunning
                    : state.problem == null
                    ? l10n.operationConfirm
                    : l10n.operationRetry,
                onPressed: busy
                    ? null
                    : () async {
                        final ok = await _cubit.submit();
                        if (ok) widget.onChanged();
                      },
              ),
              if (_cubit.canEdit)
                DsButton(
                  label: l10n.operationChangeAmount,
                  variant: DsButtonVariant.quiet,
                  onPressed: busy ? null : _cubit.edit,
                ),
            ],
            if (success)
              DsButton(
                label: l10n.operationToAccountPage,
                onPressed: () => context.pop(),
              ),
          ],
          if (state.problem case final problem?)
            DsStatus(
              title: _operationProblem(l10n, formats, state, problem, currency),
              kind: problem == AccountOperationProblem.restored
                  ? DsStatusKind.info
                  : DsStatusKind.error,
              action: problem == AccountOperationProblem.recipientsUnavailable
                  ? DsButton(
                      label: l10n.commonRetry,
                      onPressed: _cubit.retryRecipients,
                    )
                  : null,
            ),
        ],
      );
    },
  );
}

String _operationProblem(
  AppLocalizations l10n,
  AppFormats formats,
  AccountOperationState state,
  AccountOperationProblem problem,
  String currency,
) => switch (problem) {
  AccountOperationProblem.restored => l10n.operationRestored,
  AccountOperationProblem.journalUnreadable => l10n.operationJournalUnreadable,
  AccountOperationProblem.invalidAmount => l10n.operationInvalidAmount(
    formats.money(Money(1, currency: currency)),
    formats.money(Money(accountOperationLimit.minor, currency: currency)),
  ),
  AccountOperationProblem.insufficientFunds =>
    l10n.paymentErrorInsufficientFunds,
  AccountOperationProblem.invalidDestination =>
    l10n.operationInvalidDestination,
  AccountOperationProblem.invalidRecipient => l10n.operationInvalidRecipient,
  AccountOperationProblem.earlierRequestPending => l10n.operationEarlierPending,
  AccountOperationProblem.rejectedJournalStuck => l10n.operationRejectedStuck,
  AccountOperationProblem.rejected => state.serverMessage ?? l10n.errorRejected,
  AccountOperationProblem.resultUnknown => l10n.operationResultUnknown,
  AccountOperationProblem.recipientsUnavailable =>
    l10n.operationRecipientsUnavailable,
};

/// Scanner input is deliberately represented by synthetic codes. No camera or
/// external URL is opened, and only explicit internal destinations are allowed.
class _QrDemoPage extends StatefulWidget {
  const _QrDemoPage({required this.accounts});
  final List<Account> accounts;
  @override
  State<_QrDemoPage> createState() => _QrDemoPageState();
}

enum _QrProblem { invalid, unsupported }

class _QrDemoPageState extends State<_QrDemoPage> {
  final _code = TextEditingController();
  _QrProblem? _problem;
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _open(String value) {
    final uri = Uri.tryParse(value.trim());
    final parts = uri?.pathSegments ?? const <String>[];
    final accountId = uri?.host == 'topup' && parts.length == 1
        ? parts.single
        : uri?.queryParameters['account'] ?? 'main';
    final account = widget.accounts.where((a) => a.id == accountId).firstOrNull;
    if (uri == null || uri.scheme != 'demobank' || account == null) {
      setState(() => _problem = _QrProblem.invalid);
      return;
    }
    if (uri.host == 'topup' && parts.length == 1) {
      context.push('/account/${account.id}/topup');
      return;
    }
    if (uri.host == 'pay' &&
        parts.length == 1 &&
        const [
          'utilities',
          'mobile',
          'fines',
          'cinema',
        ].contains(parts.single) &&
        account.balance.currency == 'RUB') {
      context.push('/pay/${parts.single}?account=${account.id}');
      return;
    }
    setState(() => _problem = _QrProblem.unsupported);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DsPage(
      title: l10n.qrTitle,
      children: [
        DsText(l10n.qrHint),
        const DsQrCode(data: 'demobank://pay/utilities?account=main'),
        DsField(
          label: l10n.qrField,
          controller: _code,
          error: switch (_problem) {
            _QrProblem.invalid => l10n.qrInvalid,
            _QrProblem.unsupported => l10n.qrUnsupported,
            null => null,
          },
          hint: 'demobank://…',
        ),
        DsButton(label: l10n.qrOpen, onPressed: () => _open(_code.text)),
        DsListTile(
          title: l10n.qrSampleUtilities,
          icon: DsIcons.home,
          onTap: () => _open('demobank://pay/utilities?account=main'),
        ),
        DsListTile(
          title: l10n.qrSampleTopUp,
          icon: DsIcons.add,
          onTap: () => _open('demobank://topup/main'),
        ),
      ],
    );
  }
}
