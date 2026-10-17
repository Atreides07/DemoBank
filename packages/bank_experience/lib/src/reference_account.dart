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
  @override
  void initState() {
    super.initState();
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
      filter: ReportingPeriod.month(
        widget.environment.now(),
      ).copyWith(accounts: [widget.accountId], currency: currency),
    );
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
          return DsPage(
            title: 'Счёт',
            children: [
              DsStatus(
                title: accounts.loading ? 'Загружаем счёт' : 'Счёт не найден',
                kind: accounts.loading
                    ? DsStatusKind.loading
                    : DsStatusKind.error,
              ),
            ],
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
                  spendingPoints: overview.summary == null
                      ? const []
                      : spendingChartPoints(overview.summary!),
                  error: state.error ?? overview.error,
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

class _AccountActionPage extends StatefulWidget {
  const _AccountActionPage({
    required this.accountId,
    required this.action,
    required this.environment,
    required this.accounts,
    required this.onChanged,
    required this.operationJournal,
    this.cardId,
  });
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
  final _name = TextEditingController();
  bool _saved = false;
  bool _certificate = false;
  bool _copied = false;
  @override
  void initState() {
    super.initState();
    _profile = AccountManagementCubit(
      ApiAccountManagement(widget.environment.api, widget.environment.cache),
      widget.accountId,
    );
    unawaited(_profile.load());
  }

  @override
  void dispose() {
    _name.dispose();
    unawaited(_profile.close());
    super.dispose();
  }

  Future<void> _save(AccountPreferences value) async {
    final saved = await _profile.update(value);
    if (!mounted) return;
    if (saved) {
      widget.onChanged();
      setState(() => _saved = true);
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) setState(() => _copied = true);
  }

  String _title(String action) => switch (action) {
    'rename' => 'Название счёта',
    'pay' => 'Оплатить или перевести',
    'rewards' => 'Бонусы по счёту',
    'autoTopUp' => 'Автопополнение',
    'salary' => 'Зарплата на счёт',
    'pension' => 'Пенсия на счёт',
    'social' => 'Социальные выплаты',
    'cashback' => 'Зачисление кэшбэка',
    'roundUp' => 'Округление покупок',
    'addCard' => 'Дополнительная карта',
    'limits' => 'Лимиты счёта',
    'requisites' => 'Реквизиты',
    'qr' => 'QR для пополнения',
    'link' => 'Ссылка на пополнение',
    'linkedServices' => 'Привязанные сервисы',
    'plan' => 'Тариф',
    'statement' => 'Выписка по счёту',
    'certificate' => 'Справка о счёте',
    'services' => 'Услуги счёта',
    'freezeCard' => 'Управление картой',
    _ => 'Действие со счётом',
  };
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<AccountsCubit, AccountsState>(
    bloc: widget.accounts,
    builder: (context, accounts) {
      final account = accounts.accounts
          .where((a) => a.id == widget.accountId)
          .firstOrNull;
      if (account == null) {
        return const DsPage(
          title: 'Счёт',
          children: [
            DsStatus(
              title: 'Загружаем данные счёта',
              kind: DsStatusKind.loading,
            ),
          ],
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
            DsText(p?.name ?? account.name, style: DsTextStyle.title),
            if (state.error != null)
              DsStatus(
                title: state.error!,
                kind: DsStatusKind.error,
                action: DsButton(label: 'Обновить', onPressed: _profile.load),
              ),
            if (state.saving)
              const DsStatus(
                title: 'Сохраняем настройку',
                kind: DsStatusKind.loading,
              ),
            if (_saved)
              const DsStatus(
                title: 'Изменения сохранены',
                kind: DsStatusKind.success,
              ),
            if (p == null && action != 'pay')
              DsStatus(
                title: 'Загружаем настройки',
                kind: DsStatusKind.loading,
              ),
          ];
          if (action == 'pay') {
            children.addAll([
              DsPanel(
                child: DsColumn(
                  children: [
                    DsText(
                      'Доступно ${account.available.format()}',
                      style: DsTextStyle.headline,
                    ),
                    DsButton(
                      label: 'Между своими счетами',
                      icon: DsIcons.transfer,
                      onPressed: () =>
                          context.push('/account/${account.id}/transfer'),
                    ),
                  ],
                ),
              ),
              if (account.balance.currency == 'RUB')
                DsButton(
                  label: 'По номеру телефона',
                  icon: DsIcons.mobile,
                  onPressed: () => context.push('/account/${account.id}/phone'),
                ),
              if (account.balance.currency == 'RUB')
                DsButton(
                  label: 'Оплатить услугу',
                  icon: DsIcons.services,
                  onPressed: () =>
                      context.push('/account-services/${account.id}'),
                ),
              DsButton(
                label: 'Пополнить счёт',
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
                    label: 'Новое название',
                    hint: p.name,
                    controller: _name,
                  ),
                  const DsText(
                    'От 1 до 32 символов',
                    style: DsTextStyle.caption,
                    tone: DsTone.muted,
                  ),
                  DsButton(
                    label: 'Сохранить название',
                    onPressed: state.saving
                        ? null
                        : () => _save(AccountPreferences(name: _name.text)),
                  ),
                ]);
              case 'autoTopUp':
                children.addAll([
                  const DsText(
                    'Учебное правило: пополнять на 1 000 ₽, когда остаток ниже 500 ₽. Источник — демонстрационная внешняя карта.',
                  ),
                  DsSwitchRow(
                    title: 'Автопополнение',
                    value: p.autoTopUp,
                    onChanged: state.saving
                        ? null
                        : (v) => _save(AccountPreferences(autoTopUp: v)),
                  ),
                ]);
              case 'roundUp':
                children.addAll([
                  const DsText(
                    'Округлять будущие покупки до 100 ₽. Разница будет отмечаться в демонстрационных накоплениях.',
                  ),
                  DsSwitchRow(
                    title: 'Округлять покупки',
                    value: p.roundUp,
                    onChanged: state.saving
                        ? null
                        : (v) => _save(AccountPreferences(roundUp: v)),
                  ),
                ]);
              case 'cashback':
                children.addAll([
                  const DsText('Выберите счёт для зачисления бонусов'),
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
                    title: 'Помогать фонду «Добрый день»',
                    subtitle: 'Учебный фонд · демонстрационный выбор',
                    value: p.charity,
                    onChanged: state.saving
                        ? null
                        : (v) => _save(AccountPreferences(charity: v)),
                  ),
                ]);
              case 'addCard':
                children.addAll([
                  const DsFeatureArtwork(DsArt.cardPromo),
                  const DsText(
                    'Виртуальная карта для общих покупок. Выпуск и обслуживание в демо бесплатны.',
                  ),
                  if (p.cards.any((c) => c.lastDigits == '6057'))
                    const DsStatus(
                      title: 'Карта •• 6057 уже добавлена',
                      kind: DsStatusKind.success,
                    )
                  else
                    DsButton(
                      label: 'Выпустить демо-карту',
                      onPressed: state.saving
                          ? null
                          : () => _save(
                              const AccountPreferences(extraCard: true),
                            ),
                    ),
                ]);
              case 'freezeCard':
                children.addAll([
                  DsBankCards(
                    cards: [
                      for (final c in p.cards)
                        DsBankCardData(c.id, c.lastDigits, frozen: c.frozen),
                    ],
                    onCard: (id) => context.replace(
                      '/account/${account.id}/freezeCard?card=$id',
                    ),
                  ),
                  if (card != null) ...[
                    DsText(
                      'Карта •• ${card.lastDigits}',
                      style: DsTextStyle.headline,
                    ),
                    DsText(card.frozen ? 'Заморожена' : 'Активна'),
                    const DsText(
                      'Заморозка обратима и относится только к выбранной демонстрационной карте.',
                    ),
                    DsButton(
                      label: card.frozen
                          ? 'Разморозить карту'
                          : 'Подтвердить заморозку',
                      variant: card.frozen
                          ? DsButtonVariant.primary
                          : DsButtonVariant.danger,
                      onPressed: state.saving
                          ? null
                          : () => _save(
                              AccountPreferences(
                                frozenCardId: card.id,
                                frozen: !card.frozen,
                              ),
                            ),
                    ),
                  ],
                ]);
              case 'limits':
                children.addAll([
                  for (final l in p.limits)
                    DsPanel(
                      child: DsColumn(
                        children: [
                          DsLimitRow(
                            title: l.title,
                            detail: 'Доступно ${l.remaining.format()}',
                            fraction: l.remaining.minor / l.limit.minor,
                          ),
                          DsKeyValue(
                            label: 'Лимит в месяц',
                            value: l.limit.format(),
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
                  const DsText(
                    'Учебные реквизиты. Не используйте для настоящих переводов.',
                    tone: DsTone.muted,
                  ),
                  for (final r in p.requisites.entries)
                    DsKeyValue(label: r.key, value: r.value),
                  DsButton(
                    label: _copied ? 'Скопировано' : 'Скопировать реквизиты',
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
                  const DsText(
                    'Учебная ссылка работает только внутри DemoBank. Настоящие переводы недоступны.',
                    tone: DsTone.muted,
                  ),
                  DsKeyValue(label: 'Ссылка на счёт', value: link),
                  DsButton(
                    label: _copied
                        ? 'Ссылка скопирована'
                        : 'Скопировать ссылку',
                    icon: DsIcons.copy,
                    onPressed: () => _copy(link),
                  ),
                ]);
              case 'linkedServices':
                children.addAll([
                  const DsText(
                    'Разрешение сохранённых привязок демонстрационных сервисов.',
                  ),
                  if (p.linkedServicesEnabled) ...[
                    for (final title in [
                      'Демо Маркет',
                      'Музыка',
                      'Кино Дома',
                      'Город Паркинг',
                      'Кофе Клуб',
                      'Доставка',
                    ])
                      DsListTile(
                        title: title,
                        subtitle: 'Карта •• ${account.lastDigits}',
                      ),
                  ],
                  DsSwitchRow(
                    title: 'Разрешить привязанные сервисы',
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
                  const DsPanel(
                    child: DsColumn(
                      children: [
                        DsText('Демо Плюс', style: DsTextStyle.headline),
                        DsKeyValue(label: 'Обслуживание', value: 'Бесплатно'),
                        DsKeyValue(
                          label: 'Кэшбэк',
                          value: 'До 30% у учебных партнёров',
                        ),
                        DsKeyValue(
                          label: 'Переводы между своими счетами',
                          value: 'Без комиссии',
                        ),
                      ],
                    ),
                  ),
                );
              case 'statement':
                children.addAll([
                  const DsText(
                    'Все операции выбранного счёта, включая поступления и переводы. Можно открыть любую запись.',
                  ),
                  DsButton(
                    label: 'Открыть выписку',
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
                final text =
                    'ДЕМО-СПРАВКА\nВладелец: Алексей Демонов\nСчёт: ${p.name}\nОстаток: ${account.balance.format()}\nДоговор: ${p.contract}\nУчебный документ, юридической силы не имеет.';
                children.addAll([
                  const DsText(
                    'Справка об остатке на выбранном счёте. Данные и документ учебные.',
                  ),
                  if (_certificate) DsPanel(child: DsText(text)),
                  DsButton(
                    label: _certificate
                        ? (_copied
                              ? 'Справка скопирована'
                              : 'Скопировать справку')
                        : 'Сформировать справку',
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
                    title: 'Автопополнение',
                    subtitle: p.autoTopUp ? 'Включено' : 'Выключено',
                    onTap: () =>
                        context.push('/account/${account.id}/autoTopUp'),
                  ),
                  DsListTile(
                    title: 'Округление покупок',
                    subtitle: p.roundUp ? 'Включено' : 'Выключено',
                    onTap: () => context.push('/account/${account.id}/roundUp'),
                  ),
                  DsListTile(
                    title: 'Привязанные сервисы',
                    onTap: () =>
                        context.push('/account/${account.id}/linkedServices'),
                  ),
                ]);
              case 'rewards':
                children.addAll([
                  DsMoneyText(p.cashback.format()),
                  const DsText('Ожидает зачисления 22 октября'),
                  DsButton(
                    label: 'Выбрать категории кэшбэка',
                    onPressed: () => context.push('/discover/daily-cashback'),
                  ),
                  DsButton(
                    label: 'Подарки за бонусы',
                    variant: DsButtonVariant.secondary,
                    onPressed: () => context.push('/discover/gift'),
                  ),
                  DsButton(
                    label: 'Аналитика этого счёта',
                    variant: DsButtonVariant.quiet,
                    onPressed: () =>
                        context.push('/account-analytics/${account.id}'),
                  ),
                ]);
              default:
                children.add(
                  const DsText('Выберите действие на странице счёта.'),
                );
            }
          }
          return DsPage(title: _title(action), children: children);
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
            ? 'Пополнить счёт'
            : phone
            ? 'По номеру телефона'
            : 'Между своими счетами',
        backEnabled: !busy,
        children: [
          DsPanel(
            child: DsColumn(
              children: [
                DsKeyValue(
                  label: topUp ? 'Зачислим на счёт' : 'Со счёта',
                  value: widget.account.name,
                ),
                DsKeyValue(
                  label: 'Доступно',
                  value: widget.account.balance.format(),
                ),
              ],
            ),
          ),
          if (restoring)
            DsStatus(
              title: 'Восстанавливаем журнал операций',
              kind: state.error == null
                  ? DsStatusKind.loading
                  : DsStatusKind.error,
              action: state.error == null
                  ? null
                  : DsButton(
                      label: 'Повторить восстановление',
                      onPressed: _cubit.restore,
                    ),
            )
          else if (editing) ...[
            if (topUp)
              const DsText(
                'Источник: внешняя демонстрационная карта •• 0000. Настоящего списания не будет.',
              ),
            if (phone) ...[
              const DsText(
                'Выберите демонстрационный контакт. Номера учебные.',
              ),
              for (final r in _cubit.recipients)
                DsChoice(
                  label: '${r.name} · ${r.bank} · ${r.phone}',
                  selected: _destination == r.id,
                  onSelected: (_) => setState(() => _destination = r.id),
                ),
            ],
            if (!topUp && !phone) ...[
              const DsText('На свой счёт'),
              for (final a in widget.accounts.where(
                (a) =>
                    a.id != widget.account.id &&
                    a.balance.currency == widget.account.balance.currency,
              ))
                DsChoice(
                  label: '${a.name} · ${a.balance.format()}',
                  selected: _destination == a.id,
                  onSelected: (_) => setState(() => _destination = a.id),
                ),
              if (!widget.accounts.any(
                (a) =>
                    a.id != widget.account.id &&
                    a.balance.currency == widget.account.balance.currency,
              ))
                const DsStatus(
                  title: 'Нет второго счёта в этой валюте',
                  kind: DsStatusKind.empty,
                ),
            ],
            DsField(
              label: 'Сумма, ${widget.account.balance.currency}',
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            DsButton(
              label: 'Продолжить',
              onPressed: () => _cubit.review(_amount.text, _destination),
            ),
          ] else ...[
            DsMoneyText(state.operation!.amount.format()),
            if (!topUp)
              DsKeyValue(
                label: phone ? 'Получатель' : 'На счёт',
                value: phone
                    ? _cubit.recipients
                              .where(
                                (r) => r.id == state.operation?.destinationId,
                              )
                              .firstOrNull
                              ?.name ??
                          'Учебный контакт'
                    : destination?.name ?? '—',
              ),
            const DsKeyValue(label: 'Комиссия', value: '0 ₽'),
            if (success)
              DsStatus(
                title: topUp ? 'Счёт пополнен' : 'Перевод выполнен',
                message: 'Операция ${state.result!.id} сохранена в истории.',
                kind: DsStatusKind.success,
              )
            else ...[
              DsButton(
                label: busy
                    ? 'Выполняем…'
                    : state.error == null
                    ? 'Подтвердить'
                    : 'Повторить запрос',
                onPressed: busy
                    ? null
                    : () async {
                        final ok = await _cubit.submit();
                        if (ok) widget.onChanged();
                      },
              ),
              if (_cubit.canEdit)
                DsButton(
                  label: 'Изменить сумму',
                  variant: DsButtonVariant.quiet,
                  onPressed: busy ? null : _cubit.edit,
                ),
            ],
            if (success)
              DsButton(label: 'К счёту', onPressed: () => context.pop()),
          ],
          if (state.error != null)
            DsStatus(title: state.error!, kind: DsStatusKind.error),
        ],
      );
    },
  );
}

/// Scanner input is deliberately represented by synthetic codes. No camera or
/// external URL is opened, and only explicit internal destinations are allowed.
class _QrDemoPage extends StatefulWidget {
  const _QrDemoPage({required this.accounts});
  final List<Account> accounts;
  @override
  State<_QrDemoPage> createState() => _QrDemoPageState();
}

class _QrDemoPageState extends State<_QrDemoPage> {
  final _code = TextEditingController();
  String? _error;
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
      setState(
        () => _error =
            'Вставьте учебную ссылку DemoBank или выберите пример ниже.',
      );
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
    setState(
      () => _error =
          'Этот учебный код не поддерживается. Выберите доступный пример.',
    );
  }

  @override
  Widget build(BuildContext context) => DsPage(
    title: 'Сканировать QR',
    children: [
      const DsText('Выберите учебный QR-код или вставьте ссылку DemoBank.'),
      const DsQrCode(data: 'demobank://pay/utilities?account=main'),
      DsField(
        label: 'Ссылка из QR-кода',
        controller: _code,
        error: _error,
        hint: 'demobank://…',
      ),
      DsButton(label: 'Открыть код', onPressed: () => _open(_code.text)),
      DsListTile(
        title: 'Пример · оплата ЖКХ',
        icon: DsIcons.home,
        onTap: () => _open('demobank://pay/utilities?account=main'),
      ),
      DsListTile(
        title: 'Пример · пополнение счёта',
        icon: DsIcons.add,
        onTap: () => _open('demobank://topup/main'),
      ),
    ],
  );
}
