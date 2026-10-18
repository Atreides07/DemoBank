import 'dart:async';

import 'package:app_localizations/app_localizations.dart';
import 'package:bank_core/bank_core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'history_cubit.dart';

IconData categoryIcon(String id) => switch (id) {
  'groceries' => DsIcons.groceries,
  'transport' => DsIcons.transport,
  'dining' => DsIcons.cafe,
  'shopping' => DsIcons.shopping,
  'utilities' => DsIcons.home,
  'health' => DsIcons.health,
  'entertainment' => DsIcons.ticket,
  _ => DsIcons.receipt,
};

/// A sliver, so the bank header and history share one scrolling surface.
class HistorySliver extends StatelessWidget {
  const HistorySliver({
    super.key,
    required this.cubit,
    required this.controller,
    required this.onEntry,
    this.showFilters = true,
    this.showUpdateAction = true,
    this.animate = true,
    this.density = DsDensity.comfortable,
  });
  final HistoryCubit cubit;
  final ScrollController controller;
  final ValueChanged<LedgerEntry> onEntry;
  final bool showFilters;

  /// Hosts with their own update overlay disable this inline action.
  final bool showUpdateAction;
  final bool animate;
  final DsDensity density;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final formats = context.formats;
    // Preserve this widget identity across history status/total updates;
    // the applied category has its own narrow subscription.
    final filterChoices = BlocSelector<HistoryCubit, HistoryState, String?>(
      bloc: cubit,
      selector: (state) => state.filter.category,
      builder: (context, selectedCategory) => DsFilterBar(
        id: 'history-categories',
        children: [
          DsChoice(
            label: l10n.commonAll,
            selected: selectedCategory == null,
            onSelected: (_) => unawaited(
              cubit.load(
                filter: cubit.state.filter.copyWith(clearCategory: true),
              ),
            ),
          ),
          for (final category in spendingCategories)
            DsChoice(
              label: l10n.categoryName(category),
              selected: selectedCategory == category,
              onSelected: (_) => unawaited(
                cubit.load(
                  filter: cubit.state.filter.copyWith(category: category),
                ),
              ),
            ),
        ],
      ),
    );
    return BlocConsumer<HistoryCubit, HistoryState>(
      bloc: cubit,
      listenWhen: (previous, current) =>
          previous.filter != current.filter &&
          !current.ids.values.contains(cubit.readingAnchorId),
      listener: (context, _) {
        if (!context.mounted || !controller.hasClients) return;
        // Reveal this result section, including any host prefix and pinned
        // header. A retained anchor keeps the design system's normal continuity.
        unawaited(Scrollable.ensureVisible(context));
      },
      builder: (context, state) => SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: DsPadding(
              inset: density == DsDensity.compact
                  ? DsInset.listHeader
                  : DsInset.page,
              child: DsColumn(
                children: [
                  DsSection(
                    density: density,
                    title: l10n.historyTitle,
                    subtitle: state.total == 0 || density == DsDensity.compact
                        ? null
                        : l10n.commonOperationsCount(state.total),
                    action: density == DsDensity.compact
                        ? DsIconButton(
                            label: l10n.commonRefresh,
                            icon: DsIcons.refresh,
                            onPressed: () =>
                                unawaited(cubit.load(background: true)),
                          )
                        : DsButton(
                            label: l10n.commonRefresh,
                            variant: DsButtonVariant.quiet,
                            icon: DsIcons.refresh,
                            onPressed: () =>
                                unawaited(cubit.load(background: true)),
                          ),
                    child: DsColumn(
                      children: [
                        if (showFilters) filterChoices,
                        if (state.pendingFilter != null && state.rowCount > 0)
                          DsStatus(
                            title: l10n.historyUpdatingTitle,
                            message: l10n.historyUpdatingMessage,
                            kind: DsStatusKind.loading,
                          ),
                        if (state.stale) DsText(l10n.commonSavedDataStale),
                        if (showUpdateAction && state.pendingUpdate != null)
                          DsButton(
                            label: l10n.historyShowNew,
                            icon: DsIcons.toTop,
                            onPressed: cubit.applyUpdate,
                          ),
                        if (state.failed)
                          DsStatus(
                            title: l10n.historyFailed,
                            kind: DsStatusKind.error,
                            action: DsButton(
                              label: l10n.commonRetry,
                              onPressed: () => unawaited(cubit.load()),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (state.rowCount == 0)
            SliverToBoxAdapter(
              child: DsPadding(
                child: state.loading
                    ? DsStatus(
                        title: l10n.historyLoading,
                        kind: DsStatusKind.loading,
                      )
                    : !state.failed
                    ? DsStatus(
                        title: l10n.historyEmptyTitle,
                        message: l10n.historyEmptyMessage,
                        kind: DsStatusKind.empty,
                      )
                    : const DsGap(),
              ),
            ),
          DsAnimatedSliverList<HistorySlot>(
            items: state.slots,
            idOf: (slot) => slot.id,
            controller: controller,
            onAnchorChanged: (id) {
              if (state.ids.values.contains(id)) cubit.readingAnchorId = id;
            },
            animate: animate,
            itemBuilder: (context, slot) {
              final entry = slot.entry;
              if (entry == null &&
                  !state.failedPages.contains(
                    slot.index ~/ HistoryState.pageSize,
                  )) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) unawaited(cubit.ensureIndex(slot.index));
                });
              }
              final previousDay = slot.index == 0
                  ? null
                  : state.days[slot.index - 1];
              final day = slot.day != null && slot.day != previousDay
                  ? DateTime.tryParse(slot.day!)
                  : null;
              final updated =
                  entry != null && state.updatedIds.contains(entry.id);
              return _HistoryRow(
                entry: entry,
                text: (
                  dayLabel: day == null ? null : formats.date(day),
                  subtitle: entry == null
                      ? null
                      : (updated
                            ? l10n.historyUpdatedEntry
                            : l10n.historyEntry)(
                          l10n.category(entry.categoryId, entry.subtitle),
                          l10n.entryStatus(entry.status.name),
                        ),
                  value: entry == null ? null : formats.entryAmount(entry),
                  retryLabel: l10n.historyRetryPage,
                ),
                updated: updated,
                hasRetry:
                    entry == null &&
                    state.failedPages.contains(
                      slot.index ~/ HistoryState.pageSize,
                    ),
                onEntry: onEntry,
                onRetry: () => unawaited(cubit.ensureIndex(slot.index)),
              );
            },
          ),
          SliverToBoxAdapter(
            child: DsPadding(
              child: state.hasMore
                  ? DsButton(
                      label: state.loadingPages.isEmpty
                          ? l10n.historyShowMore
                          : l10n.commonLoadingEllipsis,
                      onPressed: state.loadingPages.isEmpty
                          ? () => unawaited(cubit.loadNext())
                          : null,
                    )
                  : state.rowCount > 0
                  ? DsText(l10n.historyEnd)
                  : const DsGap(),
            ),
          ),
        ],
      ),
    );
  }
}

typedef _HistoryRowVisual = ({
  String? dayLabel,
  String? entryId,
  String? title,
  String? category,
  String? subtitle,
  String? value,
  bool positive,
  bool updated,
  bool hasRetry,
  String retryLabel,
});

/// Words and formatted values of one row, resolved by the list in the
/// interface language. The row itself reads nothing from its context.
typedef _HistoryRowText = ({
  String? dayLabel,
  String? subtitle,
  String? value,
  String retryLabel,
});

/// A mounted lazy row owns just its current visual subtree. DS descendants
/// retain their own inherited palette and layout dependencies.
class _HistoryRow extends StatefulWidget {
  const _HistoryRow({
    required this.entry,
    required this.text,
    required this.updated,
    required this.hasRetry,
    required this.onEntry,
    required this.onRetry,
  });
  final LedgerEntry? entry;
  final _HistoryRowText text;
  final bool updated;
  final bool hasRetry;
  final ValueChanged<LedgerEntry> onEntry;
  final VoidCallback onRetry;

  @override
  State<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<_HistoryRow> {
  late _HistoryRowVisual _visual;
  late Widget _child;

  _HistoryRowVisual get _currentVisual {
    final entry = widget.entry;
    return (
      dayLabel: widget.text.dayLabel,
      entryId: entry?.id,
      title: entry?.title,
      category: entry?.categoryId,
      subtitle: widget.text.subtitle,
      value: widget.text.value,
      positive:
          entry != null &&
          entry.kind != EntryKind.expense &&
          entry.amount.minor >= 0,
      updated: widget.updated,
      hasRetry: widget.hasRetry,
      retryLabel: widget.text.retryLabel,
    );
  }

  @override
  void initState() {
    super.initState();
    _visual = _currentVisual;
    _child = _createChild();
  }

  @override
  void didUpdateWidget(covariant _HistoryRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final visual = _currentVisual;
    if (visual != _visual) {
      _visual = visual;
      _child = _createChild();
    }
  }

  // Cached callbacks read the latest widget, including equivalent replacement
  // entities and callbacks. Neither action captures an old row or page index.
  void _openEntry() {
    final entry = widget.entry;
    if (entry != null) widget.onEntry(entry);
  }

  void _retry() => widget.onRetry();

  Widget _createChild() {
    final entry = widget.entry;
    final visual = _visual;
    // Only DS constructors and row values belong here. Theme, MediaQuery and
    // responsive tokens are resolved by those descendants when they build.
    return DsConstrained(
      child: DsPadding(
        inset: DsInset.horizontal,
        child: DsColumn(
          gap: DsSpace.compact,
          children: [
            if (visual.dayLabel case final dayLabel?)
              DsText(dayLabel, style: DsTextStyle.caption, tone: DsTone.muted),
            if (entry != null)
              DsReadingAnchor(
                child: DsTransactionTile(
                  key: ValueKey(entry.id),
                  title: entry.title,
                  subtitle: visual.subtitle ?? '',
                  value: visual.value ?? '',
                  icon: categoryIcon(entry.categoryId),
                  changed: widget.updated,
                  positive: visual.positive,
                  onTap: _openEntry,
                ),
              )
            else if (widget.hasRetry)
              DsButton(label: visual.retryLabel, onPressed: _retry)
            else
              const DsTransactionPlaceholder(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _child;
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.reader,
    required this.onEntry,
    this.filter,
    this.animate = true,
    this.title,
    this.onAnalytics,
    this.reloadSignal,
  });
  final HistoryReader reader;
  final ValueChanged<LedgerEntry> onEntry;
  final LedgerFilter? filter;
  final bool animate;

  /// Defaults to “Transactions” in the interface language.
  final String? title;

  /// Reloads from the first page when notified, for example after the content
  /// language changed and server texts must be replaced.
  final Listenable? reloadSignal;
  final VoidCallback? onAnalytics;
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final HistoryCubit _cubit;
  final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    _cubit = HistoryCubit(widget.reader, filter: widget.filter);
    unawaited(_cubit.load());
    _scroll.addListener(_onScroll);
    widget.reloadSignal?.addListener(_reload);
  }

  void _reload() => unawaited(_cubit.load());

  @override
  void didUpdateWidget(covariant HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadSignal != widget.reloadSignal) {
      oldWidget.reloadSignal?.removeListener(_reload);
      widget.reloadSignal?.addListener(_reload);
    }
  }

  void _onScroll() {
    _cubit.userIsReading =
        _scroll.hasClients &&
        _scroll.offset > _scroll.position.viewportDimension;
    if (_scroll.hasClients &&
        _scroll.position.extentAfter < _scroll.position.viewportDimension) {
      unawaited(_cubit.loadNext());
    }
  }

  @override
  void dispose() {
    widget.reloadSignal?.removeListener(_reload);
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    unawaited(_cubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DsScaffold(
    title: widget.title ?? context.l10n.accountOperations,
    actions: [
      if (widget.onAnalytics != null)
        DsIconButton(
          label: context.l10n.analyticsForAccount,
          icon: DsIcons.analytics,
          onPressed: widget.onAnalytics,
        ),
    ],
    body: RefreshIndicator(
      onRefresh: () => _cubit.load(background: true),
      child: CustomScrollView(
        key: PageStorageKey<Object>(widget.filter ?? 'history'),
        controller: _scroll,
        slivers: [
          HistorySliver(
            cubit: _cubit,
            controller: _scroll,
            onEntry: widget.onEntry,
            showFilters: widget.filter == null,
            animate: widget.animate,
          ),
        ],
      ),
    ),
  );
}

class TransactionDetails extends StatelessWidget {
  const TransactionDetails({super.key, required this.entry, this.accountLabel});
  final LedgerEntry entry;

  /// Name of the account; a generic name in the interface language otherwise.
  final String? accountLabel;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final formats = context.formats;
    return DsPage(
      title: l10n.detailsTitle,
      children: [
        DsCard(
          child: DsColumn(
            children: [
              DsText(entry.title, style: DsTextStyle.title),
              DsMoneyText(formats.entryAmount(entry)),
              DsText(entry.subtitle),
            ],
          ),
        ),
        DsListTile(
          title: l10n.detailsCategory,
          trailing: DsText(l10n.category(entry.categoryId, entry.categoryId)),
        ),
        DsListTile(
          title: l10n.detailsDateTime,
          subtitle: l10n.detailsDateTimeValue(
            formats.date(entry.occurredAt),
            formats.time(entry.occurredAt),
            l10n.commonMoscowTime,
          ),
        ),
        DsListTile(
          title: l10n.detailsStatus,
          subtitle: l10n.entryStatus(entry.status.name),
        ),
        DsListTile(
          title: l10n.detailsAccount,
          subtitle: accountLabel ?? l10n.detailsDefaultAccount,
        ),
        DsListTile(title: l10n.detailsNumber, subtitle: entry.id),
      ],
    );
  }
}
