import 'dart:async';
import 'package:bank_core/bank_core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'history_cubit.dart';

const categoryLabels = <String, String>{
  'groceries': 'Продукты',
  'transport': 'Транспорт',
  'dining': 'Кафе и рестораны',
  'shopping': 'Покупки',
  'utilities': 'Дом и связь',
  'health': 'Здоровье',
  'entertainment': 'Развлечения',
  'other': 'Другое',
};
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
    // Preserve this widget identity across history status/total updates;
    // the applied category has its own narrow subscription.
    final filterChoices = BlocSelector<HistoryCubit, HistoryState, String?>(
      bloc: cubit,
      selector: (state) => state.filter.category,
      builder: (context, selectedCategory) => DsFilterBar(
        id: 'history-categories',
        children: [
          DsChoice(
            label: 'Все',
            selected: selectedCategory == null,
            onSelected: (_) => unawaited(
              cubit.load(
                filter: cubit.state.filter.copyWith(clearCategory: true),
              ),
            ),
          ),
          for (final category in categoryLabels.entries)
            DsChoice(
              label: category.value,
              selected: selectedCategory == category.key,
              onSelected: (_) => unawaited(
                cubit.load(
                  filter: cubit.state.filter.copyWith(category: category.key),
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
                    title: 'История операций',
                    subtitle: state.total == 0 || density == DsDensity.compact
                        ? null
                        : '${state.total} операций',
                    action: density == DsDensity.compact
                        ? DsIconButton(
                            label: 'Обновить',
                            icon: DsIcons.refresh,
                            onPressed: () =>
                                unawaited(cubit.load(background: true)),
                          )
                        : DsButton(
                            label: 'Обновить',
                            variant: DsButtonVariant.quiet,
                            icon: DsIcons.refresh,
                            onPressed: () =>
                                unawaited(cubit.load(background: true)),
                          ),
                    child: DsColumn(
                      children: [
                        if (showFilters) filterChoices,
                        if (state.pendingFilter != null && state.rowCount > 0)
                          const DsStatus(
                            title: 'Обновляем выборку',
                            message:
                                'Пока показаны операции предыдущего фильтра.',
                            kind: DsStatusKind.loading,
                          ),
                        if (state.stale)
                          const DsText('Сохранённые данные · обновляем'),
                        if (showUpdateAction && state.pendingUpdate != null)
                          DsButton(
                            label: 'Есть новые операции · показать',
                            icon: DsIcons.toTop,
                            onPressed: cubit.applyUpdate,
                          ),
                        if (state.error != null)
                          DsStatus(
                            title: state.error!,
                            kind: DsStatusKind.error,
                            action: DsButton(
                              label: 'Повторить',
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
                    ? const DsStatus(
                        title: 'Загружаем операции',
                        kind: DsStatusKind.loading,
                      )
                    : state.error == null
                    ? const DsStatus(
                        title: 'Операций пока нет',
                        message: 'Попробуйте другой период или категорию.',
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
                  !state.errors.containsKey(
                    slot.index ~/ HistoryState.pageSize,
                  )) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) unawaited(cubit.ensureIndex(slot.index));
                });
              }
              final previousDay = slot.index == 0
                  ? null
                  : state.days[slot.index - 1];
              return _HistoryRow(
                entry: entry,
                dayLabel: slot.day != null && slot.day != previousDay
                    ? slot.day!.split('-').reversed.join('.')
                    : null,
                updated: entry != null && state.updatedIds.contains(entry.id),
                hasRetry:
                    entry == null &&
                    state.errors.containsKey(
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
                          ? 'Показать ещё'
                          : 'Загружаем…',
                      onPressed: state.loadingPages.isEmpty
                          ? () => unawaited(cubit.loadNext())
                          : null,
                    )
                  : state.rowCount > 0
                  ? const DsText('Вы просмотрели все операции')
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
  Money? amount,
  EntryKind? kind,
  EntryStatus? status,
  bool updated,
  bool hasRetry,
});

/// A mounted lazy row owns just its current visual subtree. DS descendants
/// retain their own inherited palette and layout dependencies.
class _HistoryRow extends StatefulWidget {
  const _HistoryRow({
    required this.entry,
    required this.dayLabel,
    required this.updated,
    required this.hasRetry,
    required this.onEntry,
    required this.onRetry,
  });
  final LedgerEntry? entry;
  final String? dayLabel;
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
      dayLabel: widget.dayLabel,
      entryId: entry?.id,
      title: entry?.title,
      category: entry?.categoryId,
      subtitle: entry == null
          ? null
          : categoryLabels[entry.categoryId] ?? entry.subtitle,
      amount: entry?.amount,
      kind: entry?.kind,
      status: entry?.status,
      updated: widget.updated,
      hasRetry: widget.hasRetry,
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
    // Only DS constructors and row values belong here. Theme, MediaQuery and
    // responsive tokens are resolved by those descendants when they build.
    return DsConstrained(
      child: DsPadding(
        inset: DsInset.horizontal,
        child: DsColumn(
          gap: DsSpace.compact,
          children: [
            if (widget.dayLabel case final dayLabel?)
              DsText(dayLabel, style: DsTextStyle.caption, tone: DsTone.muted),
            if (entry != null)
              DsReadingAnchor(
                child: DsTransactionTile(
                  key: ValueKey(entry.id),
                  title: entry.title,
                  subtitle:
                      '${widget.updated ? 'Обновлено · ' : ''}${categoryLabels[entry.categoryId] ?? entry.subtitle} · ${entry.status == EntryStatus.posted
                          ? 'Проведено'
                          : entry.status == EntryStatus.pending
                          ? 'В обработке'
                          : 'Отменено'}',
                  value: entry.displayAmount,
                  icon: categoryIcon(entry.categoryId),
                  changed: widget.updated,
                  positive:
                      entry.kind != EntryKind.expense &&
                      entry.amount.minor >= 0,
                  onTap: _openEntry,
                ),
              )
            else if (widget.hasRetry)
              DsButton(label: 'Повторить загрузку страницы', onPressed: _retry)
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
    this.title = 'Операции',
    this.onAnalytics,
  });
  final HistoryReader reader;
  final ValueChanged<LedgerEntry> onEntry;
  final LedgerFilter? filter;
  final bool animate;
  final String title;
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
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    unawaited(_cubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DsScaffold(
    title: widget.title,
    actions: [
      if (widget.onAnalytics != null)
        DsIconButton(
          label: 'Аналитика выбранного счёта',
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
  const TransactionDetails({
    super.key,
    required this.entry,
    this.accountLabel = 'Банковский счёт',
  });
  final LedgerEntry entry;
  final String accountLabel;
  @override
  Widget build(BuildContext context) => DsPage(
    title: 'Детали операции',
    children: [
      DsCard(
        child: DsColumn(
          children: [
            DsText(entry.title, style: DsTextStyle.title),
            DsMoneyText(entry.displayAmount),
            DsText(entry.subtitle),
          ],
        ),
      ),
      DsListTile(
        title: 'Категория',
        trailing: DsText(categoryLabels[entry.categoryId] ?? entry.categoryId),
      ),
      DsListTile(
        title: 'Дата и время',
        subtitle:
            '${ReportingPeriod.date(entry.occurredAt)} · ${ReportingPeriod.time(entry.occurredAt)} · Москва',
      ),
      DsListTile(
        title: 'Статус',
        subtitle: switch (entry.status) {
          EntryStatus.posted => 'Проведено',
          EntryStatus.pending => 'В обработке',
          EntryStatus.cancelled => 'Отменено',
        },
      ),
      DsListTile(title: 'Счёт', subtitle: accountLabel),
      DsListTile(title: 'Номер операции', subtitle: entry.id),
    ],
  );
}
