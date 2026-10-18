part of '../bank_experience.dart';

class _CardWorkspace extends StatefulWidget {
  const _CardWorkspace({
    super.key,
    required this.account,
    required this.card,
    required this.saving,
    required this.loadHistory,
    required this.onSave,
    required this.loadRequisites,
  });
  final Account account;
  final AccountCard card;
  final bool saving;
  final Future<LedgerPage> Function({bool refresh}) loadHistory;
  final Future<bool> Function(AccountPreferences) onSave;
  final Future<CardRequisites> Function() loadRequisites;

  @override
  State<_CardWorkspace> createState() => _CardWorkspaceState();
}

class _CardWorkspaceState extends State<_CardWorkspace> {
  late Future<LedgerPage> _history = widget.loadHistory();
  LedgerFilter get _filter => LedgerFilter(
    accounts: [widget.account.id],
    cardId: widget.card.id,
    currency: widget.account.balance.currency,
  );

  Future<void> _freeze() async {
    final card = widget.card;
    if (!card.frozen) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.cardFreezeTitle),
          content: Text(
            '${context.l10n.accountCard(card.lastDigits)}\n\n${context.l10n.cardFreezeDescription}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: context.dsPalette.danger,
              ),
              child: Text(context.l10n.accountConfirmFreeze),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await widget.onSave(
      AccountPreferences(frozenCardId: card.id, frozen: !card.frozen),
    );
  }

  Future<void> _limits() async {
    final limit = widget.card.monthlyLimit;
    if (limit == null) return;
    final minor = await showDialog<int>(
      context: context,
      builder: (_) => _CardLimitDialog(limit: limit),
    );
    if (minor != null && mounted) {
      await widget.onSave(
        AccountPreferences(
          limitCardId: widget.card.id,
          monthlyLimitMinor: minor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final formats = context.formats;
    final card = widget.card;
    return DsColumn(
      children: [
        Wrap(
          spacing: DsTokens.space(DsSpace.regular),
          runSpacing: DsTokens.space(DsSpace.compact),
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DsText(l10n.accountCard(card.lastDigits), style: DsTextStyle.title),
            DsBadge(
              card.frozen ? l10n.accountCardFrozen : l10n.accountCardActive,
              success: !card.frozen,
            ),
          ],
        ),
        DsShortcutBar(
          actions: [
            DsShortcut(
              l10n.cardDetails,
              DsIcons.card,
              widget.saving
                  ? null
                  : () {
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        showDragHandle: true,
                        builder: (_) =>
                            _CardRequisitesSheet(load: widget.loadRequisites),
                      );
                    },
            ),
            DsShortcut(
              card.frozen ? l10n.cardUnfreeze : l10n.cardFreeze,
              card.frozen ? DsIcons.unlock : DsIcons.freeze,
              widget.saving ? null : _freeze,
            ),
            DsShortcut(
              l10n.cardLimits,
              DsIcons.settings,
              widget.saving || card.monthlyLimit == null ? null : _limits,
            ),
          ],
        ),
        DsPanel(
          child: DsColumn(
            children: [
              DsText(
                l10n.cardLinkedAccount,
                style: DsTextStyle.caption,
                tone: DsTone.muted,
              ),
              DsText(widget.account.name, style: DsTextStyle.title),
              DsMoneyText(formats.money(widget.account.available)),
              DsText(l10n.cardSharedBalance, style: DsTextStyle.caption),
              DsText(
                l10n.cardSharedBalanceHint,
                style: DsTextStyle.caption,
                tone: DsTone.muted,
              ),
            ],
          ),
        ),
        DsListTile(
          title: l10n.cardMonthlyLimit,
          subtitle: card.monthlyLimit == null
              ? l10n.cardLimitUnavailable
              : formats.money(card.monthlyLimit!),
          onTap: widget.saving || card.monthlyLimit == null ? null : _limits,
        ),
        DsText(l10n.cardTransactions, style: DsTextStyle.title),
        FutureBuilder<LedgerPage>(
          future: _history,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return DsStatus(
                title: l10n.cardTransactionsFailed,
                kind: DsStatusKind.error,
                action: DsButton(
                  label: l10n.commonRetry,
                  onPressed: () => setState(
                    () => _history = widget.loadHistory(refresh: true),
                  ),
                ),
              );
            }
            final page = snapshot.data;
            if (page == null) {
              return DsStatus(
                title: l10n.commonLoadingEllipsis,
                kind: DsStatusKind.loading,
              );
            }
            if (page.items.isEmpty) {
              return DsStatus(
                title: l10n.cardNoTransactions,
                kind: DsStatusKind.empty,
              );
            }
            return DsColumn(
              children: [
                for (final entry in page.items)
                  DsTransactionTile(
                    key: ValueKey('card-operation-${entry.id}'),
                    title: entry.title,
                    subtitle:
                        '${formats.date(entry.occurredAt)} · ${l10n.entryStatus(entry.status.name)}',
                    value: formats.entryAmount(entry),
                    icon: categoryIcon(entry.categoryId),
                    positive: entry.kind != EntryKind.expense,
                    onTap: () => context.push('/transaction', extra: entry),
                  ),
                DsButton(
                  label: l10n.cardAllTransactions,
                  variant: DsButtonVariant.quiet,
                  onPressed: () => context.push('/history', extra: _filter),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CardLimitDialog extends StatefulWidget {
  const _CardLimitDialog({required this.limit});
  final Money limit;
  @override
  State<_CardLimitDialog> createState() => _CardLimitDialogState();
}

class _CardLimitDialogState extends State<_CardLimitDialog> {
  final _amount = TextEditingController();
  bool _initialized = false;
  bool _invalid = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _amount.text = context.formats.amountInput(widget.limit.minor);
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.cardMonthlyLimit),
    content: SingleChildScrollView(
      child: DsColumn(
        children: [
          DsText(context.l10n.cardLimitHint),
          DsField(
            label: context.formats.currencySymbol(widget.limit.currency),
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          if (_invalid)
            DsText(context.l10n.cardLimitInvalid, tone: DsTone.danger),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.commonCancel),
      ),
      TextButton(
        onPressed: () {
          final minor = context.formats.parseAmount(
            _amount.text,
            maxIntegerDigits: 7,
          );
          if (minor == null || minor > 999999999) {
            setState(() => _invalid = true);
            return;
          }
          Navigator.pop(context, minor);
        },
        child: Text(context.l10n.cardSaveLimit),
      ),
    ],
  );
}

class _CardRequisitesSheet extends StatefulWidget {
  const _CardRequisitesSheet({required this.load});
  final Future<CardRequisites> Function() load;
  @override
  State<_CardRequisitesSheet> createState() => _CardRequisitesSheetState();
}

class _CardRequisitesSheetState extends State<_CardRequisitesSheet> {
  late Future<CardRequisites> _data = widget.load();
  bool _copied = false;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: DsTokens.inset(context, DsInset.bottomSheet),
      child: DsColumn(
        children: [
          DsText(context.l10n.cardDetails, style: DsTextStyle.title),
          DsText(
            context.l10n.cardDemoDetails,
            style: DsTextStyle.caption,
            tone: DsTone.muted,
          ),
          FutureBuilder<CardRequisites>(
            future: _data,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return DsStatus(
                  title: context.l10n.cardDetailsFailed,
                  kind: DsStatusKind.error,
                  action: DsButton(
                    label: context.l10n.commonRetry,
                    onPressed: () => setState(() => _data = widget.load()),
                  ),
                );
              }
              final data = snapshot.data;
              if (data == null) {
                return DsStatus(
                  title: context.l10n.commonLoadingEllipsis,
                  kind: DsStatusKind.loading,
                );
              }
              return DsColumn(
                children: [
                  DsKeyValue(
                    label: context.l10n.cardNumber,
                    value: data.number,
                  ),
                  DsKeyValue(
                    label: context.l10n.cardExpiry,
                    value: data.expiry,
                  ),
                  DsKeyValue(label: 'CVC', value: data.cvc),
                  DsButton(
                    label: _copied
                        ? context.l10n.accountCopied
                        : context.l10n.cardCopyNumber,
                    icon: DsIcons.copy,
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: data.number.replaceAll(' ', '')),
                      );
                      if (mounted) setState(() => _copied = true);
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}
