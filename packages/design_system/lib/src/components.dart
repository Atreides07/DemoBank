import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'amount.dart';
import 'layout.dart';
import 'theme.dart';
import 'tokens.dart';

class DsText extends StatelessWidget {
  const DsText(
    this.text, {
    super.key,
    this.style = DsTextStyle.body,
    this.tone = DsTone.primary,
    this.maxLines,
    this.align,
  });
  final String text;
  final DsTextStyle style;
  final DsTone tone;
  final int? maxLines;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final textStyle = switch (style) {
      DsTextStyle.caption => theme.bodySmall,
      DsTextStyle.label => theme.labelLarge,
      DsTextStyle.body => theme.bodyLarge,
      DsTextStyle.title => theme.titleLarge,
      DsTextStyle.headline => theme.headlineLarge,
      DsTextStyle.display => theme.displayLarge,
    };
    final color = _textColor(context, tone);
    Widget render(TextStyle? resolved) => Text(
      text,
      textAlign: align,
      maxLines: maxLines,
      overflow: maxLines == null ? TextOverflow.visible : TextOverflow.ellipsis,
      style: resolved?.copyWith(color: color),
    );
    if (style == DsTextStyle.headline || style == DsTextStyle.display) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final compact = DsTokens.compactTypography(context, constraints);
          final adaptive = compact
              ? (style == DsTextStyle.display
                    ? theme.headlineLarge
                    : theme.headlineMedium)
              : textStyle;
          return render(adaptive);
        },
      );
    }
    return render(textStyle);
  }
}

class DsMoneyText extends StatelessWidget {
  const DsMoneyText(
    this.text, {
    super.key,
    this.prominent = true,
    this.tone = DsTone.primary,
  });
  final String text;
  final bool prominent;
  final DsTone tone;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final typography = Theme.of(context).textTheme;
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final style = !prominent
          ? typography.titleMedium
          : scale > 1.3
          ? typography.headlineMedium
          : constraints.maxWidth < DsTokens.narrowBreakpoint
          ? typography.headlineLarge
          : typography.displayLarge;
      return DsAmountLayout(
        text: text,
        style: style?.copyWith(
          color: _textColor(context, tone),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
    },
  );
}

class DsCard extends StatelessWidget {
  const DsCard({
    super.key,
    required this.child,
    this.onTap,
    this.tone = DsCardTone.surface,
    this.density = DsDensity.comfortable,
  });
  final Widget child;
  final VoidCallback? onTap;
  final DsCardTone tone;
  final DsDensity density;

  @override
  Widget build(BuildContext context) {
    final palette = context.dsPalette;
    final color = switch (tone) {
      DsCardTone.surface => palette.surface,
      DsCardTone.dark => palette.navy,
      DsCardTone.accent => palette.accent,
      DsCardTone.subtle => palette.raised,
    };
    final foreground = switch (tone) {
      DsCardTone.dark => palette.onNavy,
      DsCardTone.accent => palette.onAccent,
      _ => palette.ink,
    };
    final radius = BorderRadius.circular(DsTokens.cardRadius);
    return Material(
      color: color,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: DsPadding(
          inset: density == DsDensity.compact ? DsInset.compact : DsInset.card,
          child: DefaultTextStyle.merge(
            style: TextStyle(color: foreground),
            child: _DsSurface(
              foreground: foreground,
              contrasting: tone == DsCardTone.dark || tone == DsCardTone.accent,
              muted: tone == DsCardTone.dark || tone == DsCardTone.accent
                  ? foreground.withValues(alpha: .82)
                  : palette.muted,
              child: IconTheme.merge(
                data: IconThemeData(color: foreground),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small account overview for paired cards. Full amounts and account names
/// wrap naturally; large text switches the containing action grid to one column.
class DsAccountCard extends StatelessWidget {
  const DsAccountCard({
    super.key,
    required this.title,
    required this.balance,
    required this.number,
  });
  final String title;
  final String balance;
  final String number;

  @override
  Widget build(BuildContext context) => DsCard(
    density: DsDensity.compact,
    child: DsColumn(
      gap: DsSpace.tight,
      children: [
        DsText(title, style: DsTextStyle.caption, tone: DsTone.muted),
        DsMoneyText(balance, prominent: false),
        DsText(number, style: DsTextStyle.caption, tone: DsTone.muted),
      ],
    ),
  );
}

/// An account keeps its name above its balance instead of squeezing two long
/// financial strings into competing half-width columns.
class DsAccountRow extends StatelessWidget {
  const DsAccountRow({
    super.key,
    required this.title,
    required this.balance,
    required this.number,
  });
  final String title;
  final String balance;
  final String number;

  @override
  Widget build(BuildContext context) {
    final large =
        MediaQuery.textScalerOf(context).scale(1) > DsTokens.largeTextThreshold;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsTokens.unit * 2),
      child: Row(
        children: [
          if (!large) ...[
            const DsIconBadge(icon: DsIcons.card),
            const SizedBox(width: DsTokens.compactInset),
          ],
          Expanded(
            child: DsColumn(
              gap: DsSpace.tight,
              children: [
                DsText(title, style: DsTextStyle.label),
                if (large) ...[
                  DsMoneyText(balance, prominent: false),
                  DsText(
                    number,
                    style: DsTextStyle.caption,
                    tone: DsTone.muted,
                  ),
                ] else
                  DsRow(
                    children: [
                      Expanded(child: DsMoneyText(balance, prominent: false)),
                      DsText(
                        number,
                        style: DsTextStyle.caption,
                        tone: DsTone.muted,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact, single-action service card. The entire surface is actionable;
/// it does not repeat a second full-width "open" button within the card.
class DsServiceCard extends StatelessWidget {
  const DsServiceCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.tone = DsTone.accent,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final DsTone tone;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: DsCard(
      onTap: onTap,
      child: DsColumn(
        gap: DsSpace.compact,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: DsIconBadge(icon: icon, tone: tone),
          ),
          DsText(title, style: DsTextStyle.label),
          DsText(subtitle, style: DsTextStyle.caption, tone: DsTone.muted),
        ],
      ),
    ),
  );
}

class _DsSurface extends InheritedWidget {
  const _DsSurface({
    required this.foreground,
    required this.muted,
    this.contrasting = false,
    required super.child,
  });
  final Color foreground;
  final Color muted;
  final bool contrasting;

  @override
  bool updateShouldNotify(covariant _DsSurface oldWidget) =>
      foreground != oldWidget.foreground ||
      muted != oldWidget.muted ||
      contrasting != oldWidget.contrasting;
}

/// A contrast scope without padding, for content on the balance/header surface.
class DsContrastSurface extends StatelessWidget {
  const DsContrastSurface({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => _DsSurface(
    foreground: context.dsPalette.onNavy,
    muted: context.dsPalette.onNavy.withValues(alpha: .82),
    contrasting: true,
    child: child,
  );
}

Color _textColor(BuildContext context, DsTone tone) {
  final surface = context.dependOnInheritedWidgetOfExactType<_DsSurface>();
  return switch (tone) {
    DsTone.primary => surface?.foreground ?? context.dsPalette.ink,
    DsTone.muted => surface?.muted ?? context.dsPalette.muted,
    DsTone.inverse => surface?.foreground ?? context.dsPalette.onNavy,
    _ => context.dsPalette.tone(tone),
  };
}

class DsButton extends StatelessWidget {
  const DsButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.variant = DsButtonVariant.primary,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final DsButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final callback = loading ? null : onPressed;
    final surface = context.dependOnInheritedWidgetOfExactType<_DsSurface>();
    final contrasting = surface?.contrasting ?? false;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          const SizedBox.square(
            dimension: DsTokens.smallIconSize,
            child: CircularProgressIndicator(
              strokeWidth: DsTokens.progressStroke,
            ),
          ),
          const SizedBox(width: DsTokens.compactInset),
        ] else if (icon != null) ...[
          Icon(icon, size: DsTokens.smallIconSize),
          const SizedBox(width: DsTokens.compactInset),
        ],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
    return Semantics(
      button: true,
      enabled: callback != null,
      liveRegion: loading,
      child: switch (variant) {
        DsButtonVariant.primary => FilledButton(
          onPressed: callback,
          style: contrasting
              ? FilledButton.styleFrom(
                  backgroundColor: context.dsPalette.highlight,
                  foregroundColor: context.dsPalette.navy,
                )
              : null,
          child: content,
        ),
        DsButtonVariant.secondary => OutlinedButton(
          onPressed: callback,
          style: contrasting
              ? OutlinedButton.styleFrom(
                  foregroundColor: surface!.foreground,
                  side: BorderSide(
                    color: surface.foreground.withValues(alpha: .55),
                  ),
                )
              : null,
          child: content,
        ),
        DsButtonVariant.quiet => TextButton(
          onPressed: callback,
          style: contrasting
              ? TextButton.styleFrom(foregroundColor: surface!.foreground)
              : null,
          child: content,
        ),
        DsButtonVariant.danger => FilledButton(
          onPressed: callback,
          style: FilledButton.styleFrom(
            backgroundColor: context.dsPalette.danger,
            foregroundColor: context.dsPalette.surface,
          ),
          child: content,
        ),
      },
    );
  }
}

class DsIconButton extends StatelessWidget {
  const DsIconButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    tooltip: label,
    icon: Icon(icon),
    constraints: const BoxConstraints(
      minWidth: DsTokens.touchTarget,
      minHeight: DsTokens.touchTarget,
    ),
  );
}

class DsField extends StatelessWidget {
  const DsField({
    super.key,
    required this.label,
    this.controller,
    this.onChanged,
    this.error,
    this.hint,
    this.keyboardType,
    this.enabled = true,
    this.obscureText = false,
    this.inputFormatters,
    this.onSubmitted,
    this.autofillHints,
  });
  final String label;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String? error;
  final String? hint;
  final TextInputType? keyboardType;
  final bool enabled;
  final bool obscureText;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
    keyboardType: keyboardType,
    enabled: enabled,
    obscureText: obscureText,
    inputFormatters: inputFormatters,
    autofillHints: autofillHints,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: error,
    ),
  );
}

class DsChoice extends StatelessWidget {
  const DsChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
  });
  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.dsPalette;
    final leading = selected ? DsIcons.check : icon;
    return Semantics(
      selected: selected,
      button: true,
      enabled: onSelected != null,
      child: TextButton(
        onPressed: onSelected == null ? null : () => onSelected!(!selected),
        style:
            TextButton.styleFrom(
              foregroundColor: selected ? palette.onAccent : palette.ink,
              disabledForegroundColor: palette.muted.withValues(
                alpha: DsTokens.disabledOpacity,
              ),
              backgroundColor: selected ? palette.accent : palette.surface,
              disabledBackgroundColor: palette.raised,
              minimumSize: const Size(
                DsTokens.touchTarget,
                DsTokens.touchTarget,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: DsTokens.compactInset,
                vertical: DsTokens.unit * 2,
              ),
              side: BorderSide(
                color: selected ? palette.accent : Colors.transparent,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DsTokens.pillRadius),
              ),
              textStyle: Theme.of(context).textTheme.labelLarge,
            ).copyWith(
              animationDuration: DsTokens.duration(context, DsTokens.quick),
            ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              Icon(leading, size: DsTokens.smallIconSize),
              const SizedBox(width: DsTokens.unit * 2),
            ],
            Flexible(child: Text(label, softWrap: true)),
          ],
        ),
      ),
    );
  }
}

class DsCheckbox extends StatelessWidget {
  const DsCheckbox({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => CheckboxListTile(
    title: Text(label),
    subtitle: subtitle == null ? null : Text(subtitle!),
    value: value,
    onChanged: onChanged == null ? null : (value) => onChanged!(value ?? false),
    contentPadding: EdgeInsets.zero,
    controlAffinity: ListTileControlAffinity.leading,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(DsTokens.controlRadius),
    ),
  );
}

class DsListTile extends StatelessWidget {
  const DsListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.icon,
    this.onTap,
    this.selected = false,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => Material(
    color: selected
        ? context.dsPalette.accent.withValues(alpha: .1)
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wideText = MediaQuery.textScalerOf(context).scale(1) > 1.5;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (icon != null && !wideText) ...[
                  DsIconBadge(icon: icon!),
                  const SizedBox(width: DsTokens.compactInset),
                ],
                Expanded(
                  child: DsColumn(
                    gap: DsSpace.tight,
                    children: [
                      DsText(title, style: DsTextStyle.label),
                      if (subtitle != null)
                        DsText(
                          subtitle!,
                          style: DsTextStyle.caption,
                          tone: DsTone.muted,
                        ),
                      if (wideText && trailing != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: trailing!,
                        ),
                    ],
                  ),
                ),
                if (!wideText && trailing != null) ...[
                  const SizedBox(width: DsTokens.compactInset),
                  Flexible(child: trailing!),
                ] else if (onTap != null)
                  const Icon(DsTokens.chevron),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class DsIconBadge extends StatelessWidget {
  const DsIconBadge({super.key, required this.icon, this.tone = DsTone.accent});
  final IconData icon;
  final DsTone tone;

  @override
  Widget build(BuildContext context) => Container(
    width: DsTokens.tileLeading,
    height: DsTokens.tileLeading,
    decoration: BoxDecoration(
      color: context.dsPalette.tone(tone).withValues(alpha: .1),
      borderRadius: BorderRadius.circular(DsTokens.controlRadius),
    ),
    child: Icon(icon, color: context.dsPalette.tone(tone)),
  );
}

/// Slot extent is stable for cache eviction and scales with text accessibility.
/// Full titles remain available to screen readers and the detail action.
class DsTransactionTile extends StatelessWidget {
  const DsTransactionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    this.onTap,
    this.trailing,
    this.positive = false,
    this.changed = false,
  });
  final String title;
  final String subtitle;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool positive;
  final bool changed;

  @override
  Widget build(BuildContext context) {
    final palette = context.dsPalette;
    final largeText =
        MediaQuery.textScalerOf(context).scale(1) > DsTokens.largeTextThreshold;
    return Semantics(
      label: '$title, $subtitle, $value${changed ? ', обновлено' : ''}',
      button: onTap != null,
      excludeSemantics: true,
      child: SizedBox(
        height: DsTokens.transactionExtent(context),
        child: Material(
          color: changed
              ? palette.accent.withValues(alpha: .07)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(DsTokens.controlRadius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(DsTokens.controlRadius),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: DsTokens.unit * 2),
              child: Row(
                children: [
                  if (!largeText) ...[
                    DsIconBadge(
                      icon: icon,
                      tone: positive ? DsTone.success : DsTone.accent,
                    ),
                    const SizedBox(width: DsTokens.compactInset),
                  ],
                  Expanded(
                    flex: largeText ? 1 : 3,
                    child: DsColumn(
                      gap: DsSpace.tight,
                      children: [
                        DsText(
                          title,
                          style: DsTextStyle.label,
                          maxLines: largeText ? 2 : 1,
                        ),
                        DsText(
                          subtitle,
                          tone: DsTone.muted,
                          style: DsTextStyle.caption,
                          maxLines: 1,
                        ),
                        if (largeText)
                          DsMoneyText(
                            value,
                            prominent: false,
                            tone: positive ? DsTone.success : DsTone.primary,
                          ),
                      ],
                    ),
                  ),
                  if (!largeText) ...[
                    const SizedBox(width: DsTokens.compactInset),
                    Flexible(
                      flex: 2,
                      child: DsColumn(
                        gap: DsSpace.tight,
                        alignment: CrossAxisAlignment.end,
                        children: [
                          DsMoneyText(
                            value,
                            prominent: false,
                            tone: positive ? DsTone.success : DsTone.primary,
                          ),
                          if (trailing != null) trailing!,
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DsTransactionPlaceholder extends StatelessWidget {
  const DsTransactionPlaceholder({super.key, this.label = 'Загрузка операции'});
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: SizedBox(
      height: DsTokens.transactionExtent(context),
      child: const Center(child: DsSkeleton()),
    ),
  );
}

class DsSkeleton extends StatelessWidget {
  const DsSkeleton({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: DsColumn(
      gap: DsSpace.compact,
      children: [
        _skeletonLine(context, 1),
        FractionallySizedBox(
          widthFactor: .64,
          alignment: Alignment.centerLeft,
          child: _skeletonLine(context, .5),
        ),
      ],
    ),
  );

  Widget _skeletonLine(BuildContext context, double opacity) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.dsPalette.border.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(DsTokens.controlRadius),
    ),
    child: const SizedBox(
      height: DsTokens.skeletonHeight,
      width: double.infinity,
    ),
  );
}

class DsLoading extends StatelessWidget {
  const DsLoading({super.key, this.label = 'Загрузка данных'});
  final String label;

  @override
  Widget build(BuildContext context) =>
      DsStatus(title: label, kind: DsStatusKind.loading);
}

class DsStatus extends StatelessWidget {
  const DsStatus({
    super.key,
    required this.title,
    this.message,
    this.kind = DsStatusKind.info,
    this.action,
  });
  final String title;
  final String? message;
  final DsStatusKind kind;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final icon = switch (kind) {
      DsStatusKind.empty => DsTokens.empty,
      DsStatusKind.error => DsTokens.error,
      DsStatusKind.success => DsTokens.success,
      _ => DsTokens.info,
    };
    final tone = switch (kind) {
      DsStatusKind.error => DsTone.danger,
      DsStatusKind.success => DsTone.success,
      _ => DsTone.accent,
    };
    return Semantics(
      liveRegion: kind != DsStatusKind.empty,
      child: DsCard(
        child: DsColumn(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: kind == DsStatusKind.loading
                  ? const RepaintBoundary(
                      child: SizedBox.square(
                        dimension: DsTokens.largeIconSize,
                        child: CircularProgressIndicator(
                          strokeWidth: DsTokens.progressStroke,
                        ),
                      ),
                    )
                  : DsIconBadge(icon: icon, tone: tone),
            ),
            DsText(title, style: DsTextStyle.title),
            if (message != null) DsText(message!, tone: DsTone.muted),
            if (action != null) action!,
          ],
        ),
      ),
    );
  }
}

class DsNotice extends StatelessWidget {
  const DsNotice({
    super.key,
    required this.message,
    this.tone = DsTone.muted,
    this.action,
  });
  final String message;
  final DsTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) => DsCard(
    tone: DsCardTone.subtle,
    child: DsColumn(
      gap: DsSpace.compact,
      children: [
        DsText(message, tone: tone, style: DsTextStyle.caption),
        if (action != null)
          Align(alignment: Alignment.centerLeft, child: action!),
      ],
    ),
  );
}

class DsDivider extends StatelessWidget {
  const DsDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      const Divider(height: DsTokens.unit * 4);
}

@immutable
class DsDetail {
  const DsDetail(this.label, this.value);
  final String label;
  final String value;
}

class DsDetailList extends StatelessWidget {
  const DsDetailList({super.key, required this.details});
  final List<DsDetail> details;

  @override
  Widget build(BuildContext context) => DsColumn(
    children: [
      for (final detail in details)
        DsColumn(
          gap: DsSpace.tight,
          children: [
            DsText(
              detail.label,
              style: DsTextStyle.caption,
              tone: DsTone.muted,
            ),
            SelectableText(
              detail.value,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
    ],
  );
}

class DsPaymentSummary extends StatelessWidget {
  const DsPaymentSummary({
    super.key,
    required this.title,
    required this.amount,
    required this.details,
    this.notice,
  });
  final String title;
  final String amount;
  final List<DsDetail> details;
  final String? notice;

  @override
  Widget build(BuildContext context) => DsCard(
    child: DsColumn(
      gap: DsSpace.section,
      children: [
        DsColumn(
          gap: DsSpace.compact,
          children: [
            DsText(title, style: DsTextStyle.label, tone: DsTone.muted),
            DsMoneyText(amount),
          ],
        ),
        DsDetailList(details: details),
        if (notice != null)
          DsText(notice!, style: DsTextStyle.caption, tone: DsTone.muted),
      ],
    ),
  );
}

class DsMetric extends StatelessWidget {
  const DsMetric({
    super.key,
    required this.label,
    required this.value,
    this.change,
    this.detail,
    this.tone = DsTone.primary,
  });
  final String label;
  final String value;
  final String? change;
  final String? detail;
  final DsTone tone;

  @override
  Widget build(BuildContext context) => DsColumn(
    gap: DsSpace.compact,
    children: [
      DsText(label, style: DsTextStyle.label, tone: DsTone.muted),
      DsMoneyText(value, tone: tone),
      if (change != null)
        DsText(change!, style: DsTextStyle.label, tone: DsTone.accent),
      if (detail != null)
        DsText(detail!, style: DsTextStyle.caption, tone: DsTone.muted),
    ],
  );
}

@immutable
class DsDestination {
  const DsDestination({
    required this.label,
    required this.icon,
    this.selectedIcon,
  });
  final String label;
  final IconData icon;
  final IconData? selectedIcon;
}

class DsNavigationBar extends StatelessWidget {
  const DsNavigationBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });
  final List<DsDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.textScalerOf(context).scale(1) > 1.4) {
      return Material(
        color: context.dsPalette.surface,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(DsTokens.unit * 2),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = destinations.length > 2
                    ? 2
                    : destinations.length;
                final gap = DsTokens.space(DsSpace.compact);
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (var index = 0; index < destinations.length; index++)
                      SizedBox(
                        width: width,
                        child: Semantics(
                          selected: index == selectedIndex,
                          button: true,
                          child: Material(
                            color: index == selectedIndex
                                ? context.dsPalette.accent.withValues(alpha: .1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(
                              DsTokens.controlRadius,
                            ),
                            child: InkWell(
                              onTap: () => onSelected(index),
                              borderRadius: BorderRadius.circular(
                                DsTokens.controlRadius,
                              ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: DsTokens.touchTarget,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(
                                    DsTokens.unit * 2,
                                  ),
                                  child: DsColumn(
                                    gap: DsSpace.compact,
                                    alignment: CrossAxisAlignment.center,
                                    children: [
                                      Icon(
                                        destinations[index].icon,
                                        color: index == selectedIndex
                                            ? context.dsPalette.ink
                                            : context.dsPalette.muted,
                                      ),
                                      DsText(
                                        destinations[index].label,
                                        style: DsTextStyle.caption,
                                        align: TextAlign.center,
                                        tone: index == selectedIndex
                                            ? DsTone.primary
                                            : DsTone.muted,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    }
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      destinations: [
        for (final item in destinations)
          NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon ?? item.icon),
            label: item.label,
          ),
      ],
    );
  }
}

class DsTabBar extends StatelessWidget {
  const DsTabBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => DsFlow(
    children: [
      for (var i = 0; i < labels.length; i++)
        DsChoice(
          label: labels[i],
          selected: i == selectedIndex,
          onSelected: (_) => onSelected(i),
        ),
    ],
  );
}

class DsSeatPicker extends StatelessWidget {
  const DsSeatPicker({
    super.key,
    required this.seats,
    required this.onSelected,
  });
  final List<DsSeat> seats;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => DsColumn(
    children: [
      const DsNotice(message: 'Экран • выберите свободные места'),
      DsFlow(
        children: [
          for (final seat in seats)
            Semantics(
              label:
                  'Место ${seat.label}, ${seat.available ? (seat.selected ? 'выбрано' : 'свободно') : 'занято'}',
              selected: seat.selected,
              child: ChoiceChip(
                label: Text(seat.label),
                selected: seat.selected,
                onSelected: seat.available ? (_) => onSelected(seat.id) : null,
                materialTapTargetSize: MaterialTapTargetSize.padded,
              ),
            ),
        ],
      ),
    ],
  );
}

@immutable
class DsSeat {
  const DsSeat({
    required this.id,
    required this.label,
    required this.available,
    this.selected = false,
  });
  final String id;
  final String label;
  final bool available;
  final bool selected;
}

Future<T?> dsShowDialog<T>({
  required BuildContext context,
  required String title,
  required Widget child,
  List<Widget> actions = const [],
}) => showDialog<T>(
  context: context,
  builder: (context) => AlertDialog(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(DsTokens.cardRadius),
    ),
    title: DsText(title, style: DsTextStyle.title),
    content: SingleChildScrollView(child: child),
    actions: actions,
    scrollable: false,
  ),
);

/// Common route motion. Move a retained incoming surface without compositing
/// two full pages through alpha on every frame. This matters for image-heavy
/// account pages on budget Android GPUs.
Route<T> dsRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
}) => PageRouteBuilder<T>(
  settings: settings,
  pageBuilder: (context, animation, secondaryAnimation) =>
      RepaintBoundary(child: builder(context)),
  transitionDuration: DsTokens.standard,
  reverseTransitionDuration: DsTokens.quick,
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final curved = CurvedAnimation(parent: animation, curve: DsTokens.movement);
    return AnimatedBuilder(
      animation: curved,
      child: child,
      builder: (context, surface) {
        final ratio = MediaQuery.devicePixelRatioOf(context);
        final distance = MediaQuery.sizeOf(context).width * .035;
        // Preserve glyph raster positions while moving the retained layer.
        // Fractional physical pixels create new glyph-atlas entries per frame.
        final pixels = (distance * (1 - curved.value) * ratio).round();
        return Transform.translate(
          offset: Offset(pixels / ratio, 0),
          child: surface,
        );
      },
    );
  },
);

/// Router-independent Page adapter: go_router and other declarative routers
/// use the same route motion without a dependency from this package to them.
class DsTransitionPage<T> extends Page<T> {
  const DsTransitionPage({
    required this.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) {
    late final Route<T> route;
    route = dsRoute<T>(
      builder: (context) => (route.settings as DsTransitionPage<T>).child,
      settings: this,
    );
    return route;
  }
}
