import 'dart:async';

import 'package:app_localizations/app_localizations.dart';
import 'package:bank_core/bank_core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'analytics_cubit.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({
    super.key,
    required this.reader,
    required this.now,
    required this.onDrill,
    this.accounts = const [],
    this.initialFilter,
    this.refreshSignal,
  });
  final AnalyticsReader reader;
  final DateTime Function() now;
  final ValueChanged<LedgerFilter> onDrill;
  final List<Account> accounts;
  final LedgerFilter? initialFilter;
  final Listenable? refreshSignal;
  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  late final AnalyticsCubit _cubit;
  String? _selectedTime;
  String? _selectedCategory;
  @override
  void initState() {
    super.initState();
    _cubit = AnalyticsCubit(
      widget.reader,
      filter: widget.initialFilter ?? ReportingPeriod.month(widget.now()),
    );
    unawaited(_cubit.load());
    widget.refreshSignal?.addListener(_refresh);
  }

  void _refresh() => unawaited(_cubit.load());

  @override
  void didUpdateWidget(covariant AnalyticsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      oldWidget.refreshSignal?.removeListener(_refresh);
      widget.refreshSignal?.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_refresh);
    unawaited(_cubit.close());
    super.dispose();
  }

  void _period(LedgerFilter filter) {
    setState(() {
      _selectedTime = null;
      _selectedCategory = null;
    });
    unawaited(
      _cubit.load(
        filter: filter.copyWith(
          accounts: _cubit.state.filter.accounts,
          currency: _cubit.state.filter.currency,
        ),
      ),
    );
  }

  Future<void> _custom() async {
    final now = widget.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (range != null && mounted) {
      _period(ReportingPeriod.custom(range.start, range.end));
    }
  }

  void _drillCategory(DsChartPoint point) {
    setState(() => _selectedCategory = point.id);
    widget.onDrill(
      _cubit.state.filter.copyWith(
        category: point.id,
        kind: EntryKind.expense,
        revision: _cubit.state.summary?.revision,
      ),
    );
  }

  void _drillTime(DsChartPoint point) {
    final data = _cubit.state.summary!.timeline.firstWhere(
      (entry) => entry.id == point.id,
    );
    setState(() => _selectedTime = point.id);
    widget.onDrill(
      _cubit.state.filter.copyWith(
        from: data.from,
        to: data.to,
        kind: EntryKind.expense,
        revision: _cubit.state.summary?.revision,
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<AnalyticsCubit, AnalyticsState>(
    bloc: _cubit,
    builder: (context, state) {
      final l10n = context.l10n;
      final formats = context.formats;
      final summary = state.summary;
      String period(LedgerFilter filter) =>
          filter.from != null && filter.to != null
          ? formats.period(filter.from!, filter.to!)
          : l10n.analyticsAllTime;
      final currencies = {
        'RUB',
        ...widget.accounts.map((account) => account.balance.currency),
      };
      // A report has one currency, so only its accounts can be chosen.
      final reportAccounts = widget.accounts
          .where((account) => account.balance.currency == state.filter.currency)
          .toList(growable: false);
      return DsPage(
        title: l10n.analyticsTitle,
        onRefresh: () => _cubit.load(),
        children: [
          DsFilterBar(
            id: 'analytics-period',
            children: [
              DsChoice(
                label: l10n.analyticsThisMonth,
                selected:
                    state.filter.from ==
                    ReportingPeriod.month(widget.now()).from,
                onSelected: (_) => _period(ReportingPeriod.month(widget.now())),
              ),
              DsChoice(
                label: l10n.analyticsLastMonth,
                selected:
                    state.filter.from ==
                    ReportingPeriod.month(widget.now(), offset: -1).from,
                onSelected: (_) =>
                    _period(ReportingPeriod.month(widget.now(), offset: -1)),
              ),
              DsChoice(
                label: l10n.analyticsYear,
                selected:
                    state.filter.from ==
                    ReportingPeriod.year(widget.now()).from,
                onSelected: (_) => _period(ReportingPeriod.year(widget.now())),
              ),
              DsButton(
                label: l10n.analyticsChooseDates,
                icon: DsIcons.calendar,
                variant: DsButtonVariant.quiet,
                onPressed: () => unawaited(_custom()),
              ),
            ],
          ),
          DsFilterBar(
            id: 'analytics-accounts',
            children: [
              if (currencies.length > 1)
                for (final currency in currencies)
                  DsChoice(
                    label: currency,
                    selected: state.filter.currency == currency,
                    onSelected: (_) => unawaited(
                      _cubit.load(
                        filter: state.filter.copyWith(
                          currency: currency,
                          // Accounts in another currency would make the
                          // report empty; the choice starts over.
                          accounts: state.filter.accounts
                              .where(
                                (id) => widget.accounts.any(
                                  (a) =>
                                      a.id == id &&
                                      a.balance.currency == currency,
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
              DsChoice(
                label: l10n.commonAllAccounts,
                selected: state.filter.accounts.isEmpty,
                onSelected: (_) => unawaited(
                  _cubit.load(filter: state.filter.copyWith(accounts: [])),
                ),
              ),
              for (final account in reportAccounts)
                DsChoice(
                  label: account.name,
                  selected: state.filter.accounts.contains(account.id),
                  onSelected: (selected) {
                    final accounts = state.filter.accounts.toSet();
                    if (selected) {
                      accounts.add(account.id);
                    } else {
                      accounts.remove(account.id);
                    }
                    unawaited(
                      _cubit.load(
                        filter: state.filter.copyWith(
                          accounts: accounts.toList(),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          DsText(
            l10n.analyticsScope(
              period(state.filter),
              state.filter.currency,
              l10n.commonMoscowTime,
            ),
            style: DsTextStyle.caption,
          ),
          if (state.loading)
            DsStatus(
              title: summary == null
                  ? l10n.analyticsLoadingTitle
                  : l10n.analyticsUpdatingTitle,
              message: summary == null
                  ? l10n.analyticsLoadingMessage
                  : l10n.analyticsUpdatingMessage,
              kind: DsStatusKind.loading,
            ),
          if (state.pendingFilter case final requested?)
            DsText(
              l10n.analyticsRequested(
                period(requested),
                requested.accounts.isEmpty
                    ? l10n.commonAllAccounts
                    : requested.accounts
                          .map(
                            (id) =>
                                widget.accounts
                                    .where((a) => a.id == id)
                                    .firstOrNull
                                    ?.name ??
                                id,
                          )
                          .join(', '),
              ),
              style: DsTextStyle.caption,
            ),
          if (state.failed)
            DsStatus(
              title: l10n.analyticsFailed,
              kind: DsStatusKind.error,
              action: DsButton(
                label: l10n.commonRetry,
                onPressed: () => unawaited(_cubit.retry()),
              ),
            ),
          if (state.stale) DsText(l10n.analyticsStale),
          if (summary != null) ...[
            if (summary.count == 0)
              DsStatus(
                title: l10n.analyticsEmptyTitle,
                message: l10n.analyticsEmptyMessage,
                kind: DsStatusKind.empty,
              ),
            DsCard(
              child: DsMetric(
                label: l10n.analyticsTotal,
                value: formats.money(summary.total),
                change: l10n.analyticsChange(
                  formats.money(summary.total - summary.previous, signed: true),
                  switch (summary.changePercent) {
                    null => l10n.analyticsNoPercentBase,
                    final double percent => formats.percent(
                      percent,
                      signed: true,
                    ),
                  },
                ),
                detail: l10n.analyticsComparison(
                  formats.period(summary.comparisonFrom, summary.comparisonTo),
                  formats.money(summary.previous),
                ),
              ),
            ),
            if (summary.refunds.minor > 0)
              DsCard(
                tone: DsCardTone.subtle,
                child: DsMetric(
                  label: l10n.analyticsRefunds,
                  value: formats.money(summary.refunds),
                  detail: l10n.analyticsRefundsDetail,
                ),
              ),
            Builder(
              key: const ValueKey('analytics-trend'),
              builder: (context) => DsSection(
                title: l10n.analyticsTrend,
                subtitle: l10n.analyticsTrendHint,
                child: DsCard(
                  child: DsBarChart(
                    label: l10n.analyticsTrendLabel,
                    selectedId: _selectedTime,
                    points: [
                      for (final point in summary.timeline)
                        DsChartPoint(
                          id: point.id,
                          label: _timeLabel(formats, point),
                          value: point.amount.minor,
                          displayValue: formats.money(point.amount),
                        ),
                    ],
                    onSelected: state.loading ? null : _drillTime,
                    valueLabel: (value) => formats.money(
                      Money(value.toInt(), currency: summary.total.currency),
                    ),
                  ),
                ),
              ),
            ),
            Builder(
              key: const ValueKey('analytics-categories'),
              builder: (context) => DsSection(
                title: l10n.analyticsCategories,
                subtitle: l10n.analyticsCategoriesSubtitle(
                  l10n.commonOperationsCount(summary.count),
                ),
                child: DsCard(
                  child: DsRankedBars(
                    label: l10n.analyticsCategoriesLabel,
                    selectedId: _selectedCategory,
                    points: [
                      for (final point in summary.categories)
                        DsChartPoint(
                          id: point.id,
                          label: l10n.category(point.id, point.label),
                          value: point.amount.minor,
                          displayValue: formats.money(point.amount),
                          detail: l10n.analyticsShareDetail(
                            formats.percent(
                              summary.total.minor == 0
                                  ? 0
                                  : point.amount.minor *
                                        100 /
                                        summary.total.minor,
                            ),
                            l10n.commonOperationsCount(point.count),
                          ),
                          role: _categoryRole(point.id),
                        ),
                    ],
                    onSelected: state.loading ? null : _drillCategory,
                  ),
                ),
              ),
            ),
            Builder(
              key: const ValueKey('analytics-merchants'),
              builder: (context) => DsSection(
                title: l10n.analyticsMerchants,
                subtitle: l10n.analyticsMerchantsHint,
                child: DsCard(
                  child: DsColumn(
                    children: [
                      for (final point in summary.merchants)
                        DsListTile(
                          title: point.label,
                          subtitle: l10n.commonOperationsCount(point.count),
                          trailing: DsText(formats.money(point.amount)),
                          onTap: () => widget.onDrill(
                            state.filter.copyWith(
                              merchant: point.id,
                              kind: EntryKind.expense,
                              revision: summary.revision,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            DsCard(
              tone: DsCardTone.subtle,
              child: DsColumn(
                children: [
                  DsText(l10n.analyticsRuleTitle, style: DsTextStyle.title),
                  DsText(l10n.analyticsRule),
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}

DsChartRole _categoryRole(String id) => switch (id) {
  'groceries' => DsChartRole.primary,
  'transport' => DsChartRole.secondary,
  'dining' => DsChartRole.tertiary,
  'shopping' => DsChartRole.fourth,
  'utilities' => DsChartRole.fifth,
  'entertainment' => DsChartRole.seventh,
  'health' => DsChartRole.eighth,
  _ => DsChartRole.sixth,
};

/// Bucket labels follow the interface language: a day (`16.10`, `10/16`) or,
/// for monthly buckets, a month (`10.2026`, `10/2026`).
String _timeLabel(AppFormats formats, AggregatePoint point) {
  final from = point.from;
  final to = point.to;
  if (from == null) return point.label;
  return to != null && to.difference(from).inDays >= 28
      ? formats.monthYear(from)
      : formats.dayMonth(from);
}

/// One category-to-role mapping for the overview strip and detailed charts.
List<DsChartPoint> spendingChartPoints(
  BuildContext context,
  SpendingSummary summary,
) {
  final l10n = context.l10n;
  final formats = context.formats;
  return [
    for (final point in summary.categories)
      DsChartPoint(
        id: point.id,
        label: l10n.category(point.id, point.label),
        value: point.amount.minor,
        displayValue: formats.money(point.amount),
        role: _categoryRole(point.id),
      ),
  ];
}
