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
enum AppAccent { gold, violet, teal, coral, sage }

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

  Color get glow => accent.withValues(alpha: 0.15);

  static const gold = AccentPalette(
    label: 'Gold',
    swatch: Color(0xFFE8B04B),
    accent: Color(0xFFE8B04B),
    accentDim: Color(0xFFB8862A),
    accentFg: Color(0xFF0C0C12),
    accent2: Color(0xFF7C6AF7),
  );
  static const violet = AccentPalette(
    label: 'Violet',
    swatch: Color(0xFF7C6AF7),
    accent: Color(0xFF7C6AF7),
    accentDim: Color(0xFF5A48D4),
    accentFg: Color(0xFFFFFFFF),
    accent2: Color(0xFFE8B04B),
  );
  static const teal = AccentPalette(
    label: 'Teal',
    swatch: Color(0xFF2DD4BF),
    accent: Color(0xFF2DD4BF),
    accentDim: Color(0xFF0D9488),
    accentFg: Color(0xFF0C0C12),
    accent2: Color(0xFF7C6AF7),
  );
  static const coral = AccentPalette(
    label: 'Coral',
    swatch: Color(0xFFF87171),
    accent: Color(0xFFF87171),
    accentDim: Color(0xFFEF4444),
    accentFg: Color(0xFFFFFFFF),
    accent2: Color(0xFF7C6AF7),
  );
  static const sage = AccentPalette(
    label: 'Sage',
    swatch: Color(0xFF6DB98A),
    accent: Color(0xFF6DB98A),
    accentDim: Color(0xFF4A9168),
    accentFg: Color(0xFF0C0C12),
    accent2: Color(0xFF7C6AF7),
  );

  static AccentPalette of(AppAccent accent) {
    switch (accent) {
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

  static const dark = AppColors(
    bg: Color(0xFF0C0C12),
    surface: Color(0xFF14141E),
    surface2: Color(0xFF1C1C2A),
    border: Color(0xFF2A2A3A),
    borderFaint: Color(0xFF1C1C2A),
    text: Color(0xFFE4DFD0),
    textSub: Color(0xFFB0A898),
    muted: Color(0xFF7A7690),
    faint: Color(0xFF5A5668),
    fainter: Color(0xFF3A3A50),
    inputBg: Color(0xFF0C0C12),
    shadow: Color(0x8C000000),
    overlay: Color(0xCC000000),
  );

  static const light = AppColors(
    bg: Color(0xFFF4F0E6),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEDE8DE),
    border: Color(0xFFD8D0C4),
    borderFaint: Color(0xFFEDE8DE),
    text: Color(0xFF1A1614),
    textSub: Color(0xFF3A3028),
    muted: Color(0xFF8A7A68),
    faint: Color(0xFFB0A090),
    fainter: Color(0xFFD4CCC0),
    inputBg: Color(0xFFF8F4EC),
    shadow: Color(0x1F000000),
    overlay: Color(0x99000000),
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
  Color get success => const Color(0xFF4ADE80);
  Color get danger => const Color(0xFFE06B6B);
  Color get info => const Color(0xFF7C6AF7);
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
    error: const Color(0xFFE06B6B),
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
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: c.border),
      ),
    ),
    dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.inputBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintStyle: TextStyle(color: c.faint, fontSize: 15 * textScale),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: a.accent),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE06B6B)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE06B6B)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: a.accent),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
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
