/// Design tokens ported from `src/index.css` and `src/context/ThemeContext.tsx`,
/// revamped according to the 60/30/10 design rule:
/// - 60% Dominant canvas / background base (mood, breathing room, spaciousness)
/// - 30% Secondary structure (surfaces, card containers, side rail, borders, typography)
/// - 10% Accent layer (purposeful focal points: CTAs, active highlights, badges, status)
library;

import 'package:flutter/material.dart';

import '../models/models.dart';

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
/// Forms the 10% accent layer in the 60/30/10 rule.
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

  // 10% ACCENT PRESETS: Carefully tuned for high clarity and contrast
  // against both the 60% canvas and 30% structural surfaces.
  static const terracotta = AccentPalette(
    label: 'Terracotta',
    swatch: Color(0xFFE05638),
    accent: Color(0xFFE05638),
    accentDim: Color(0xFFC04024),
    accentFg: Color(0xFFFFFFFF),
    accent2: Color(0xFF6B7A92),
  );
  static const gold = AccentPalette(
    label: 'Gold',
    swatch: Color(0xFFD99B26),
    accent: Color(0xFFD99B26),
    accentDim: Color(0xFFB57D16),
    accentFg: Color(0xFF181307),
    accent2: Color(0xFF6B7A92),
  );
  static const violet = AccentPalette(
    label: 'Violet',
    swatch: Color(0xFF8B6CE0),
    accent: Color(0xFF8B6CE0),
    accentDim: Color(0xFF6F50C2),
    accentFg: Color(0xFFFFFFFF),
    accent2: Color(0xFF6B7A92),
  );
  static const teal = AccentPalette(
    label: 'Teal',
    swatch: Color(0xFF2BAE9E),
    accent: Color(0xFF2BAE9E),
    accentDim: Color(0xFF1E8C7E),
    accentFg: Color(0xFFFFFFFF),
    accent2: Color(0xFF6B7A92),
  );
  static const coral = AccentPalette(
    label: 'Coral',
    swatch: Color(0xFFF06A58),
    accent: Color(0xFFF06A58),
    accentDim: Color(0xFFD14C3A),
    accentFg: Color(0xFFFFFFFF),
    accent2: Color(0xFF6B7A92),
  );
  static const sage = AccentPalette(
    label: 'Sage',
    swatch: Color(0xFF76A85B),
    accent: Color(0xFF76A85B),
    accentDim: Color(0xFF5A8941),
    accentFg: Color(0xFFFFFFFF),
    accent2: Color(0xFF6B7A92),
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
/// Enforces the 60% dominant canvas and 30% secondary structure layers.
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

  /// 60% DOMINANT: Base canvas / background
  final Color bg;

  /// 30% SECONDARY: Elevated card & panel surface
  final Color surface;

  /// 30% SECONDARY: Nested container & chip surface
  final Color surface2;

  /// 30% SECONDARY: Clear structural border
  final Color border;

  /// 30% SECONDARY: Subtle interior divider
  final Color borderFaint;

  /// 30% SECONDARY: Primary readable text
  final Color text;

  /// 30% SECONDARY: Secondary body text
  final Color textSub;

  /// 30% SECONDARY: Metadata, dates, counts
  final Color muted;

  /// 30% SECONDARY: Tertiary hints
  final Color faint;

  /// 30% SECONDARY: Inactive markers
  final Color fainter;

  /// 30% SECONDARY: Recessed input fill
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

  // ── DARK PALETTE ──
  // 60% Canvas: Deep obsidian slate (0xFF111317)
  // 30% Structure: Elevated surfaces (0xFF191C23 / 0xFF222630), crisp borders & typography
  static const dark = AppColors(
    bg: Color(0xFF111317),
    surface: Color(0xFF191C23),
    surface2: Color(0xFF222630),
    border: Color(0xFF2E3442),
    borderFaint: Color(0xFF232833),
    text: Color(0xFFF1F3F7),
    textSub: Color(0xFFB5BAC6),
    muted: Color(0xFF838B9C),
    faint: Color(0xFF565D6D),
    fainter: Color(0xFF383F4D),
    inputBg: Color(0xFF151820),
    shadow: Color(0x66000000),
    overlay: Color(0xCC0D0E12),
  );

  // ── LIGHT PALETTE ──
  // 60% Canvas: Warm ivory parchment (0xFFF7F6F2)
  // 30% Structure: Crisp white cards (0xFFFFFFFF / 0xFFECEAE3), refined borders & ink typography
  static const light = AppColors(
    bg: Color(0xFFF7F6F2),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFECEAE3),
    border: Color(0xFFDAD6CC),
    borderFaint: Color(0xFFE8E5DD),
    text: Color(0xFF14171C),
    textSub: Color(0xFF3F4452),
    muted: Color(0xFF6B7280),
    faint: Color(0xFF9CA3AF),
    fainter: Color(0xFFD1D5DB),
    inputBg: Color(0xFFFAF9F6),
    shadow: Color(0x1F2B2118),
    overlay: Color(0x99101216),
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

  // ── 10% ACCENT: SEMANTIC FEEDBACK COLORS ──
  Color get success => isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A);
  Color get danger => isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
  Color get warning => isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
  Color get info => isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);

  /// Unified status color mapped directly to the 60/30/10 palette.
  Color statusColor(PaperStatus status) {
    switch (status) {
      case PaperStatus.approved:
        return success;
      case PaperStatus.rejected:
        return danger;
      case PaperStatus.revision:
        return warning;
      case PaperStatus.pending:
        return accent.accent;
      case PaperStatus.archived:
        return c.muted;
    }
  }
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
    error: palette.danger,
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
        borderSide: BorderSide(color: palette.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: palette.danger),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: a.accent),
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
