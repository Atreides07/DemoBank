import 'package:flutter/material.dart';

import 'amount.dart';
import 'components.dart';
import 'theme.dart';
import 'tokens.dart';

/// One scrolling surface with safe areas and a readable maximum line length.
/// Page owns external spacing; cards and controls own their internal spacing.
class DsPage extends StatelessWidget {
  const DsPage({
    super.key,
    this.title,
    this.subtitle,
    this.actions,
    this.children,
    this.body,
    this.bottom,
    this.bottomNavigation,
    this.scrollController,
    this.onRefresh,
    this.onBack,
    this.backEnabled = true,
  }) : assert(children == null || body == null);

  final String? title;
  final String? subtitle;
  final List<Widget>? actions;
  final List<Widget>? children;
  final Widget? body;
  final Widget? bottom;
  final Widget? bottomNavigation;
  final ScrollController? scrollController;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onBack;
  final bool backEnabled;

  @override
  Widget build(BuildContext context) {
    Widget scroll = CustomScrollView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: DsConstrained(
            child: DsPadding(
              child: DsColumn(
                gap: DsSpace.section,
                children: [
                  if (subtitle != null)
                    DsText(
                      subtitle!,
                      style: DsTextStyle.caption,
                      tone: DsTone.muted,
                    ),
                  if (body != null) body!,
                  ...?children,
                ],
              ),
            ),
          ),
        ),
      ],
    );
    if (onRefresh != null) {
      scroll = RefreshIndicator(onRefresh: onRefresh!, child: scroll);
    }
    return DsScaffold(
      title: title,
      actions: actions,
      onBack: onBack,
      backEnabled: backEnabled,
      body: SafeArea(
        bottom: bottom == null && bottomNavigation == null,
        child: Column(
          children: [
            Expanded(child: scroll),
            if (bottom != null) DsActionArea(child: bottom!),
          ],
        ),
      ),
      bottomNavigationBar: bottomNavigation,
    );
  }
}

/// A fixed route toolbar. Local flow steps may supply [onBack]; otherwise
/// Navigator owns back navigation. Neither toolbar nor its target scrolls away.
/// PopScope makes Android system back follow the same local-step transition.
class DsScaffold extends StatelessWidget {
  const DsScaffold({
    super.key,
    required this.body,
    this.title,
    this.onBack,
    this.actions,
    this.bottomNavigationBar,
    this.backEnabled = true,
  });

  final Widget body;
  final String? title;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final Widget? bottomNavigationBar;
  final bool backEnabled;

  @override
  Widget build(BuildContext context) {
    final canGoBack = onBack != null || Navigator.of(context).canPop();
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final page = Scaffold(
      appBar: title != null || canGoBack
          ? AppBar(
              automaticallyImplyLeading: false,
              toolbarHeight: DsTokens.navigationHeight * scale,
              leading: canGoBack
                  ? DsIconButton(
                      icon: DsIcons.back,
                      label: 'Назад',
                      onPressed: backEnabled
                          ? onBack ?? () => Navigator.of(context).maybePop()
                          : null,
                    )
                  : null,
              title: title == null
                  ? null
                  : Semantics(
                      header: true,
                      child: DsText(
                        title!,
                        style: DsTextStyle.title,
                        maxLines: 2,
                      ),
                    ),
              actions: actions,
            )
          : null,
      body: body,
      bottomNavigationBar: bottomNavigationBar,
    );
    if (onBack == null && backEnabled) return page;
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && backEnabled && onBack != null) onBack!();
      },
      child: page,
    );
  }
}

/// Filter groups occupy one row at standard text sizes. Large text wraps
/// without shrinking labels or touch targets. Every option stays reachable.
class DsFilterBar extends StatelessWidget {
  const DsFilterBar({super.key, required this.id, required this.children});
  final String id;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(1) > DsTokens.largeTextThreshold
      ? DsFlow(children: children)
      : SingleChildScrollView(
          key: PageStorageKey('filters:$id'),
          scrollDirection: Axis.horizontal,
          child: DsRow(children: children),
        );
}

class DsConstrained extends StatelessWidget {
  const DsConstrained({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: DsTokens.readableWidth),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}

class DsPadding extends StatelessWidget {
  const DsPadding({super.key, required this.child, this.inset = DsInset.page});
  final Widget child;
  final DsInset inset;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: DsTokens.inset(context, inset), child: child);
}

class DsGap extends StatelessWidget {
  const DsGap({super.key, this.space = DsSpace.regular});
  final DsSpace space;

  @override
  Widget build(BuildContext context) =>
      SizedBox.square(dimension: DsTokens.space(space));
}

class DsColumn extends StatelessWidget {
  const DsColumn({
    super.key,
    required this.children,
    this.gap = DsSpace.regular,
    this.alignment = CrossAxisAlignment.stretch,
    this.compact = true,
  });
  final List<Widget> children;
  final DsSpace gap;
  final CrossAxisAlignment alignment;
  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
    crossAxisAlignment: alignment,
    children: _separated(children, SizedBox(height: DsTokens.space(gap))),
  );
}

class DsRow extends StatelessWidget {
  const DsRow({
    super.key,
    required this.children,
    this.gap = DsSpace.compact,
    this.alignment = MainAxisAlignment.start,
    this.wrap = false,
  });
  final List<Widget> children;
  final DsSpace gap;
  final MainAxisAlignment alignment;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    if (wrap) return DsFlow(gap: gap, children: children);
    return Row(
      mainAxisAlignment: alignment,
      children: _separated(children, SizedBox(width: DsTokens.space(gap))),
    );
  }
}

class DsFlow extends StatelessWidget {
  const DsFlow({super.key, required this.children, this.gap = DsSpace.compact});
  final List<Widget> children;
  final DsSpace gap;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: DsTokens.space(gap),
    runSpacing: DsTokens.space(gap),
    crossAxisAlignment: WrapCrossAlignment.center,
    children: children,
  );
}

class DsAdaptiveGrid extends StatelessWidget {
  const DsAdaptiveGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth >= DsTokens.gridBreakpoint &&
              MediaQuery.textScalerOf(context).scale(1) < 1.5
          ? 2
          : 1;
      final gap = DsTokens.space(DsSpace.regular);
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

/// Frequent actions are grouped in pairs on phones, with a single readable
/// column at large text sizes. Content, rather than a fixed tile height,
/// determines the row height.
class DsActionGrid extends StatelessWidget {
  const DsActionGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          MediaQuery.textScalerOf(context).scale(1) >
              DsTokens.largeTextThreshold
          ? 1
          : constraints.maxWidth >= DsTokens.gridBreakpoint
          ? children.length.clamp(1, 4)
          : children.length.clamp(1, 2);
      final gap = DsTokens.space(DsSpace.regular);
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class DsSection extends StatelessWidget {
  const DsSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.action,
    this.density = DsDensity.comfortable,
  });
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? action;
  final DsDensity density;

  @override
  Widget build(BuildContext context) => DsColumn(
    gap: density == DsDensity.compact ? DsSpace.compact : DsSpace.regular,
    children: [
      DsColumn(
        gap: DsSpace.tight,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.4;
              return largeText
                  ? DsColumn(
                      gap: DsSpace.compact,
                      children: [
                        DsText(title, style: DsTextStyle.title),
                        if (action != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: action!,
                          ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: DsText(title, style: DsTextStyle.title),
                        ),
                        if (action != null) action!,
                      ],
                    );
            },
          ),
          if (subtitle != null)
            DsText(subtitle!, tone: DsTone.muted, style: DsTextStyle.caption),
        ],
      ),
      child,
    ],
  );
}

class DsScreenHeader extends StatelessWidget {
  const DsScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
  });
  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) => DsColumn(
    gap: DsSpace.compact,
    children: [
      if (actions?.isNotEmpty ?? false) DsFlow(children: actions!),
      Semantics(
        header: true,
        child: DsText(title, style: DsTextStyle.headline),
      ),
      if (subtitle != null) DsText(subtitle!, tone: DsTone.muted),
    ],
  );
}

class DsActionArea extends StatelessWidget {
  const DsActionArea({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.dsPalette.surface,
      border: Border(top: BorderSide(color: context.dsPalette.border)),
    ),
    child: SafeArea(
      top: false,
      child: DsConstrained(child: DsPadding(child: child)),
    ),
  );
}

/// A reading surface with a reachable notice that never consumes scroll layout
/// space. The host decides when to offer/apply updates; the scrollable child
/// retains exactly the same constraints and position when the notice changes.
class DsReadingSurface extends StatelessWidget {
  const DsReadingSurface({super.key, required this.child, this.notice});
  final Widget child;
  final Widget? notice;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      child,
      if (notice != null)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: DsConstrained(
              child: DsPadding(
                child: Semantics(
                  liveRegion: true,
                  container: true,
                  child: Material(
                    color: context.dsPalette.surface,
                    borderRadius: BorderRadius.circular(DsTokens.cardRadius),
                    clipBehavior: Clip.antiAlias,
                    child: notice,
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class DsSliverContent extends StatelessWidget {
  const DsSliverContent({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: DsConstrained(child: DsPadding(child: child)),
  );
}

class DsSliverInset extends StatelessWidget {
  const DsSliverInset({super.key, required this.sliver});
  final Widget sliver;

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: EdgeInsets.symmetric(horizontal: DsTokens.pagePadding(context)),
    sliver: sliver,
  );
}

class DsSliverGap extends StatelessWidget {
  const DsSliverGap({super.key, this.space = DsSpace.section});
  final DsSpace space;

  @override
  Widget build(BuildContext context) =>
      SliverToBoxAdapter(child: DsGap(space: space));
}

/// A scroll-coupled pinned header. Geometry follows scroll directly; no timer
/// or full-screen implicit animation competes with the user's gesture.
class DsCollapsingHeader extends StatelessWidget {
  const DsCollapsingHeader({
    super.key,
    required this.title,
    required this.balance,
    this.subtitle,
    this.label = 'Общий баланс',
    this.child,
    this.action,
    this.density = DsDensity.comfortable,
  });
  final String title;
  final String balance;
  final String? subtitle;
  final String label;
  final Widget? child;
  final Widget? action;
  final DsDensity density;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    var compact =
        density == DsDensity.compact &&
        scale <= DsTokens.largeTextThreshold &&
        action == null;
    if (compact) {
      final amount = TextPainter(
        text: TextSpan(
          text: balance,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      compact =
          amount.width <=
          MediaQuery.sizeOf(context).width -
              (DsTokens.pagePadding(context) + DsTokens.cardInset) * 2;
      amount.dispose();
    }
    return SliverPersistentHeader(
      pinned: true,
      delegate: _BalanceHeaderDelegate(
        title: title,
        balance: balance,
        label: label,
        subtitle: subtitle,
        child: child,
        action: action,
        scale: scale,
        compact: compact,
      ),
    );
  }
}

class _BalanceHeaderDelegate extends SliverPersistentHeaderDelegate {
  _BalanceHeaderDelegate({
    required this.title,
    required this.balance,
    required this.label,
    required this.scale,
    required this.compact,
    this.subtitle,
    this.child,
    this.action,
  });
  final String title;
  final String balance;
  final String label;
  final String? subtitle;
  final Widget? child;
  final Widget? action;
  final double scale;
  final bool compact;

  @override
  double get minExtent => DsTokens.headerCollapsed * scale;
  @override
  double get maxExtent =>
      (compact ? DsTokens.compactHeaderExpanded : DsTokens.headerExpanded) *
          scale +
      (child != null
          ? DsTokens.controlHeight * (scale + (scale - 1))
          : subtitle != null
          ? DsTokens.cardInset * scale
          : 0) +
      (action == null ? 0 : DsTokens.controlHeight * scale);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final t = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final colors = context.dsPalette;
    final inset = DsTokens.pagePadding(context);
    return RepaintBoundary(
      child: ColoredBox(
        color: colors.background,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            inset,
            DsTokens.unit * 2,
            inset,
            DsTokens.unit * 2,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(DsTokens.cardRadius * (1 - t)),
            child: ColoredBox(
              color: Color.lerp(colors.surface, colors.background, t)!,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DsTokens.cardInset,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned(
                        top: DsTokens.compactInset,
                        left: 0,
                        right: 0,
                        child: Opacity(
                          opacity: (1 - t / DsTokens.headerLabelsFadeEnd).clamp(
                            0.0,
                            1.0,
                          ),
                          child: ExcludeSemantics(
                            excluding: t >= DsTokens.headerLabelsFadeEnd,
                            child: compact
                                ? Row(
                                    children: [
                                      Expanded(
                                        child: DsText(
                                          title,
                                          style: DsTextStyle.caption,
                                        ),
                                      ),
                                      DsText(
                                        label,
                                        style: DsTextStyle.caption,
                                        tone: DsTone.muted,
                                      ),
                                    ],
                                  )
                                : DsColumn(
                                    gap: DsSpace.tight,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: DsText(
                                              title,
                                              style: DsTextStyle.label,
                                              tone: DsTone.primary,
                                            ),
                                          ),
                                          if (action != null) action!,
                                        ],
                                      ),
                                      DsText(
                                        label,
                                        style: DsTextStyle.caption,
                                        tone: DsTone.primary,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: compact
                            ? DsTokens.compactHeaderBalanceTop * scale * (1 - t)
                            : (DsTokens.headerBalanceTop +
                                      (action == null
                                          ? 0
                                          : DsTokens.controlHeight)) *
                                  scale *
                                  (1 - t),
                        child: Semantics(
                          label: '$label: $balance',
                          excludeSemantics: true,
                          child: DsAmountLayout(
                            key: const ValueKey('ds-header-amount'),
                            text: balance,
                            style: TextStyle.lerp(
                              (compact
                                      ? Theme.of(
                                          context,
                                        ).textTheme.headlineLarge
                                      : scale > 1.3
                                      ? Theme.of(
                                          context,
                                        ).textTheme.headlineMedium
                                      : Theme.of(
                                          context,
                                        ).textTheme.displayLarge)
                                  ?.copyWith(color: colors.ink),
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: colors.ink,
                              ),
                              t,
                            ),
                          ),
                        ),
                      ),
                      if (t < DsTokens.headerActionsFadeEnd)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: compact
                              ? DsTokens.compactInset
                              : DsTokens.cardInset,
                          child: Opacity(
                            opacity: (1 - t / DsTokens.headerActionsFadeEnd)
                                .clamp(0.0, 1.0),
                            child: ExcludeSemantics(
                              excluding: t >= DsTokens.headerActionsFadeEnd,
                              child: DsColumn(
                                gap: DsSpace.compact,
                                children: [
                                  if (subtitle != null)
                                    DsText(
                                      subtitle!,
                                      style: DsTextStyle.caption,
                                      tone: DsTone.primary,
                                    ),
                                  if (child != null) child!,
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _BalanceHeaderDelegate oldDelegate) =>
      title != oldDelegate.title ||
      balance != oldDelegate.balance ||
      subtitle != oldDelegate.subtitle ||
      label != oldDelegate.label ||
      compact != oldDelegate.compact ||
      scale != oldDelegate.scale ||
      child != oldDelegate.child ||
      action != oldDelegate.action;
}

List<Widget> _separated(List<Widget> children, Widget gap) => [
  for (var index = 0; index < children.length; index++) ...[
    if (index > 0) gap,
    children[index],
  ],
];
