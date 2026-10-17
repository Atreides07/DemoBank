import 'dart:async';
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
      final summary = state.summary;
      final currencies = {
        'RUB',
        ...widget.accounts.map((account) => account.balance.currency),
      };
      return DsPage(
        title: 'Аналитика трат',
        onRefresh: () => _cubit.load(),
        children: [
          DsFilterBar(
            id: 'analytics-period',
            children: [
              DsChoice(
                label: 'Этот месяц',
                selected:
                    state.filter.from ==
                    ReportingPeriod.month(widget.now()).from,
                onSelected: (_) => _period(ReportingPeriod.month(widget.now())),
              ),
              DsChoice(
                label: 'Прошлый месяц',
                selected:
                    state.filter.from ==
                    ReportingPeriod.month(widget.now(), offset: -1).from,
                onSelected: (_) =>
                    _period(ReportingPeriod.month(widget.now(), offset: -1)),
              ),
              DsChoice(
                label: 'Год',
                selected:
                    state.filter.from ==
                    ReportingPeriod.year(widget.now()).from,
                onSelected: (_) => _period(ReportingPeriod.year(widget.now())),
              ),
              DsButton(
                label: 'Выбрать даты',
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
                        filter: state.filter.copyWith(currency: currency),
                      ),
                    ),
                  ),
              DsChoice(
                label: 'Все счета',
                selected: state.filter.accounts.isEmpty,
                onSelected: (_) => unawaited(
                  _cubit.load(filter: state.filter.copyWith(accounts: [])),
                ),
              ),
              for (final account in widget.accounts)
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
            '${ReportingPeriod.label(state.filter)} · ${state.filter.currency} · Москва',
            style: DsTextStyle.caption,
          ),
          if (state.loading)
            DsStatus(
              title: summary == null
                  ? 'Собираем аналитику'
                  : 'Обновляем выбранный период',
              message: summary == null
                  ? 'Графики появятся по мере получения данных.'
                  : 'Сейчас показан предыдущий согласованный результат.',
              kind: DsStatusKind.loading,
            ),
          if (state.pendingFilter case final requested?)
            DsText(
              'Запрошено: ${ReportingPeriod.label(requested)} · ${requested.accounts.isEmpty ? 'все счета' : requested.accounts.map((id) => widget.accounts.where((a) => a.id == id).firstOrNull?.name ?? id).join(', ')}',
              style: DsTextStyle.caption,
            ),
          if (state.error != null)
            DsStatus(
              title: state.error!,
              kind: DsStatusKind.error,
              action: DsButton(
                label: 'Повторить',
                onPressed: () => unawaited(_cubit.load()),
              ),
            ),
          if (state.stale)
            const DsText('Сохранённые данные · актуальность проверяется'),
          if (summary != null) ...[
            if (summary.count == 0)
              const DsStatus(
                title: 'Нет расходов в этом периоде',
                message:
                    'Проведённых списаний по выбранным фильтрам не найдено.',
                kind: DsStatusKind.empty,
              ),
            DsCard(
              child: DsMetric(
                label: 'Расходы за период',
                value: summary.total.format(),
                change:
                    '${(summary.total - summary.previous).format(signed: true)} · ${summary.changePercent == null ? 'нет базы для процента' : '${summary.changePercent! >= 0 ? '+' : ''}${summary.changePercent!.toStringAsFixed(1)}%'}',
                detail:
                    'Сравнение: ${ReportingPeriod.date(summary.comparisonFrom)} — ${ReportingPeriod.date(summary.comparisonTo.subtract(const Duration(days: 1)))} · ${summary.previous.format()}',
              ),
            ),
            if (summary.refunds.minor > 0)
              DsCard(
                tone: DsCardTone.subtle,
                child: DsMetric(
                  label: 'Возвраты отдельно',
                  value: summary.refunds.format(),
                  detail: 'Не включены в показатель расходов',
                ),
              ),
            DsSection(
              title: 'Динамика расходов',
              subtitle: 'Нажмите на столбец, чтобы увидеть операции',
              child: DsCard(
                child: DsBarChart(
                  label: 'Расходы по времени',
                  selectedId: _selectedTime,
                  points: [
                    for (final point in summary.timeline)
                      DsChartPoint(
                        id: point.id,
                        label: point.label,
                        value: point.amount.minor,
                        displayValue: point.amount.format(),
                      ),
                  ],
                  onSelected: state.loading ? null : _drillTime,
                  valueLabel: (value) => Money(
                    value.toInt(),
                    currency: summary.total.currency,
                  ).format(),
                ),
              ),
            ),
            DsSection(
              title: 'На что потрачено',
              subtitle: 'Полная выборка · ${summary.count} операций',
              child: DsCard(
                child: DsRankedBars(
                  label: 'Категории расходов',
                  selectedId: _selectedCategory,
                  points: [
                    for (final point in summary.categories)
                      DsChartPoint(
                        id: point.id,
                        label: point.label,
                        value: point.amount.minor,
                        displayValue: point.amount.format(),
                        detail: summary.total.minor == 0
                            ? '0%'
                            : '${(point.amount.minor * 100 / summary.total.minor).toStringAsFixed(1)}% · ${point.count} операций',
                        role: _categoryRole(point.id),
                      ),
                  ],
                  onSelected: state.loading ? null : _drillCategory,
                ),
              ),
            ),
            DsSection(
              title: 'Получатели',
              subtitle: 'Откройте детализацию по торговой точке',
              child: DsCard(
                child: DsColumn(
                  children: [
                    for (final point in summary.merchants)
                      DsListTile(
                        title: point.label,
                        subtitle: '${point.count} операций',
                        trailing: DsText(point.amount.format()),
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
            const DsCard(
              tone: DsCardTone.subtle,
              child: DsColumn(
                children: [
                  DsText('Как считаем расходы', style: DsTextStyle.title),
                  DsText(
                    'Только проведённые списания. Доходы, переводы между своими счетами, отмены и ожидающие операции исключены. Возвраты показываются отдельно. Комиссия учитывается один раз. Дни определяются по московскому времени.',
                  ),
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

/// One category-to-role mapping for the overview strip and detailed charts.
List<DsChartPoint> spendingChartPoints(SpendingSummary summary) => [
  for (final point in summary.categories)
    DsChartPoint(
      id: point.id,
      label: point.label,
      value: point.amount.minor,
      displayValue: point.amount.format(),
      role: _categoryRole(point.id),
    ),
];
