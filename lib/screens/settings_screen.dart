/// Settings screen ported from `src/components/SettingsView.tsx`.
///
/// Theme controls (color mode, accent color, text size) write through
/// [ThemeProvider.update]; the provider notifies and the root MaterialApp
/// rebuilds with the new [ThemeData], so changes apply live.
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/shared.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.theme});

  final ThemeProvider theme;

  // -- Section label ---------------------------------------------------------
  // Mirrors the `Section` component: mono 9px, letterspaced, muted, faint
  // bottom border.
  Widget _section(AppPalette p, String title) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 14),
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.c.borderFaint)),
      ),
      child: Text(
        title.toUpperCase(),
        style: monoStyle(p, size: 9, weight: FontWeight.w600, letterSpacing: 0.15),
      ),
    );
  }

  // -- Group title ("Color Mode" / "Accent Color" / "Text Size") ---------------
  Widget _groupTitle(AppPalette p, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        title,
        style: bodyStyle(p, size: 14, weight: FontWeight.w500, color: p.c.textSub),
      ),
    );
  }

  // -- Color mode card (dark / light) -----------------------------------------
  Widget _modeCard(AppPalette p, AppMode mode) {
    final c = p.c;
    final a = p.accent;
    final active = theme.mode == mode;
    final dark = mode == AppMode.dark;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => theme.update(mode: mode),
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: active ? c.surface : Colors.transparent,
              border: Border.all(color: active ? a.accent : c.border, width: 1.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Text(dark ? '🌙' : '☀️', style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dark ? 'Dark Mode' : 'Light Mode',
                        style: bodyStyle(
                          p,
                          size: 14,
                          weight: FontWeight.w600,
                          color: active ? a.accent : c.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dark ? 'Easy on the eyes at night' : 'Bright & crisp for daytime',
                        style: monoStyle(p, size: 10),
                      ),
                    ],
                  ),
                ),
                // Check badge slot is always laid out (transparent when
                // inactive) so selecting a mode never re-wraps the text or
                // resizes the cards.
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? a.accent : Colors.transparent,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '✓',
                    style: TextStyle(
                      fontSize: 9,
                      color: active ? a.accentFg : Colors.transparent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -- Accent color option -----------------------------------------------------
  Widget _accentOption(AppPalette p, AppAccent option, double width) {
    final c = p.c;
    final pal = AccentPalette.of(option);
    final active = theme.accent == option;
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => theme.update(accent: option),
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: active ? pal.swatch.withValues(alpha: 0.09) : c.surface,
              border: Border.all(
                color: active ? pal.swatch : c.border,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: pal.swatch,
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: pal.swatch.withValues(alpha: 0.33),
                              blurRadius: 16,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  pal.label,
                  style: monoStyle(
                    p,
                    size: 10,
                    letterSpacing: 0.04,
                    color: active ? pal.swatch : c.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -- Text size segmented control ----------------------------------------------
  Widget _fontScaleSegment(AppPalette p, AppFontScale scale) {
    final c = p.c;
    final a = p.accent;
    final active = theme.fontScale == scale;
    return Expanded(
      child: Material(
        color: active ? a.accent : Colors.transparent,
        child: InkWell(
          onTap: () => theme.update(fontScale: scale),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Aa',
                  style: displayStyle(
                    p,
                    size: scale.baseSize,
                    weight: FontWeight.w600,
                    color: active ? a.accentFg : c.text,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  scale.label,
                  style: monoStyle(
                    p,
                    size: 9,
                    letterSpacing: 0.04,
                    color: active ? a.accentFg : c.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;
    final c = p.c;
    final a = p.accent;

    return Scaffold(
      backgroundColor: c.bg,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'PREFERENCES',
                      style: monoStyle(p, size: 9, letterSpacing: 0.15, color: a.accent),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Settings',
                      style: displayStyle(p, size: 28, weight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    'Customize your reading experience',
                    style: bodyStyle(p, size: 14, color: c.muted),
                  ),
                ],
              ),
            ),

            // Content (maxWidth 640, centered)
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Appearance
                      _section(p, 'Appearance'),

                      // Color Mode
                      _groupTitle(p, 'Color Mode'),
                      // Color Mode — IntrinsicHeight + stretch keeps both cards
                      // at identical height in either mode.
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _modeCard(p, AppMode.dark),
                            const SizedBox(width: 10),
                            _modeCard(p, AppMode.light),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Accent Color
                      _groupTitle(p, 'Accent Color'),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final w = (constraints.maxWidth - 20) / 3;
                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: AppAccent.values
                                .map((option) => _accentOption(p, option, w))
                                .toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 32),

                      // Text Size
                      _groupTitle(p, 'Text Size'),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: c.surface,
                            border: Border.all(color: c.border),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: AppFontScale.values
                                .map((scale) => _fontScaleSegment(p, scale))
                                .toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // About
                      _section(p, 'About'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                        decoration: BoxDecoration(
                          color: c.surface,
                          border: Border.all(color: c.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            AppLogo(palette: p, fontSize: 17),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Research Library · v1.0',
                                    style: monoStyle(p, size: 10, letterSpacing: 0.04),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
