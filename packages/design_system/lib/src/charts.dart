import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'components.dart';
import 'layout.dart';
import 'theme.dart';
import 'tokens.dart';

/// A persistent semantic color slot, assigned by the caller's category map.
/// Labels and values always accompany color, so it is never the only key.
enum DsChartRole {
  primary,
  secondary,
  tertiary,
  fourth,
  fifth,
  sixth,
  seventh,
  eighth,
}

@immutable
class DsChartPoint {
  const DsChartPoint({
    required this.id,
    required this.label,
    required this.value,
    this.displayValue,
    this.detail,
    this.role = DsChartRole.primary,
  }) : assert(value >= 0);
  final String id;
  final String label;
  final num value;
  final String? displayValue;
  final String? detail;
  final DsChartRole role;

  String get accessibleValue => displayValue ?? '$value';
}

/// Zero-based columns with an explicit scale, exact-value selection and an
/// equivalent text view. Computes drawing ratios only, never business totals.
class DsBarChart extends StatefulWidget {
  const DsBarChart({
    super.key,
    required this.points,
    this.onSelected,
    this.selectedId,
    this.valueLabel,
    this.label = 'Динамика',
    this.updating = false,
  });
  final List<DsChartPoint> points;
  final ValueChanged<DsChartPoint>? onSelected;
  final String? selectedId;
  final String Function(num)? valueLabel;
  final String label;
  final bool updating;

  @override
  State<DsBarChart> createState() => _DsBarChartState();
}

class _DsBarChartState extends State<DsBarChart> {
  bool _textView = false;
  String? _localSelected;

  @override
  void didUpdateWidget(covariant DsBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.points.any((p) => p.id == _localSelected)) {
      _localSelected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) {
      return const DsStatus(
        title: 'За этот период данных нет',
        kind: DsStatusKind.empty,
      );
    }
    final maximum = widget.points.fold<num>(
      0,
      (max, point) => math.max(max, point.value),
    );
    final axisMax = maximum == 0 ? 1 : maximum;
    final selectedId = widget.selectedId ?? _localSelected;
    final selected = widget.points
        .where((point) => point.id == selectedId)
        .firstOrNull;
    final scaleLabel = widget.valueLabel ?? _compactNumber;
    final colors = context.dsPalette;
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    return Semantics(
      container: true,
      label: widget.label,
      child: DsColumn(
        gap: DsSpace.regular,
        children: [
          DsText(
            'Шкала: 0 — ${scaleLabel(maximum)}',
            style: DsTextStyle.caption,
            tone: DsTone.muted,
          ),
          if (widget.updating)
            const DsText(
              'Обновляем график…',
              style: DsTextStyle.caption,
              tone: DsTone.accent,
            ),
          if (!_textView)
            LayoutBuilder(
              builder: (context, constraints) {
                final minBarWidth = DsTokens.touchTarget * textScale;
                final width = math.max(
                  constraints.maxWidth,
                  minBarWidth * widget.points.length,
                );
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: width,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          height: DsTokens.chartHeight,
                          child: ExcludeSemantics(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                for (
                                  var i = 0;
                                  i <= DsTokens.chartGridCount;
                                  i++
                                )
                                  Container(
                                    height: DsTokens.borderWidth,
                                    color: colors.border,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final point in widget.points)
                              Expanded(
                                child: Semantics(
                                  label:
                                      '${point.label}, ${point.accessibleValue}${point.detail == null ? '' : ', ${point.detail}'}',
                                  selected: point.id == selectedId,
                                  button: true,
                                  excludeSemantics: true,
                                  child: InkWell(
                                    onTap: () => _select(point),
                                    borderRadius: BorderRadius.circular(
                                      DsTokens.controlRadius,
                                    ),
                                    child: Tooltip(
                                      message:
                                          '${point.label}: ${point.accessibleValue}',
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: DsTokens.unit,
                                        ),
                                        child: Column(
                                          children: [
                                            SizedBox(
                                              height: DsTokens.chartHeight,
                                              child: Align(
                                                alignment:
                                                    Alignment.bottomCenter,
                                                child: AnimatedContainer(
                                                  duration: DsTokens.duration(
                                                    context,
                                                    DsTokens.standard,
                                                  ),
                                                  curve: DsTokens.movement,
                                                  height:
                                                      point.value.toDouble() /
                                                      axisMax *
                                                      DsTokens.chartHeight,
                                                  width: DsTokens.chartBarWidth,
                                                  decoration: BoxDecoration(
                                                    color:
                                                        point.id == selectedId
                                                        ? colors.accent
                                                        : dsChartColor(
                                                            context,
                                                            point.role,
                                                          ).withValues(
                                                            alpha:
                                                                selectedId ==
                                                                    null
                                                                ? .85
                                                                : DsTokens
                                                                      .chartIdleOpacity,
                                                          ),
                                                    borderRadius:
                                                        const BorderRadius.vertical(
                                                          top: Radius.circular(
                                                            DsTokens.unit * 2,
                                                          ),
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const DsGap(space: DsSpace.compact),
                                            DsText(
                                              point.label,
                                              style: DsTextStyle.caption,
                                              align: TextAlign.center,
                                              maxLines: 2,
                                            ),
                                            if (point.value == 0)
                                              const DsText(
                                                '0',
                                                style: DsTextStyle.caption,
                                                tone: DsTone.muted,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          if (selected != null && !_textView)
            DsNotice(
              message:
                  '${selected.label}: ${selected.accessibleValue}${selected.detail == null ? '' : ' · ${selected.detail}'}',
              tone: DsTone.primary,
            ),
          DsButton(
            label: _textView ? 'Показать график' : 'Все значения списком',
            variant: DsButtonVariant.quiet,
            icon: _textView
                ? Icons.bar_chart_rounded
                : Icons.format_list_bulleted_rounded,
            onPressed: () => setState(() => _textView = !_textView),
          ),
          if (_textView)
            DsColumn(
              gap: DsSpace.none,
              children: [
                for (final point in widget.points)
                  DsListTile(
                    title: point.label,
                    subtitle: point.detail,
                    selected: point.id == selectedId,
                    trailing: DsText(
                      point.accessibleValue,
                      style: DsTextStyle.label,
                    ),
                    onTap: () => _select(point),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  void _select(DsChartPoint point) {
    setState(() => _localSelected = point.id);
    widget.onSelected?.call(point);
  }
}

class DsRankedBars extends StatelessWidget {
  const DsRankedBars({
    super.key,
    required this.points,
    this.onSelected,
    this.selectedId,
    this.label = 'Распределение',
  });
  final List<DsChartPoint> points;
  final ValueChanged<DsChartPoint>? onSelected;
  final String? selectedId;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const DsStatus(
        title: 'Категорий пока нет',
        kind: DsStatusKind.empty,
      );
    }
    final maximum = points.fold<num>(
      0,
      (max, point) => math.max(max, point.value),
    );
    return Semantics(
      container: true,
      label: label,
      child: DsColumn(
        gap: DsSpace.regular,
        children: [
          for (var index = 0; index < points.length; index++)
            _RankedRow(
              point: points[index],
              rank: index + 1,
              maximum: maximum,
              selected: selectedId == points[index].id,
              onTap: onSelected == null
                  ? null
                  : () => onSelected!(points[index]),
            ),
        ],
      ),
    );
  }
}

class _RankedRow extends StatelessWidget {
  const _RankedRow({
    required this.point,
    required this.rank,
    required this.maximum,
    required this.selected,
    this.onTap,
  });
  final DsChartPoint point;
  final int rank;
  final num maximum;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: onTap != null,
    label:
        '$rank. ${point.label}: ${point.accessibleValue}${point.detail == null ? '' : ', ${point.detail}'}',
    excludeSemantics: true,
    child: Material(
      color: selected
          ? context.dsPalette.accent.withValues(alpha: .06)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(DsTokens.controlRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DsTokens.controlRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: DsTokens.compactInset,
            horizontal: DsTokens.unit * 2,
          ),
          child: DsColumn(
            gap: DsSpace.compact,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final textScale = MediaQuery.textScalerOf(context).scale(1);
                  return textScale > 1.4 ||
                          constraints.maxWidth < DsTokens.narrowBreakpoint
                      ? DsColumn(
                          gap: DsSpace.tight,
                          children: [
                            DsText(
                              '$rank. ${point.label}',
                              style: DsTextStyle.label,
                            ),
                            DsText(
                              '${point.accessibleValue}${point.detail == null ? '' : ' · ${point.detail}'}',
                              style: DsTextStyle.caption,
                              tone: DsTone.muted,
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: DsText(
                                '$rank. ${point.label}',
                                style: DsTextStyle.label,
                              ),
                            ),
                            const DsGap(space: DsSpace.compact),
                            DsText(
                              point.accessibleValue,
                              style: DsTextStyle.label,
                            ),
                            if (point.detail != null) ...[
                              const DsGap(space: DsSpace.compact),
                              DsText(
                                point.detail!,
                                style: DsTextStyle.caption,
                                tone: DsTone.muted,
                              ),
                            ],
                          ],
                        );
                },
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(DsTokens.pillRadius),
                child: SizedBox(
                  height: DsTokens.rankedBarHeight,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ColoredBox(color: context.dsPalette.raised),
                      ),
                      FractionallySizedBox(
                        widthFactor: maximum == 0
                            ? 0
                            : point.value.toDouble() / maximum,
                        heightFactor: 1,
                        child: ColoredBox(
                          color: dsChartColor(context, point.role),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Color dsChartColor(BuildContext context, DsChartRole role) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (role) {
    DsChartRole.primary => context.dsPalette.accent,
    DsChartRole.secondary =>
      dark ? const Color(0xFF83D3C3) : const Color(0xFF27A87A),
    DsChartRole.tertiary =>
      dark ? const Color(0xFFF1C481) : const Color(0xFFFFA440),
    DsChartRole.fourth =>
      dark ? const Color(0xFFF2A4C0) : const Color(0xFFE66FA0),
    DsChartRole.fifth =>
      dark ? const Color(0xFF99B6F5) : const Color(0xFF5F8FF5),
    DsChartRole.sixth => context.dsPalette.muted,
    DsChartRole.seventh =>
      dark ? const Color(0xFFB9A1FF) : const Color(0xFF9B75ED),
    DsChartRole.eighth =>
      dark ? const Color(0xFF76D8E8) : const Color(0xFF29B6CB),
  };
}

String _compactNumber(num value) {
  if (value.abs() >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)} млн';
  }
  if (value.abs() >= 1000) return '${(value / 1000).toStringAsFixed(1)} тыс.';
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
}
