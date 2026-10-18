import 'package:flutter/material.dart';

/// These are semantic choices, not an open-ended numeric layout escape hatch.
enum DsSpace { none, tight, compact, regular, section, page }

enum DsTextStyle { caption, label, body, title, headline, display }

enum DsTone { primary, muted, accent, success, warning, danger, inverse }

enum DsCardTone { surface, dark, accent, subtle }

enum DsButtonVariant { primary, secondary, quiet, danger }

enum DsStatusKind { loading, empty, error, success, info }

enum DsDensity { comfortable, compact }

enum DsInset { none, page, horizontal, card, compact, section, listHeader }

/// Icon meaning is shared across features; screens choose a purpose, never a
/// font, drawing size, or ad-hoc icon variant.
abstract final class DsIcons {
  static const search = Icons.search_rounded;
  static const receipt = Icons.receipt_long_outlined;
  static const home = Icons.home_outlined;
  static const cinema = Icons.movie_outlined;
  static const schedule = Icons.schedule_rounded;
  static const success = Icons.check_circle_outline_rounded;
  static const check = Icons.check_rounded;
  static const dashboard = Icons.space_dashboard_outlined;
  static const analytics = Icons.bar_chart_rounded;
  static const services = Icons.apps_rounded;
  static const settings = Icons.tune_rounded;
  static const card = Icons.credit_card_outlined;
  static const fines = Icons.directions_car_outlined;
  static const mobile = Icons.smartphone_outlined;
  static const design = Icons.palette_outlined;
  static const open = Icons.open_in_new_rounded;
  static const transfer = Icons.north_east_rounded;
  static const add = Icons.add_rounded;
  static const calendar = Icons.calendar_month_outlined;
  static const back = Icons.arrow_back_rounded;
  static const toTop = Icons.arrow_upward_rounded;
  static const transport = Icons.directions_transit_outlined;
  static const health = Icons.favorite_outline_rounded;
  static const cafe = Icons.local_cafe_outlined;
  static const ticket = Icons.local_play_outlined;
  static const refresh = Icons.refresh_rounded;
  static const shopping = Icons.shopping_bag_outlined;
  static const groceries = Icons.shopping_basket_outlined;
  static const qr = Icons.qr_code_rounded;
  static const gift = Icons.redeem_rounded;
  static const salary = Icons.payments_outlined;
  static const pension = Icons.account_balance_outlined;
  static const document = Icons.description_outlined;
  static const link = Icons.link_rounded;
  static const copy = Icons.copy_rounded;
  static const lock = Icons.lock_outline_rounded;
  static const investments = Icons.work_outline_rounded;
  static const currencyUsd = Icons.attach_money_rounded;
  static const currencyGbp = Icons.currency_pound_rounded;
  static const ruble = Icons.currency_ruble_rounded;
  static const wallet = Icons.account_balance_wallet_outlined;
  static const language = Icons.translate_rounded;
}

/// The base scale is intentionally private to the package's presentation code.
/// Consumers choose a semantic variant; they never multiply these dimensions.
abstract final class DsTokens {
  static const unit = 4.0;
  static const pageInset = 20.0;
  static const compactPageInset = 16.0;
  static const cardInset = 16.0;
  static const compactInset = 12.0;
  static const sectionGap = 16.0;
  static const controlHeight = 48.0;
  static const touchTarget = 48.0;
  static const iconSize = 22.0;
  static const smallIconSize = 18.0;
  static const largeIconSize = 28.0;
  static const tileLeading = 44.0;
  static const cardRadius = 20.0;
  static const panelRadius = 24.0;
  static const referenceControlRadius = 16.0;
  static const artworkDecodeLimit = 1024;
  static const overviewTitleSize = 18.0;
  static const overviewValueSize = 14.0;
  static const profileNameSize = 22.0;
  static const referenceHomeExpanded = 116.0;
  static const referenceHomeCollapsed = 60.0;
  static const referenceAccountExpanded = 280.0;
  static const referenceAccountCollapsed = 72.0;
  static const bankCardWidth = 80.0;
  static const bankCardHeight = 52.0;
  static const controlRadius = 14.0;
  static const pillRadius = 100.0;
  static const borderWidth = 1.0;
  static const readableWidth = 1080.0;
  static const narrowBreakpoint = 400.0;
  static const largeTextThreshold = 1.4;
  static const gridBreakpoint = 650.0;
  static const navigationHeight = 56.0;
  static const bottomNavigationHeight = 68.0;
  static const chartHeight = 168.0;
  static const chartBarWidth = 28.0;
  static const chartBarGap = 10.0;
  static const chartGridCount = 4;
  static const rankedBarHeight = 8.0;
  static const headerExpanded = 144.0;
  static const headerBalanceTop = 60.0;
  static const compactHeaderExpanded = 96.0;
  static const compactHeaderBalanceTop = 32.0;
  static const headerCollapsed = 64.0;
  static const headerLabelsFadeEnd = .2;
  static const headerActionsFadeEnd = .4;
  static const skeletonHeight = 18.0;
  static const progressStroke = 2.0;
  static const transactionHeight = 64.0;
  static const accessibleTransactionHeight = 88.0;
  static const seatSize = 48.0;
  static const quick = Duration(milliseconds: 140);
  static const standard = Duration(milliseconds: 240);
  static const continuity = Duration(milliseconds: 360);
  static const slow = Duration(milliseconds: 500);
  static const movement = Curves.easeOutCubic;
  static const entrance = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;
  static const disabledOpacity = .45;
  static const mutedOpacity = .64;
  static const chartIdleOpacity = .38;
  static const arrow = Icons.arrow_forward_rounded;
  static const back = Icons.arrow_back_rounded;
  static const chevron = Icons.chevron_right_rounded;
  static const success = Icons.check_circle_outline_rounded;
  static const error = Icons.error_outline_rounded;
  static const empty = Icons.inbox_outlined;
  static const info = Icons.info_outline_rounded;

  static double space(DsSpace value) => switch (value) {
    DsSpace.none => 0,
    DsSpace.tight => unit,
    DsSpace.compact => unit * 2,
    DsSpace.regular => unit * 3,
    DsSpace.section => sectionGap,
    DsSpace.page => unit * 6,
  };

  static double pagePadding(BuildContext context) =>
      MediaQuery.sizeOf(context).width < narrowBreakpoint
      ? compactPageInset
      : pageInset;

  static bool compactTypography(
    BuildContext context,
    BoxConstraints constraints,
  ) =>
      constraints.maxWidth < narrowBreakpoint &&
      MediaQuery.textScalerOf(context).scale(1) > largeTextThreshold;

  static EdgeInsets inset(BuildContext context, DsInset value) =>
      switch (value) {
        DsInset.none => EdgeInsets.zero,
        DsInset.page => EdgeInsets.all(pagePadding(context)),
        DsInset.horizontal => EdgeInsets.symmetric(
          horizontal: pagePadding(context),
        ),
        DsInset.card => const EdgeInsets.all(cardInset),
        DsInset.compact => const EdgeInsets.all(compactInset),
        DsInset.section => const EdgeInsets.symmetric(vertical: sectionGap),
        DsInset.listHeader => EdgeInsets.symmetric(
          horizontal: pagePadding(context),
          vertical: unit * 2,
        ),
      };

  static Duration duration(BuildContext context, Duration normal) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : normal;

  static double transactionExtent(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    if (scale <= largeTextThreshold) return transactionHeight * scale;
    // Multiline title and amount replace the trailing column at large text
    // sizes. The loaded row and its evicted placeholder share this geometry.
    return accessibleTransactionHeight * scale + controlHeight * (scale - 1);
  }
}
