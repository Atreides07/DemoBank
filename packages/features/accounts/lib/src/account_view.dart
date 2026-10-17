import 'package:bank_core/bank_core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

enum AccountAction {
  topUp,
  pay,
  activity,
  rewards,
  autoTopUp,
  salary,
  pension,
  social,
  cashback,
  roundUp,
  addCard,
  limits,
  requisites,
  qr,
  link,
  linkedServices,
  plan,
  statement,
  certificate,
  services,
  freezeCard,
  rename,
}

/// The feature owns the account composition; the host supplies destinations and
/// repositories. Nothing here knows the bank application's router or network.
class AccountDashboard extends StatelessWidget {
  const AccountDashboard({
    super.key,
    required this.account,
    required this.profile,
    required this.scrollController,
    required this.onBack,
    required this.onAction,
    required this.onCard,
    required this.onRefresh,
    this.summary,
    this.spendingPoints = const [],
    this.error,
    this.loading = false,
    this.couponVisible = true,
    required this.onDismissCoupon,
  });
  final Account account;
  final AccountProfile? profile;
  final ScrollController scrollController;
  final VoidCallback onBack;
  final ValueChanged<AccountAction> onAction;
  final ValueChanged<String> onCard;
  final Future<void> Function() onRefresh;
  final SpendingSummary? summary;
  final List<DsChartPoint> spendingPoints;
  final String? error;
  final bool loading;
  final bool couponVisible;
  final VoidCallback onDismissCoupon;

  @override
  Widget build(BuildContext context) {
    void open(AccountAction action) => onAction(action);
    final cards =
        profile?.cards
            .map((c) => DsBankCardData(c.id, c.lastDigits, frozen: c.frozen))
            .toList() ??
        [DsBankCardData('${account.id}-card-0', account.lastDigits)];
    Widget panel(String title, List<Widget> children) => DsPanel(
      child: DsColumn(
        children: [
          DsText(title, style: DsTextStyle.title),
          ...children,
        ],
      ),
    );
    Widget tile(String title, AccountAction action, {String? subtitle}) =>
        DsListTile(title: title, subtitle: subtitle, onTap: () => open(action));
    return DsSliverPage(
      scrollKey: PageStorageKey('account-${account.id}'),
      controller: scrollController,
      darkTop: true,
      prebuildOffscreen: false,
      onRefresh: onRefresh,
      slivers: [
        DsAccountHeader(
          name: profile?.name ?? account.name,
          balance: account.balance.format(),
          cards: cards,
          onBack: onBack,
          onRename: () => open(AccountAction.rename),
          onCard: onCard,
          onAdd: () => open(AccountAction.addCard),
        ),
        DsSliverSections(
          children: [
            DsShortcutBar(
              panel: true,
              actions: [
                DsShortcut(
                  'Пополнить',
                  DsIcons.add,
                  () => open(AccountAction.topUp),
                ),
                DsShortcut(
                  'Оплатить или перевести',
                  DsIcons.transfer,
                  () => open(AccountAction.pay),
                ),
              ],
            ),
            if (error != null)
              DsStatus(
                title: error!,
                kind: DsStatusKind.error,
                action: DsButton(label: 'Повторить', onPressed: onRefresh),
              ),
            DsActionGrid(
              children: [
                DsOverviewCard(
                  title: 'Операции',
                  value: summary == null
                      ? 'Загружаем расходы…'
                      : summary!.total.format(),
                  detail: 'Потрачено в октябре',
                  footer: summary == null
                      ? null
                      : DsSpendingStrip(points: spendingPoints),
                  onTap: () => open(AccountAction.activity),
                ),
                DsOverviewCard(
                  title: 'Кэшбэк',
                  value: profile?.cashback.format() ?? '—',
                  detail: 'Зачислим 22 октября',
                  footer: const DsBadge('Бонусы за покупки'),
                  onTap: () => open(AccountAction.rewards),
                ),
              ],
            ),
            if (couponVisible)
              DsOfferBanner(
                title: 'Ваши бонусы',
                detail: 'Выберите подарок',
                art: DsArt.gift,
                onTap: () => open(AccountAction.rewards),
                onDismiss: onDismissCoupon,
              ),
            panel('Бонусы ${profile?.name ?? account.name}', [
              DsActionGrid(
                children: [
                  DsArtTile(
                    title: 'До 30% у партнёров',
                    art: DsArt.gift,
                    onTap: () => open(AccountAction.rewards),
                  ),
                  DsArtTile(
                    title: 'Кэшбэк октября',
                    art: DsArt.cashback,
                    onTap: () => open(AccountAction.rewards),
                  ),
                ],
              ),
            ]),
            panel('Автопополнение', [
              const DsText(
                'На счёте всегда будут деньги для важных платежей',
                tone: DsTone.muted,
              ),
              DsButton(
                label: profile?.autoTopUp == true
                    ? 'Настроено · изменить'
                    : 'Настроить',
                variant: DsButtonVariant.secondary,
                onPressed: () => open(AccountAction.autoTopUp),
              ),
            ]),
            panel('Получать деньги на счёт', [
              DsShortcutBar(
                actions: [
                  DsShortcut(
                    'Зарплата',
                    DsIcons.salary,
                    () => open(AccountAction.salary),
                  ),
                  DsShortcut(
                    'Пенсия',
                    DsIcons.pension,
                    () => open(AccountAction.pension),
                  ),
                  DsShortcut(
                    'Пособия',
                    DsIcons.document,
                    () => open(AccountAction.social),
                  ),
                ],
              ),
            ]),
            panel('Куда зачислять', [
              tile(
                'Кэшбэк',
                AccountAction.cashback,
                subtitle: profile?.charity == true
                    ? 'В помощь фонду «Добрый день»'
                    : 'На выбранный счёт',
              ),
            ]),
            panel('Округление покупок', [
              const DsText(
                'Откладывайте разницу до 100 ₽ в накопления',
                tone: DsTone.muted,
              ),
              DsButton(
                label: profile?.roundUp == true
                    ? 'Включено · изменить'
                    : 'Настроить округление',
                variant: DsButtonVariant.secondary,
                onPressed: () => open(AccountAction.roundUp),
              ),
            ]),
            panel('Карта для близких', [
              const DsText(
                'Оплачивайте общие покупки и получайте кэшбэк вместе',
                tone: DsTone.muted,
              ),
              DsButton(
                label: 'Добавить карту',
                variant: DsButtonVariant.secondary,
                onPressed: () => open(AccountAction.addCard),
              ),
            ]),
            panel('Лимиты переводов и снятия', [
              for (final limit in profile?.limits.take(2) ?? <AccountLimit>[])
                DsLimitRow(
                  title: limit.title,
                  detail: 'Ещё ${limit.remaining.format()} без комиссии',
                  fraction: limit.remaining.minor / limit.limit.minor,
                ),
              DsButton(
                label: 'Все лимиты счёта',
                variant: DsButtonVariant.secondary,
                onPressed: () => open(AccountAction.limits),
              ),
            ]),
            DsPanel(
              onTap: () => open(AccountAction.requisites),
              child: DsColumn(
                gap: DsSpace.compact,
                children: [
                  const DsText('Реквизиты', style: DsTextStyle.title),
                  DsText(
                    'Договор ${profile?.contract ?? '—'}',
                    tone: DsTone.muted,
                  ),
                ],
              ),
            ),
            DsActionGrid(
              children: [
                DsOverviewCard(
                  title: 'QR-код',
                  value: 'Для пополнения',
                  onTap: () => open(AccountAction.qr),
                ),
                DsOverviewCard(
                  title: 'Ссылка',
                  value: 'Поделиться счётом',
                  onTap: () => open(AccountAction.link),
                ),
              ],
            ),
            DsPanel(
              subtle: true,
              child: DsColumn(
                children: [
                  const DsText('О счёте', style: DsTextStyle.title),
                  tile('Лимиты переводов и снятия', AccountAction.limits),
                  tile(
                    'Привязанные сервисы',
                    AccountAction.linkedServices,
                    subtitle: profile?.linkedServicesEnabled == false
                        ? 'Подключений нет'
                        : 'Демо Маркет, Музыка и ещё 4',
                  ),
                  tile('Тариф', AccountAction.plan),
                  tile('Выписка по счёту', AccountAction.statement),
                  tile('Заказать справку', AccountAction.certificate),
                  tile('Услуги', AccountAction.services),
                  DsButton(
                    label: 'Заморозить карту',
                    variant: DsButtonVariant.danger,
                    onPressed: () => open(AccountAction.freezeCard),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
