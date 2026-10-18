import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'amount.dart';
import 'charts.dart';
import 'components.dart';
import 'layout.dart';
import 'localizations.dart';
import 'theme.dart';
import 'tokens.dart';

/// Raster artwork is bundled, decoded to the rendered size and shared by the
/// two applications. Screens select a semantic asset, never an image geometry.
enum DsArt {
  travelTrain,
  coast,
  gift,
  cashback,
  books,
  shopping,
  accountGlow,
  home,
  saving,
  investments,
  borrow,
  cardPlastic,
  electronics,
  cosmetics,
  clothes,
  appliances,
  pillow,
  airfryer,
  insurance,
  cardPromo,
}

extension on DsArt {
  String get file => switch (this) {
    DsArt.travelTrain => 'travel-train',
    DsArt.accountGlow => 'account-glow',
    DsArt.cardPlastic => 'card-plastic',
    DsArt.cardPromo => 'card-promo',
    _ => name,
  };
}

/// The host supplies an optional asset package without coupling this shared
/// UI library to bank marketing content or increasing a standalone app's APK.
class DsArtworkSource extends InheritedWidget {
  const DsArtworkSource({
    super.key,
    required this.package,
    required super.child,
  });
  final String package;
  static String of(BuildContext context) {
    final source = context
        .dependOnInheritedWidgetOfExactType<DsArtworkSource>();
    if (source == null) {
      throw FlutterError(
        'The host must supply DsArtworkSource for artwork components.',
      );
    }
    return source.package;
  }

  @override
  bool updateShouldNotify(DsArtworkSource oldWidget) =>
      package != oldWidget.package;
}

class DsArtwork extends StatelessWidget {
  const DsArtwork(this.art, {super.key, this.fit = BoxFit.cover});
  final DsArt art;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : DsTokens.readableWidth;
      final pixels = (width * MediaQuery.devicePixelRatioOf(context))
          .ceil()
          .clamp(1, DsTokens.artworkDecodeLimit);
      return ExcludeSemantics(
        child: Image.asset(
          'assets/art/${art.file}.png',
          package: DsArtworkSource.of(context),
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          cacheWidth: pixels,
          filterQuality: FilterQuality.low,
          gaplessPlayback: true,
        ),
      );
    },
  );
}

class DsPanel extends StatelessWidget {
  const DsPanel({
    super.key,
    required this.child,
    this.onTap,
    this.inset = DsInset.card,
    this.subtle = false,
  });
  final Widget child;
  final VoidCallback? onTap;
  final DsInset inset;
  final bool subtle;
  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    child: Material(
      color: subtle ? context.dsPalette.background : context.dsPalette.surface,
      // A native physical shadow avoids a large Gaussian-blur texture around
      // every panel, including the two panels in the overview row.
      elevation: subtle ? 0 : 4,
      shadowColor: Colors.black.withValues(alpha: .22),
      surfaceTintColor: Colors.transparent,
      borderRadius: BorderRadius.circular(DsTokens.panelRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DsPadding(inset: inset, child: child),
      ),
    ),
  );
}

class DsShortcut {
  const DsShortcut(this.label, this.icon, this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
}

class DsShortcutBar extends StatelessWidget {
  const DsShortcutBar({super.key, required this.actions, this.panel = false});
  final List<DsShortcut> actions;
  final bool panel;
  @override
  Widget build(BuildContext context) {
    Widget item(DsShortcut a) => Semantics(
      button: true,
      label: a.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: a.onTap,
        borderRadius: BorderRadius.circular(DsTokens.referenceControlRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: DsColumn(
            gap: DsSpace.compact,
            children: [
              Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: panel
                      ? Colors.transparent
                      : context.dsPalette.background,
                  borderRadius: BorderRadius.circular(
                    DsTokens.referenceControlRadius,
                  ),
                ),
                child: Icon(a.icon, size: 30, color: context.dsPalette.link),
              ),
              Text(
                a.label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: panel ? context.dsPalette.link : context.dsPalette.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final large =
        MediaQuery.textScalerOf(context).scale(1) > DsTokens.largeTextThreshold;
    final row = large
        ? DsColumn(children: actions.map(item).toList())
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final a in actions) Expanded(child: item(a))],
          );
    return panel ? DsPanel(child: row) : row;
  }
}

enum DsRailStyle { stories, offers, categories, products }

class DsRail extends StatelessWidget {
  const DsRail({
    super.key,
    required this.id,
    required this.children,
    required this.style,
  });
  final String id;
  final List<Widget> children;
  final DsRailStyle style;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
      final (width, height) = switch (style) {
        DsRailStyle.stories => (96.0, 104.0),
        DsRailStyle.offers => (
          math.min(260.0, constraints.maxWidth * .76),
          248.0,
        ),
        DsRailStyle.categories => (80.0, 132.0),
        DsRailStyle.products => (
          math.min(196.0, constraints.maxWidth * .58),
          292.0,
        ),
      };
      final extraHeight = switch (style) {
        DsRailStyle.offers => 240,
        DsRailStyle.products => 180,
        _ => 100,
      };
      return SizedBox(
        height: height + (scale - 1) * extraHeight,
        child: ListView.separated(
          key: PageStorageKey('rail:$id'),
          scrollDirection: Axis.horizontal,
          itemCount: children.length,
          itemBuilder: (context, index) => SizedBox(
            width: width * (scale > 1.4 ? 1.3 : 1),
            child: children[index],
          ),
          separatorBuilder: (_, _) => const SizedBox(width: 12),
        ),
      );
    },
  );
}

class DsStory extends StatelessWidget {
  const DsStory({
    super.key,
    required this.title,
    required this.art,
    required this.onTap,
  });
  final String title;
  final DsArt art;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: title,
    excludeSemantics: true,
    child: Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(color: context.dsPalette.link, width: 1.5),
        borderRadius: BorderRadius.circular(22),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DsArtwork(art),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    color: Colors.black.withValues(alpha: .32),
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class DsSpendingStrip extends StatelessWidget {
  const DsSpendingStrip({super.key, required this.points});
  final List<DsChartPoint> points;
  @override
  Widget build(BuildContext context) => Semantics(
    label: points.map((p) => '${p.label}: ${p.displayValue}').join(', '),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 10,
        child: Row(
          children: [
            for (var i = 0; i < points.length; i++)
              Expanded(
                flex: math.max(1, points[i].value.round()),
                child: ColoredBox(
                  color: dsChartColor(context, points[i].role),
                  child: const SizedBox.expand(),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class DsOverviewCard extends StatelessWidget {
  const DsOverviewCard({
    super.key,
    required this.title,
    required this.value,
    this.detail,
    this.footer,
    required this.onTap,
  });
  final String title;
  final String value;
  final String? detail;
  final Widget? footer;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => DsPanel(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 88),
      child: DsColumn(
        gap: DsSpace.compact,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: DsTokens.overviewTitleSize,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: DsTokens.overviewValueSize,
            ),
          ),
          if (detail != null)
            DsText(detail!, style: DsTextStyle.caption, tone: DsTone.muted),
          if (footer != null) footer!,
        ],
      ),
    ),
  );
}

class DsBankCardData {
  const DsBankCardData(this.id, this.digits, {this.frozen = false});
  final String id;
  final String digits;
  final bool frozen;
}

class DsBankCards extends StatelessWidget {
  const DsBankCards({
    super.key,
    required this.cards,
    required this.onCard,
    this.onAdd,
  });
  final List<DsBankCardData> cards;
  final ValueChanged<String> onCard;
  final VoidCallback? onAdd;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: DsTokens.bankCardHeight,
    child: ListView.separated(
      key: PageStorageKey(
        'bank-cards:${cards.map((card) => card.id).join(',')}',
      ),
      scrollDirection: Axis.horizontal,
      itemCount: cards.length + (onAdd == null ? 0 : 1),
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (context, i) {
        if (i == cards.length) {
          return SizedBox(
            width: 64,
            child: Material(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
              child: IconButton(
                tooltip: DsLocalizations.of(context).addCard,
                onPressed: onAdd,
                icon: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          );
        }
        final card = cards[i];
        return SizedBox(
          width: DsTokens.bankCardWidth,
          child: Semantics(
            button: true,
            label: DsLocalizations.of(
              context,
            ).card(card.digits, frozen: card.frozen),
            excludeSemantics: true,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Material(
                color: Colors.black,
                child: InkWell(
                  onTap: () => onCard(card.id),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Opacity(
                        opacity: card.frozen ? .5 : 1,
                        child: const DsArtwork(DsArt.cardPlastic),
                      ),
                      Positioned(
                        left: 6,
                        bottom: 5,
                        child: Text(
                          card.digits,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      if (card.frozen)
                        const Align(
                          alignment: Alignment.topRight,
                          child: Icon(
                            Icons.lock_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class DsAccountProduct extends StatelessWidget {
  const DsAccountProduct({
    super.key,
    required this.title,
    required this.balance,
    required this.onTap,
    this.cards = const [],
    this.cashback,
    this.icon = Icons.currency_ruble_rounded,
  });
  final String title;
  final String balance;
  final String? cashback;
  final List<DsBankCardData> cards;
  final VoidCallback onTap;
  final IconData icon;
  @override
  Widget build(BuildContext context) => DsPanel(
    onTap: onTap,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: context.dsPalette.link,
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: DsColumn(
            gap: DsSpace.compact,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                runSpacing: 4,
                children: [
                  DsText(balance, style: DsTextStyle.title),
                  if (cashback != null) DsBadge(cashback!),
                ],
              ),
              DsText(title, style: DsTextStyle.body),
              if (cards.isNotEmpty)
                DsBankCards(cards: cards, onCard: (_) => onTap()),
            ],
          ),
        ),
      ],
    ),
  );
}

class DsBadge extends StatelessWidget {
  const DsBadge(this.label, {super.key, this.success = false});
  final String label;
  final bool success;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: success
          ? context.dsPalette.success.withValues(alpha: .12)
          : context.dsPalette.navy,
      borderRadius: BorderRadius.circular(100),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: success ? context.dsPalette.success : Colors.white,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class DsOfferBanner extends StatelessWidget {
  const DsOfferBanner({
    super.key,
    required this.title,
    required this.detail,
    required this.art,
    required this.onTap,
    this.onDismiss,
  });
  final String title;
  final String detail;
  final DsArt art;
  final VoidCallback onTap;
  final VoidCallback? onDismiss;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(DsTokens.panelRadius),
    child: Material(
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Positioned.fill(child: DsArtwork(art)),
            Positioned.fill(
              child: ColoredBox(color: Colors.black.withValues(alpha: .15)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: FractionallySizedBox(
                widthFactor: .76,
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 92),
                  child: DsColumn(
                    gap: DsSpace.regular,
                    children: [
                      DsText(
                        title,
                        style: DsTextStyle.title,
                        tone: DsTone.inverse,
                      ),
                      DsText(
                        detail,
                        style: DsTextStyle.body,
                        tone: DsTone.inverse,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (onDismiss != null)
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  tooltip: DsLocalizations.of(context).hideOffer,
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

enum DsImageOfferStyle { hero, rail }

class DsImageOffer extends StatelessWidget {
  const DsImageOffer({
    super.key,
    required this.title,
    required this.detail,
    required this.art,
    required this.onTap,
    this.button,
    this.style = DsImageOfferStyle.hero,
  });
  final String title;
  final String detail;
  final DsArt art;
  final VoidCallback onTap;
  final String? button;
  final DsImageOfferStyle style;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(DsTokens.panelRadius),
    child: Material(
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Positioned.fill(child: DsArtwork(art)),
            Positioned.fill(
              child: ColoredBox(color: Colors.black.withValues(alpha: .24)),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 240),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: DsColumn(
                  gap: DsSpace.regular,
                  children: [
                    DsText(
                      title,
                      style: style == DsImageOfferStyle.rail
                          ? DsTextStyle.title
                          : DsTextStyle.headline,
                      tone: DsTone.inverse,
                      maxLines: style == DsImageOfferStyle.rail ? 2 : null,
                    ),
                    DsText(
                      detail,
                      style: style == DsImageOfferStyle.rail
                          ? DsTextStyle.caption
                          : DsTextStyle.body,
                      tone: DsTone.inverse,
                      maxLines: style == DsImageOfferStyle.rail ? 3 : null,
                    ),
                    if (button != null)
                      DsButton(label: button!, onPressed: onTap),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class DsArtTile extends StatelessWidget {
  const DsArtTile({
    super.key,
    required this.title,
    required this.art,
    required this.onTap,
  });
  final String title;
  final DsArt art;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => DsPanel(
    subtle: true,
    inset: DsInset.none,
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DsPadding(
          inset: DsInset.card,
          child: DsText(title, style: DsTextStyle.title),
        ),
        AspectRatio(aspectRatio: 1.8, child: DsArtwork(art, fit: BoxFit.cover)),
      ],
    ),
  );
}

class DsCategoryTile extends StatelessWidget {
  const DsCategoryTile({
    super.key,
    required this.title,
    required this.art,
    required this.onTap,
  });
  final String title;
  final DsArt art;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: DsColumn(
      gap: DsSpace.compact,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: DsArtwork(art),
          ),
        ),
        DsText(title, style: DsTextStyle.caption, align: TextAlign.center),
      ],
    ),
  );
}

class DsProductTile extends StatelessWidget {
  const DsProductTile({
    super.key,
    required this.title,
    required this.price,
    required this.art,
    required this.onTap,
    this.oldPrice,
    this.reward,
  });
  final String title;
  final String price;
  final String? oldPrice;
  final String? reward;
  final DsArt art;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: DsColumn(
      gap: DsSpace.compact,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DsArtwork(art),
                if (reward != null)
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: DsBadge(reward!, success: true),
                  ),
              ],
            ),
          ),
        ),
        Wrap(
          spacing: 6,
          children: [
            DsText(price, style: DsTextStyle.label),
            if (oldPrice != null)
              Text(
                oldPrice!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.dsPalette.muted,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
          ],
        ),
        DsText(title, style: DsTextStyle.body, maxLines: 2),
      ],
    ),
  );
}

class DsShowcaseHeading extends StatelessWidget {
  const DsShowcaseHeading(
    this.title, {
    super.key,
    this.action,
    this.center = false,
  });
  final String title;
  final Widget? action;
  final bool center;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: center ? 16 : 4),
    child: Row(
      children: [
        Expanded(
          child: DsText(
            title,
            style: DsTextStyle.headline,
            align: center ? TextAlign.center : TextAlign.start,
          ),
        ),
        if (action != null) action!,
      ],
    ),
  );
}

class DsSliverPage extends StatelessWidget {
  const DsSliverPage({
    super.key,
    this.scrollKey,
    required this.slivers,
    required this.controller,
    this.onRefresh,
    this.darkTop = false,
    this.white = false,
    this.prebuildOffscreen = true,
  });
  final Key? scrollKey;
  final List<Widget> slivers;
  final ScrollController controller;
  final Future<void> Function()? onRefresh;
  final bool darkTop;
  final bool white;

  /// Image-heavy detail screens can defer below-fold media until it is visible
  /// instead of competing with the initial route's texture uploads.
  final bool prebuildOffscreen;
  @override
  Widget build(BuildContext context) {
    final palette = context.dsPalette;
    final scroll = CustomScrollView(
      key: scrollKey,
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      cacheExtent: prebuildOffscreen ? null : 0,
      slivers: slivers,
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: darkTop
          ? SystemUiOverlayStyle.light
          : (Theme.of(context).brightness == Brightness.dark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark),
      child: ColoredBox(
        color: darkTop
            ? palette.navy
            : white
            ? palette.surface
            : palette.background,
        child: SafeArea(
          child: ColoredBox(
            color: white ? palette.surface : palette.background,
            child: onRefresh == null
                ? scroll
                : RefreshIndicator(onRefresh: onRefresh!, child: scroll),
          ),
        ),
      ),
    );
  }
}

class DsHomeHeader extends StatelessWidget {
  const DsHomeHeader({
    super.key,
    required this.name,
    required this.onProfile,
    required this.onSearch,
    required this.onRewards,
  });
  final String name;
  final VoidCallback onProfile;
  final VoidCallback onSearch;
  final VoidCallback onRewards;
  @override
  Widget build(BuildContext context) => SliverPersistentHeader(
    pinned: true,
    delegate: _HomeHeaderDelegate(
      name,
      onProfile,
      onSearch,
      onRewards,
      MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0),
    ),
  );
}

class _HomeHeaderDelegate extends SliverPersistentHeaderDelegate {
  _HomeHeaderDelegate(
    this.name,
    this.onProfile,
    this.onSearch,
    this.onRewards,
    this.scale,
  );
  final String name;
  final VoidCallback onProfile;
  final VoidCallback onSearch;
  final VoidCallback onRewards;
  final double scale;
  @override
  double get minExtent => DsTokens.referenceHomeCollapsed * scale;
  @override
  double get maxExtent => DsTokens.referenceHomeExpanded * scale;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final t = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    return Material(
      color: context.dsPalette.surface,
      elevation: overlapsContent ? 1 : 0,
      child: ClipRect(
        child: Stack(
          children: [
            if (t < .8)
              Positioned(
                top: 6 - shrinkOffset,
                left: 16,
                right: 16,
                child: Opacity(
                  opacity: (1 - t / .8).clamp(0, 1),
                  child: Semantics(
                    button: true,
                    label: DsLocalizations.of(context).searchBank,
                    child: InkWell(
                      onTap: onSearch,
                      borderRadius: BorderRadius.circular(DsTokens.panelRadius),
                      child: Container(
                        height: 44 * scale,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: context.dsPalette.background,
                          borderRadius: BorderRadius.circular(
                            DsTokens.panelRadius,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              DsIcons.search,
                              color: context.dsPalette.muted,
                            ),
                            const SizedBox(width: 8),
                            DsText(
                              DsLocalizations.of(context).search,
                              tone: DsTone.muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 16,
              right: 8,
              bottom: 4,
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: onProfile,
                      borderRadius: BorderRadius.circular(DsTokens.panelRadius),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 19,
                            backgroundColor: context.dsPalette.background,
                            child: DsText(
                              name.characters.first,
                              style: DsTextStyle.label,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              name,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontSize: DsTokens.profileNameSize,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(DsTokens.chevron),
                        ],
                      ),
                    ),
                  ),
                  if (t > .6)
                    DsIconButton(
                      label: DsLocalizations.of(context).searchBank,
                      icon: DsIcons.search,
                      onPressed: onSearch,
                    ),
                  DsIconButton(
                    label: DsLocalizations.of(context).rewards,
                    icon: Icons.redeem_rounded,
                    onPressed: onRewards,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _HomeHeaderDelegate old) =>
      name != old.name ||
      scale != old.scale ||
      onProfile != old.onProfile ||
      onSearch != old.onSearch ||
      onRewards != old.onRewards;
}

class DsAccountHeader extends StatelessWidget {
  const DsAccountHeader({
    super.key,
    required this.name,
    required this.balance,
    required this.cards,
    required this.onBack,
    required this.onRename,
    required this.onCard,
    required this.onAdd,
  });
  final String name;
  final String balance;
  final List<DsBankCardData> cards;
  final VoidCallback onBack;
  final VoidCallback onRename;
  final ValueChanged<String> onCard;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => SliverPersistentHeader(
    pinned: true,
    delegate: _AccountHeaderDelegate(
      this,
      MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0),
    ),
  );
}

class _AccountHeaderDelegate extends SliverPersistentHeaderDelegate {
  _AccountHeaderDelegate(this.content, this.scale);
  final DsAccountHeader content;
  final double scale;
  @override
  double get minExtent => DsTokens.referenceAccountCollapsed * scale;
  @override
  double get maxExtent => DsTokens.referenceAccountExpanded * scale;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final t = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    return RepaintBoundary(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DsArtwork(DsArt.accountGlow),
            Positioned.fill(
              child: ColoredBox(
                color: context.dsPalette.navy.withValues(alpha: t),
              ),
            ),
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                tooltip: DsLocalizations.of(context).back,
                onPressed: content.onBack,
                color: Colors.white,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            if (scale > 1.4 && t < .4)
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  tooltip: DsLocalizations.of(context).renameAccount,
                  onPressed: content.onRename,
                  color: Colors.white,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                ),
              ),
            Positioned(
              left: 24 + 40 * t,
              right: 24,
              top: (56 * (1 - t) + 2 * t) * scale,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      content.name,
                      maxLines: scale > 1.4 && t < .4 ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle.lerp(
                        Theme.of(context).textTheme.headlineLarge,
                        Theme.of(context).textTheme.titleLarge,
                        t,
                      )?.copyWith(color: Colors.white),
                    ),
                  ),
                  if (scale <= 1.4 && t < .4)
                    IconButton(
                      tooltip: DsLocalizations.of(context).renameAccount,
                      onPressed: content.onRename,
                      color: Colors.white,
                      icon: const Icon(Icons.edit_rounded, size: 18),
                    ),
                ],
              ),
            ),
            Positioned(
              left: 24 + 40 * t,
              right: 16,
              top: ((scale > 1.4 ? 128 : 110) * (1 - t) + 36 * t) * scale,
              child: DsAmountLayout(
                key: const ValueKey('ds-account-balance'),
                text: content.balance,
                style: TextStyle.lerp(
                  scale > 1.4
                      ? Theme.of(context).textTheme.headlineMedium
                      : Theme.of(context).textTheme.displayLarge,
                  Theme.of(context).textTheme.bodyLarge,
                  t,
                )?.copyWith(color: Colors.white),
              ),
            ),
            if (t < .55)
              Positioned(
                left: 24,
                right: 24,
                bottom: 24,
                child: Opacity(
                  opacity: (1 - t / .55).clamp(0, 1),
                  child: DsBankCards(
                    cards: content.cards,
                    onCard: content.onCard,
                    onAdd: content.onAdd,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _AccountHeaderDelegate old) =>
      content != old.content || scale != old.scale;
}

class DsLimitRow extends StatelessWidget {
  const DsLimitRow({
    super.key,
    required this.title,
    required this.detail,
    required this.fraction,
  });
  final String title;
  final String detail;
  final double fraction;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 40,
        height: 40,
        child: CircularProgressIndicator(
          value: fraction.clamp(0, 1),
          strokeWidth: 5,
          backgroundColor: context.dsPalette.background,
          color: context.dsPalette.link,
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: DsColumn(
          gap: DsSpace.tight,
          children: [
            DsText(title),
            DsText(detail, style: DsTextStyle.caption, tone: DsTone.muted),
          ],
        ),
      ),
    ],
  );
}

class DsSwitchRow extends StatelessWidget {
  const DsSwitchRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
    contentPadding: EdgeInsets.zero,
    title: DsText(title),
    subtitle: subtitle == null
        ? null
        : DsText(subtitle!, style: DsTextStyle.caption, tone: DsTone.muted),
    value: value,
    onChanged: onChanged,
  );
}

/// A feed section is built only when its sliver enters the viewport. Artwork
/// decoding and nested rails never delay the first visible bank controls.
class DsSliverSections extends StatelessWidget {
  const DsSliverSections({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SliverList.builder(
    itemCount: children.length,
    itemBuilder: (context, index) => DsConstrained(
      child: DsPadding(
        inset: DsInset.horizontal,
        child: DsColumn(
          gap: DsSpace.section,
          children: [
            children[index],
            const DsGap(space: DsSpace.none),
          ],
        ),
      ),
    ),
  );
}

class DsFeatureArtwork extends StatelessWidget {
  const DsFeatureArtwork(this.art, {super.key});
  final DsArt art;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(DsTokens.panelRadius),
    child: AspectRatio(aspectRatio: 1.5, child: DsArtwork(art)),
  );
}

/// Demo deep links are valid QR payloads but contain no real bank details.
class DsQrCode extends StatelessWidget {
  const DsQrCode({super.key, required this.data, this.label});
  final String data;
  final String? label;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label ?? DsLocalizations.of(context).qrCode,
    image: true,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 248),
        child: QrImageView(
          data: data,
          version: QrVersions.auto,
          backgroundColor: Colors.white,
          eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: Colors.black,
          ),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: Colors.black,
          ),
        ),
      ),
    ),
  );
}

class DsKeyValue extends StatelessWidget {
  const DsKeyValue({super.key, required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => DsColumn(
    gap: DsSpace.tight,
    children: [
      DsText(label, style: DsTextStyle.caption, tone: DsTone.muted),
      SelectableText(value, style: Theme.of(context).textTheme.bodyLarge),
    ],
  );
}
