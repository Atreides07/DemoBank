import 'package:flutter/material.dart';

import 'tokens.dart';

/// Brand changes occur at the application boundary, not in feature widgets.
enum DsBrand { bank, fines }

@immutable
class DsPalette extends ThemeExtension<DsPalette> {
  const DsPalette({
    required this.background,
    required this.surface,
    required this.raised,
    required this.ink,
    required this.muted,
    required this.border,
    required this.accent,
    required this.onAccent,
    required this.link,
    required this.highlight,
    required this.navy,
    required this.onNavy,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final Color background;
  final Color surface;
  final Color raised;
  final Color ink;
  final Color muted;
  final Color border;
  final Color accent;
  final Color onAccent;
  final Color link;
  final Color highlight;
  final Color navy;
  final Color onNavy;
  final Color success;
  final Color warning;
  final Color danger;

  static DsPalette of(BuildContext context) =>
      Theme.of(context).extension<DsPalette>()!;

  Color tone(DsTone value) => switch (value) {
    DsTone.primary => ink,
    DsTone.muted => muted,
    DsTone.accent => link,
    DsTone.success => success,
    DsTone.warning => warning,
    DsTone.danger => danger,
    DsTone.inverse => onNavy,
  };

  @override
  DsPalette copyWith({
    Color? background,
    Color? surface,
    Color? raised,
    Color? ink,
    Color? muted,
    Color? border,
    Color? accent,
    Color? onAccent,
    Color? link,
    Color? highlight,
    Color? navy,
    Color? onNavy,
    Color? success,
    Color? warning,
    Color? danger,
  }) => DsPalette(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    raised: raised ?? this.raised,
    ink: ink ?? this.ink,
    muted: muted ?? this.muted,
    border: border ?? this.border,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    link: link ?? this.link,
    highlight: highlight ?? this.highlight,
    navy: navy ?? this.navy,
    onNavy: onNavy ?? this.onNavy,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
  );

  @override
  DsPalette lerp(covariant DsPalette? other, double t) {
    if (other == null) return this;
    return DsPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      border: Color.lerp(border, other.border, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      link: Color.lerp(link, other.link, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      navy: Color.lerp(navy, other.navy, t)!,
      onNavy: Color.lerp(onNavy, other.onNavy, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

abstract final class DsAppTheme {
  // ThemeData is immutable. Reuse each of the four variants so unrelated host
  // notifications cannot look like theme changes to AnimatedTheme: extensions
  // and state-property callbacks otherwise receive a new identity every time.
  static final Map<(Brightness, DsBrand), ThemeData> _themes = {};

  static ThemeData light({DsBrand brand = DsBrand.bank}) =>
      _resolve(Brightness.light, brand);
  static ThemeData dark({DsBrand brand = DsBrand.bank}) =>
      _resolve(Brightness.dark, brand);

  static ThemeData _resolve(Brightness brightness, DsBrand brand) =>
      _themes[(brightness, brand)] ??= _build(brightness, brand);

  static ThemeData _build(Brightness brightness, DsBrand brand) {
    final dark = brightness == Brightness.dark;
    final accent = brand == DsBrand.bank
        ? const Color(0xFFFFDD2D)
        : const Color(0xFFFFC928);
    final palette = DsPalette(
      background: dark ? const Color(0xFF121212) : const Color(0xFFF5F6F7),
      surface: dark ? const Color(0xFF202022) : const Color(0xFFFFFFFF),
      raised: dark ? const Color(0xFF2C2C2E) : const Color(0xFFEBEEF2),
      ink: dark ? const Color(0xFFF5F5F6) : const Color(0xFF222222),
      muted: dark ? const Color(0xFFA8AAAD) : const Color(0xFF666B73),
      border: dark ? const Color(0xFF3B3D40) : const Color(0xFFE3E6EA),
      accent: accent,
      onAccent: const Color(0xFF222222),
      link: dark ? const Color(0xFF80B8FF) : const Color(0xFF0664D8),
      highlight: accent,
      navy: const Color(0xFF292A2E),
      onNavy: const Color(0xFFFFFFFF),
      success: dark ? const Color(0xFF75D9A1) : const Color(0xFF197446),
      warning: dark ? const Color(0xFFFFCE70) : const Color(0xFF8D5900),
      danger: dark ? const Color(0xFFFF9CA8) : const Color(0xFFC42640),
    );
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      surface: palette.surface,
      primary: palette.accent,
      onPrimary: palette.onAccent,
      error: palette.danger,
    );
    final textTheme = const TextTheme(
      displayLarge: TextStyle(
        fontSize: 34,
        height: 1.12,
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
      ),
      headlineLarge: TextStyle(
        fontSize: 26,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -.8,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -.5,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w700,
        letterSpacing: -.3,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(fontSize: 15, height: 1.4),
      bodyMedium: TextStyle(fontSize: 14, height: 1.4),
      labelLarge: TextStyle(
        fontSize: 14,
        height: 1.3,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        height: 1.35,
        fontWeight: FontWeight.w600,
      ),
      bodySmall: TextStyle(fontSize: 12, height: 1.4),
    ).apply(fontFamily: 'packages/design_system/DsSans');
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(DsTokens.controlRadius),
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'packages/design_system/DsSans',
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      textTheme: textTheme.apply(
        bodyColor: palette.ink,
        displayColor: palette.ink,
      ),
      extensions: [palette],
      splashFactory: InkRipple.splashFactory,
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: DsTokens.borderWidth,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: palette.ink,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: palette.ink),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(DsTokens.touchTarget, DsTokens.controlHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: DsTokens.cardInset,
            vertical: DsTokens.compactInset,
          ),
          shape: shape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.link,
          backgroundColor: palette.raised,
          minimumSize: const Size(DsTokens.touchTarget, DsTokens.controlHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: DsTokens.cardInset,
            vertical: DsTokens.compactInset,
          ),
          shape: shape,
          side: BorderSide.none,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.link,
          minimumSize: const Size(DsTokens.touchTarget, DsTokens.touchTarget),
          shape: shape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.link,
        selectionColor: palette.link.withValues(alpha: .16),
        selectionHandleColor: palette.link,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: palette.link),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: WidgetStateTextStyle.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.error)
                ? palette.danger
                : palette.muted,
          ),
        ),
        floatingLabelStyle: WidgetStateTextStyle.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.error)
                ? palette.danger
                : states.contains(WidgetState.focused)
                ? palette.link
                : palette.muted,
          ),
        ),
        filled: true,
        fillColor: palette.raised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DsTokens.cardInset,
          vertical: DsTokens.compactInset,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DsTokens.controlRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DsTokens.controlRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DsTokens.controlRadius),
          borderSide: BorderSide(
            color: palette.link,
            width: DsTokens.borderWidth * 2,
          ),
        ),
        errorMaxLines: 4,
      ),
      iconTheme: IconThemeData(color: palette.ink, size: DsTokens.iconSize),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        height: DsTokens.bottomNavigationHeight,
        surfaceTintColor: Colors.transparent,
        indicatorColor: palette.accent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? palette.ink
                : palette.muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? palette.onAccent
                : palette.muted,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surface,
        selectedColor: palette.accent,
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DsTokens.pillRadius),
        ),
        labelStyle: textTheme.labelLarge?.copyWith(color: palette.ink),
        padding: const EdgeInsets.symmetric(
          horizontal: DsTokens.compactInset,
          vertical: DsTokens.unit * 2,
        ),
      ),
    );
  }
}

extension DsContext on BuildContext {
  DsPalette get dsPalette => DsPalette.of(this);
}
