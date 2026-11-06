/// Theme state ported from `src/context/ThemeContext.tsx`.
///
/// Holds the current [AppMode] and [AppAccent], exposes the
/// resolved [AppPalette] and the Material 3 [ThemeData], and notifies
/// listeners on change (mirrors `updateSettings`).
///
/// Text renders at the Normal scale (textScale 1.0); there is no
/// text-size control.
library;

import 'package:flutter/material.dart';

import 'app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeProvider({
    AppMode mode = AppMode.dark,
    AppAccent accent = AppAccent.gold,
  })  : _mode = mode,
        _accent = accent;

  AppMode _mode;
  AppAccent _accent;

  AppMode get mode => _mode;
  AppAccent get accent => _accent;

  /// Resolved color palette for the current mode + accent.
  AppPalette get palette => AppPalette(
        mode: _mode,
        accent: AccentPalette.of(_accent),
      );

  /// Material 3 theme built from the resolved palette.
  ThemeData get themeData => buildThemeData(palette, textScale: 1.0);

  /// Mirrors `updateSettings(patch)` from the React context.
  void update({AppMode? mode, AppAccent? accent}) {
    var changed = false;
    if (mode != null && mode != _mode) {
      _mode = mode;
      changed = true;
    }
    if (accent != null && accent != _accent) {
      _accent = accent;
      changed = true;
    }
    if (changed) notifyListeners();
  }
}
