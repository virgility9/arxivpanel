/// Design tokens ported from `src/index.css` and `src/context/ThemeContext.tsx`.
///
/// The React app drives its look with CSS variables (`--bg`, `--surface`,
/// `--accent`, …). This file is the Dart equivalent: resolved color palettes
/// for each mode + accent combination, plus a Material 3 [ThemeData] builder.
library;

import 'package:flutter/material.dart';

/// Light / dark color mode (mirrors `Mode` in ThemeContext.tsx).
enum AppMode { dark, light }

/// Accent choices (mirrors `Accent` in ThemeContext.tsx).
enum AppAccent { terracotta, gold, violet, teal, coral, sage }

/// Text size choices (mirrors `FontScale` in ThemeContext.tsx).
enum AppFontScale { compact, normal, large }

extension AppFontScaleX on AppFontScale {
  /// Base font size in logical pixels (13 / 15 / 17 in the web app).
  double get baseSize {
    switch (this) {
      case AppFontScale.compact:
        return 13;
      case AppFontScale.normal:
        return 15;
      case AppFontScale.large:
        return 17;
    }
  }

  /// Multiplier relative to the default 15px base.
  double get scale => baseSize / 15.0;

  String get label {
    switch (this) {
      case AppFontScale.compact:
        return 'Compact';
      case AppFontScale.normal:
        return 'Normal';
      case AppFontScale.large:
        return 'Large';
    }
  }
}

/// One accent palette (mirrors `ACCENT_PALETTES`).
class AccentPalette {
  const AccentPalette({
    required this.label,
    required this.swatch,
    required this.accent,
    required this.accentDim,
    required this.accentFg,
    required this.accent2,
  });

  final String label;
  final Color swatch;
  final Color accent;
  final Color accentDim;
  final Color accentFg;
  final Color accent2;

  /// A quiet tint of the accent (selected rows, soft fills). Deliberately
  /// low-alpha: the design uses tint + soft shadow, never a glow.
  Color get glow => accent.withValues(alpha: 0.10);

  // Every accent is a muted, earthy tone. The default (terracotta) is the one
  // deliberate pop of personality against the neutral corporate palette; the
  // others are kept (same names) so the Settings choices still exist.
  static const terracotta = AccentPalette(
    label: 'Terracotta',
    swatch: Color(0xFFBF6244),
    accent: Color(0xFFBF6244),
    accentDim: Color(0xFFA64E33),
    accentFg: Color(0xFFFFFFFF),
    accent2: Color(0xFF6F7C94),
  );
  static const gold = AccentPalette(
    label: 'Gold',
    swatch: Color(0xFFC49A3C),
    accent: Color(0xFFC49A3C),
    accentDim: Color(0xFFA37E27),
    accentFg: Color(0xFF1A1710),
    accent2: Color(0xFF6F7C94),
  );
  static const violet = AccentPalette(
    label: 'Violet',
    swatch: Color(0xFF8574A6),
    accent: Color(0xFF8574A6),
    accentDim: Color(0xFF6A5A8A),
    accentFg: Color(0xFFFFFFFF),
    accent2: Color(0xFF6F7C94),
  );
  static const teal = AccentPalette(
    label: 'Teal',
    swatch: Color(0xFF4F9A93),
    accent: Color(0xFF4F9A93),
    accentDim: Color(0xFF3B7C76),
    accentFg: Color(0xFFFFFFFF),
    accent2: Color(0xFF6F7C94),
  );
  static const coral = AccentPalette(
    label: 'Coral',
    swatch: Color(0xFFD07A6E),
    accent: Color(0xFFD07A6E),
    accentDim: Color(0xFFB45F54),
    accentFg: Color(0xFFFFFFFF),
    accent2: Color(0xFF6F7C94),
  );
  static const sage = AccentPalette(
    label: 'Sage',
    swatch: Color(0xFF7D8F5C),
    accent: Color(0xFF7D8F5C),
    accentDim: Color(0xFF64754A),
    accentFg: Color(0xFFFFFFFF),
    accent2: Color(0xFF6F7C94),
  );

  static AccentPalette of(AppAccent accent) {
    switch (accent) {
      case AppAccent.terracotta:
        return terracotta;
      case AppAccent.gold:
        return gold;
      case AppAccent.violet:
        return violet;
      case AppAccent.teal:
        return teal;
      case AppAccent.coral:
        return coral;
      case AppAccent.sage:
        return sage;
    }
  }
}

/// Resolved color set for a mode (mirrors the `MODES` record).
class AppColors {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.borderFaint,
    required this.text,
    required this.textSub,
    required this.muted,
    required this.faint,
    required this.fainter,
    required this.inputBg,
    required this.shadow,
    required this.overlay,
  });

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color borderFaint;
  final Color text;
  final Color textSub;
  final Color muted;
  final Color faint;
  final Color fainter;
  final Color inputBg;
  final Color shadow;
  final Color overlay;

  Color get navBg => bg.withValues(alpha: 0.96);

  /// Soft, layered card shadow: a tight contact shadow plus a wide, faint
  /// ambient one. Reads as paper resting on a desk, not a floating glow.
  List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: shadow.withValues(alpha: shadow.a * 0.55),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
        BoxShadow(
          color: shadow.withValues(alpha: shadow.a * 0.35),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];

  /// Slightly stronger shadow for popovers, menus and toasts.
  List<BoxShadow> get raisedShadow => [
        BoxShadow(
          color: shadow.withValues(alpha: shadow.a * 0.6),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: shadow,
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ];

  // Warm charcoal instead of blue-black; paper-white instead of pure white.
  static const dark = AppColors(
    bg: Color(0xFF16171A),
    surface: Color(0xFF1E1F23),
    surface2: Color(0xFF27292E),
    border: Color(0xFF34363C),
    borderFaint: Color(0xFF27292E),
    text: Color(0xFFEAE6DE),
    textSub: Color(0xFFBAB5AA),
    muted: Color(0xFF93908A),
    faint: Color(0xFF6F6D69),
    fainter: Color(0xFF4A4B4F),
    inputBg: Color(0xFF191A1D),
    shadow: Color(0x66000000),
    overlay: Color(0xCC0E0F11),
  );

  static const light = AppColors(
    bg: Color(0xFFF3F1EC),
    surface: Color(0xFFFCFBF8),
    surface2: Color(0xFFEBE8E1),
    border: Color(0xFFD9D5CB),
    borderFaint: Color(0xFFE8E4DC),
    text: Color(0xFF1F2124),
    textSub: Color(0xFF454A50),
    muted: Color(0xFF6F6B63),
    faint: Color(0xFF9A958B),
    fainter: Color(0xFFCFCABF),
    inputBg: Color(0xFFF7F5F0),
    shadow: Color(0x262B2118),
    overlay: Color(0x99121316),
  );

  static AppColors of(AppMode mode) => mode == AppMode.dark ? dark : light;
}

/// Full resolved theme: mode colors + accent palette.
class AppPalette {
  const AppPalette({
    required this.mode,
    required this.accent,
    this.textScale = 1.0,
  });

  final AppMode mode;
  final AccentPalette accent;

  /// Multiplier applied to custom typography helpers (mirrors the web app's
  /// font-size setting). Defaults to 1.0; [ThemeProvider] sets it from the
  /// user's chosen [AppFontScale].
  final double textScale;

  AppColors get c => AppColors.of(mode);
  bool get isDark => mode == AppMode.dark;

  /// Status colors used by the admin panel.
  Color get success => const Color(0xFF5E9E6E);
  Color get danger => const Color(0xFFC75B52);
  Color get info => const Color(0xFF6F7C94);
}

/// Builds a Material 3 [ThemeData] matching the design tokens.
ThemeData buildThemeData(AppPalette palette, {required double textScale}) {
  final c = palette.c;
  final a = palette.accent;
  final isDark = palette.isDark;

  final scheme = ColorScheme(
    brightness: isDark ? Brightness.dark : Brightness.light,
    primary: a.accent,
    onPrimary: a.accentFg,
    secondary: a.accent2,
    onSecondary: isDark ? Colors.white : Colors.black,
    surface: c.surface,
    onSurface: c.text,
    surfaceContainerHighest: c.surface2,
    error: const Color(0xFFC75B52),
    onError: Colors.white,
    outline: c.border,
  );

  TextStyle baseText(TextStyle s) =>
      s.copyWith(fontSize: (s.fontSize ?? 14) * textScale);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    splashFactory: InkRipple.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: c.navBg,
      foregroundColor: c.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.border),
      ),
    ),
    dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.inputBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      hintStyle: TextStyle(color: c.faint, fontSize: 15 * textScale),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: a.accent),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFC75B52)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFC75B52)),
      ),
    ),
    // Plain text / outlined buttons follow the same scale as GoldButton and
    // GhostButton (see _ButtonSpec in widgets/shared.dart): 44px high, 10px
    // radius, and shrink-wrapped so Flutter doesn't silently grow them to a
    // 48px layout box on touch devices.
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: a.accent,
        minimumSize: const Size(0, 44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: TextStyle(
          fontSize: 14 * textScale,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.text,
        side: BorderSide(color: c.border),
        minimumSize: const Size(0, 44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: TextStyle(
          fontSize: 14 * textScale,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: c.border),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.surface2,
      contentTextStyle: TextStyle(color: c.text, fontSize: 14 * textScale),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: c.border),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: c.navBg,
      selectedItemColor: a.accent,
      unselectedItemColor: c.muted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: a.accent,
      unselectedLabelColor: c.muted,
      indicatorColor: a.accent,
      indicatorSize: TabBarIndicatorSize.label,
    ),
    textTheme: TextTheme(
      displayLarge: baseText(
        const TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.02),
      ),
      displayMedium: baseText(
        const TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.02),
      ),
      titleLarge: baseText(const TextStyle(fontWeight: FontWeight.w600)),
      titleMedium: baseText(const TextStyle(fontWeight: FontWeight.w600)),
      bodyLarge: baseText(const TextStyle()),
      bodyMedium: baseText(const TextStyle()),
      bodySmall: baseText(const TextStyle()),
      labelLarge: baseText(const TextStyle(fontWeight: FontWeight.w600)),
      labelSmall: baseText(const TextStyle(letterSpacing: 0.08)),
    ).apply(bodyColor: c.text, displayColor: c.text),
  );
}
