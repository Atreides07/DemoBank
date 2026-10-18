import 'package:app_localizations/app_localizations.dart';
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
    this.spendingMonth,
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

  /// Start of the reporting month [summary] covers.
  final DateTime? spendingMonth;
  final List<DsChartPoint> spendingPoints;

  /// Text of a failed refresh, already in the interface language.
  final String? error;
  final bool loading;
  final bool couponVisible;
  final VoidCallback onDismissCoupon;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final formats = context.formats;
    void open(AccountAction action) => onAction(action);
    final name = profile?.name ?? account.name;
    final month = spendingMonth;
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
          name: name,
          balance: formats.money(account.balance),
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
                  l10n.accountTopUp,
                  DsIcons.add,
                  () => open(AccountAction.topUp),
                ),
                DsShortcut(
                  l10n.accountPayOrTransfer,
                  DsIcons.transfer,
                  () => open(AccountAction.pay),
                ),
              ],
            ),
            if (error != null)
              DsStatus(
                title: error!,
                kind: DsStatusKind.error,
                action: DsButton(label: l10n.commonRetry, onPressed: onRefresh),
              ),
            DsActionGrid(
              children: [
                DsOverviewCard(
                  title: l10n.accountOperations,
                  value: summary == null
                      ? l10n.accountLoadingSpending
                      : formats.money(summary!.total),
                  detail: l10n.spentInMonth(
                    month == null
                        ? 'other'
                        : AppFormats.monthKey(formats.reporting(month).month),
                  ),
                  footer: summary == null
                      ? null
                      : DsSpendingStrip(points: spendingPoints),
                  onTap: () => open(AccountAction.activity),
                ),
                DsOverviewCard(
                  title: l10n.accountCashback,
                  value: profile == null
                      ? '—'
                      : formats.money(profile!.cashback),
                  detail: profile == null
                      ? null
                      : l10n.accountCashbackCredit(
                          formats.dayMonthLong(profile!.cashbackDate),
                        ),
                  footer: DsBadge(l10n.accountPurchaseBonuses),
                  onTap: () => open(AccountAction.rewards),
                ),
              ],
            ),
            if (couponVisible)
              DsOfferBanner(
                title: l10n.accountYourBonuses,
                detail: l10n.accountChooseGift,
                art: DsArt.gift,
                onTap: () => open(AccountAction.rewards),
                onDismiss: onDismissCoupon,
              ),
            panel(l10n.accountBonusesOf(name), [
              DsActionGrid(
                children: [
                  DsArtTile(
                    title: l10n.accountPartnerDiscount(
                      formats.percent(30, fractionDigits: 0),
                    ),
                    art: DsArt.gift,
                    onTap: () => open(AccountAction.rewards),
                  ),
                  DsArtTile(
                    title: l10n.accountMonthCashback,
                    art: DsArt.cashback,
                    onTap: () => open(AccountAction.rewards),
                  ),
                ],
              ),
            ]),
            panel(l10n.accountAutoTopUp, [
              DsText(l10n.accountAutoTopUpHint, tone: DsTone.muted),
              DsButton(
                label: profile?.autoTopUp == true
                    ? l10n.accountConfiguredChange
                    : l10n.accountConfigure,
                variant: DsButtonVariant.secondary,
                onPressed: () => open(AccountAction.autoTopUp),
              ),
            ]),
            panel(l10n.accountReceiveMoney, [
              DsShortcutBar(
                actions: [
                  DsShortcut(
                    l10n.accountSalary,
                    DsIcons.salary,
                    () => open(AccountAction.salary),
                  ),
                  DsShortcut(
                    l10n.accountPension,
                    DsIcons.pension,
                    () => open(AccountAction.pension),
                  ),
                  DsShortcut(
                    l10n.accountBenefits,
                    DsIcons.document,
                    () => open(AccountAction.social),
                  ),
                ],
              ),
            ]),
            panel(l10n.accountCreditTo, [
              tile(
                l10n.accountCashback,
                AccountAction.cashback,
                subtitle: profile?.charity == true
                    ? l10n.accountCashbackCharity
                    : l10n.accountCashbackToAccount,
              ),
            ]),
            panel(l10n.accountRoundUp, [
              DsText(
                l10n.accountRoundUpHint(
                  formats.money(
                    Money(10000, currency: account.balance.currency),
                  ),
                ),
                tone: DsTone.muted,
              ),
              DsButton(
                label: profile?.roundUp == true
                    ? l10n.accountEnabledChange
                    : l10n.accountConfigureRoundUp,
                variant: DsButtonVariant.secondary,
                onPressed: () => open(AccountAction.roundUp),
              ),
            ]),
            panel(l10n.accountFamilyCard, [
              DsText(l10n.accountFamilyCardHint, tone: DsTone.muted),
              DsButton(
                label: l10n.accountAddCard,
                variant: DsButtonVariant.secondary,
                onPressed: () => open(AccountAction.addCard),
              ),
            ]),
            panel(l10n.accountLimits, [
              for (final limit in profile?.limits.take(2) ?? <AccountLimit>[])
                DsLimitRow(
                  title: limit.title,
                  detail: l10n.accountLimitRemaining(
                    formats.money(limit.remaining),
                  ),
                  fraction: limit.remaining.minor / limit.limit.minor,
                ),
              DsButton(
                label: l10n.accountAllLimits,
                variant: DsButtonVariant.secondary,
                onPressed: () => open(AccountAction.limits),
              ),
            ]),
            DsPanel(
              onTap: () => open(AccountAction.requisites),
              child: DsColumn(
                gap: DsSpace.compact,
                children: [
                  DsText(l10n.accountRequisites, style: DsTextStyle.title),
                  DsText(
                    l10n.accountContract(profile?.contract ?? '—'),
                    tone: DsTone.muted,
                  ),
                ],
              ),
            ),
            DsActionGrid(
              children: [
                DsOverviewCard(
                  title: l10n.accountQrCode,
                  value: l10n.accountForTopUp,
                  onTap: () => open(AccountAction.qr),
                ),
                DsOverviewCard(
                  title: l10n.accountLink,
                  value: l10n.accountShare,
                  onTap: () => open(AccountAction.link),
                ),
              ],
            ),
            DsPanel(
              subtle: true,
              child: DsColumn(
                children: [
                  DsText(l10n.accountAbout, style: DsTextStyle.title),
                  tile(l10n.accountLimits, AccountAction.limits),
                  tile(
                    l10n.accountLinkedServices,
                    AccountAction.linkedServices,
                    subtitle: profile?.linkedServicesEnabled == false
                        ? l10n.accountNoLinkedServices
                        : l10n.accountLinkedServicesSummary(4),
                  ),
                  tile(l10n.accountPlan, AccountAction.plan),
                  tile(l10n.accountStatement, AccountAction.statement),
                  tile(l10n.accountCertificate, AccountAction.certificate),
                  tile(l10n.accountServices, AccountAction.services),
                  tile(l10n.accountManageCards, AccountAction.freezeCard),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
