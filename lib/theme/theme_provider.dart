/// Theme state ported from `src/context/ThemeContext.tsx`.
///
/// Holds the current [AppMode], [AppAccent] and [AppFontScale], exposes the
/// resolved [AppPalette] and the Material 3 [ThemeData], and notifies
/// listeners on change (mirrors `updateSettings`).
library;

import 'package:flutter/material.dart';

import 'app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeProvider({
    AppMode mode = AppMode.dark,
    AppAccent accent = AppAccent.gold,
    AppFontScale fontScale = AppFontScale.normal,
  })  : _mode = mode,
        _accent = accent,
        _fontScale = fontScale;

  AppMode _mode;
  AppAccent _accent;
  AppFontScale _fontScale;

  AppMode get mode => _mode;
  AppAccent get accent => _accent;
  AppFontScale get fontScale => _fontScale;

  /// Resolved color palette for the current mode + accent, including the
  /// user's text-size scale so the custom typography helpers scale too.
  AppPalette get palette => AppPalette(
        mode: _mode,
        accent: AccentPalette.of(_accent),
        textScale: _fontScale.scale,
      );

  /// Material 3 theme built from the resolved palette.
  ThemeData get themeData => buildThemeData(palette, textScale: _fontScale.scale);

  /// Mirrors `updateSettings(patch)` from the React context.
  void update({AppMode? mode, AppAccent? accent, AppFontScale? fontScale}) {
    var changed = false;
    if (mode != null && mode != _mode) {
      _mode = mode;
      changed = true;
    }
    if (accent != null && accent != _accent) {
      _accent = accent;
      changed = true;
    }
    if (fontScale != null && fontScale != _fontScale) {
      _fontScale = fontScale;
      changed = true;
    }
    if (changed) notifyListeners();
  }
}
