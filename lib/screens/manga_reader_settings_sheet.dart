/// Manga reader settings sheet (Tachiyomi-style bottom sheet, three
/// tabs: Reading mode / General / Custom filter). Settings are per
/// series and save on every tap — there is no Save button. What
/// Tachiyomi has that v1 does not (crop borders, split wide pages,
/// keep screen on, vertical navigator) is deliberately absent here —
/// see `arxivpanel_reader_settings_design.md`.
library;

import 'package:flutter/material.dart';

import '../models/reader_settings.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/reader_settings_widgets.dart';
import '../widgets/shared.dart';

Future<void> showMangaReaderSettingsSheet({
  required BuildContext context,
  required AppState appState,
  required ThemeProvider theme,
}) {
  return showReaderSettingsSheet(
    context: context,
    theme: theme,
    child: _MangaReaderSettingsSheet(appState: appState, theme: theme),
  );
}

class _MangaReaderSettingsSheet extends StatelessWidget {
  const _MangaReaderSettingsSheet({
    required this.appState,
    required this.theme,
  });

  final AppState appState;
  final ThemeProvider theme;

  void _set(MangaReaderSettings Function(MangaReaderSettings s) update) {
    appState.setMangaReaderSettings(update(appState.mangaReaderSettings));
  }

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;
    final c = p.c;
    final a = p.accent;
    return DefaultTabController(
      length: 3,
      child: AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          final s = appState.mangaReaderSettings;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TabBar(
                labelColor: a.accent,
                unselectedLabelColor: c.muted,
                indicatorColor: a.accent,
                tabs: const [
                  Tab(text: 'Reading mode'),
                  Tab(text: 'General'),
                  Tab(text: 'Custom filter'),
                ],
              ),
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.62,
                child: TabBarView(
                  children: [
                    _readingModeTab(p, s),
                    _generalTab(p, s),
                    _customFilterTab(p, s),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tabScroll(Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: child,
    );
  }

  Widget _readingModeTab(AppPalette p, MangaReaderSettings s) {
    return _tabScroll(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'For this series',
            style: bodyStyle(p, size: 13, color: p.c.faint),
          ),
          const SizedBox(height: 16),
          ReaderSection(
            palette: p,
            title: 'Reading mode',
            child: ReaderOptionRow(
              children: [
                for (final e in MangaReadingMode.values)
                  ReaderOptionPill(
                    palette: p,
                    label: _readingModeLabel(e),
                    selected: s.readingMode == e,
                    onTap: () => _set((v) => v.copyWith(readingMode: e)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ReaderSection(
            palette: p,
            title: 'Rotation',
            child: ReaderOptionRow(
              children: [
                for (final e in ReaderRotation.values)
                  ReaderOptionPill(
                    palette: p,
                    label: _rotationLabel(e),
                    selected: s.rotation == e,
                    onTap: () => _set((v) => v.copyWith(rotation: e)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ReaderSection(
            palette: p,
            title: 'Tap zones',
            child: ReaderOptionRow(
              children: [
                for (final e in TapZones.values)
                  ReaderOptionPill(
                    palette: p,
                    label: _tapZonesLabel(e),
                    selected: s.tapZones == e,
                    onTap: () => _set((v) => v.copyWith(tapZones: e)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ReaderSection(
            palette: p,
            title: 'Invert tap zones',
            child: ReaderOptionRow(
              children: [
                for (final e in InvertTapZones.values)
                  ReaderOptionPill(
                    palette: p,
                    label: _invertLabel(e),
                    selected: s.invertTapZones == e,
                    onTap: () => _set((v) => v.copyWith(invertTapZones: e)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ReaderSection(
            palette: p,
            title: 'Scale type',
            child: ReaderOptionRow(
              children: [
                for (final e in MangaScaleType.values)
                  ReaderOptionPill(
                    palette: p,
                    label: _scaleLabel(e),
                    selected: s.scaleType == e,
                    onTap: () => _set((v) => v.copyWith(scaleType: e)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _generalTab(AppPalette p, MangaReaderSettings s) {
    return _tabScroll(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReaderSection(
            palette: p,
            title: 'Background color',
            child: ReaderOptionRow(
              children: [
                for (final e in ReaderBackground.values)
                  ReaderOptionPill(
                    palette: p,
                    label: _backgroundLabel(e),
                    selected: s.background == e,
                    onTap: () => _set((v) => v.copyWith(background: e)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ReaderCheckRow(
            palette: p,
            label: 'Show page number',
            value: s.showPageNumber,
            onChanged: (v) => _set((s) => s.copyWith(showPageNumber: v)),
          ),
          ReaderCheckRow(
            palette: p,
            label: 'Fullscreen',
            value: s.fullscreen,
            onChanged: (v) => _set((s) => s.copyWith(fullscreen: v)),
          ),
          ReaderCheckRow(
            palette: p,
            label: 'Show actions on long tap',
            value: s.showActionsOnLongTap,
            onChanged: (v) =>
                _set((s) => s.copyWith(showActionsOnLongTap: v)),
          ),
          ReaderCheckRow(
            palette: p,
            label: 'Animate page transitions',
            value: s.animateTransitions,
            onChanged: (v) => _set((s) => s.copyWith(animateTransitions: v)),
          ),
        ],
      ),
    );
  }

  Widget _customFilterTab(AppPalette p, MangaReaderSettings s) {
    return _tabScroll(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReaderCheckRow(
            palette: p,
            label: 'Custom brightness',
            value: s.brightnessEnabled,
            onChanged: (v) => _set((s) => s.copyWith(brightnessEnabled: v)),
          ),
          const SizedBox(height: 8),
          ReaderSliderRow(
            palette: p,
            label: 'Custom brightness',
            value: s.brightness,
            min: 0,
            max: 100,
            divisions: 20,
            valueLabel: '${s.brightness.round()}',
            onChanged: s.brightnessEnabled
                ? (v) => _set((s) => s.copyWith(brightness: v))
                : null,
          ),
          const SizedBox(height: 20),
          ReaderCheckRow(
            palette: p,
            label: 'Grayscale',
            value: s.grayscale,
            onChanged: (v) => _set((s) => s.copyWith(grayscale: v)),
          ),
          ReaderCheckRow(
            palette: p,
            label: 'Inverted',
            value: s.inverted,
            onChanged: (v) => _set((s) => s.copyWith(inverted: v)),
          ),
          const SizedBox(height: 20),
          ReaderSection(
            palette: p,
            title: 'Color tint',
            child: ReaderOptionRow(
              children: [
                for (final e in PageTint.values)
                  ReaderOptionPill(
                    palette: p,
                    label: _tintLabel(e),
                    selected: s.tint == e,
                    onTap: () => _set((v) => v.copyWith(tint: e)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _readingModeLabel(MangaReadingMode e) => switch (e) {
    MangaReadingMode.def => 'Default',
    MangaReadingMode.pagedLtr => 'Paged (left to right)',
    MangaReadingMode.pagedRtl => 'Paged (right to left)',
    MangaReadingMode.pagedVertical => 'Paged (vertical)',
    MangaReadingMode.longStrip => 'Long strip',
    MangaReadingMode.longStripGaps => 'Long strip with gaps',
  };

  String _rotationLabel(ReaderRotation e) => switch (e) {
    ReaderRotation.def => 'Default',
    ReaderRotation.free => 'Free',
    ReaderRotation.portrait => 'Portrait',
    ReaderRotation.landscape => 'Landscape',
    ReaderRotation.lockedPortrait => 'Locked portrait',
    ReaderRotation.lockedLandscape => 'Locked landscape',
    ReaderRotation.reversePortrait => 'Reverse portrait',
  };

  String _tapZonesLabel(TapZones e) => switch (e) {
    TapZones.def => 'Default',
    TapZones.rightAndLeft => 'Right and Left',
    TapZones.disabled => 'Disabled',
  };

  String _invertLabel(InvertTapZones e) => switch (e) {
    InvertTapZones.none => 'None',
    InvertTapZones.horizontal => 'Horizontal',
    InvertTapZones.vertical => 'Vertical',
    InvertTapZones.both => 'Both',
  };

  String _scaleLabel(MangaScaleType e) => switch (e) {
    MangaScaleType.fitScreen => 'Fit screen',
    MangaScaleType.stretch => 'Stretch',
    MangaScaleType.fitWidth => 'Fit width',
    MangaScaleType.fitHeight => 'Fit height',
    MangaScaleType.originalSize => 'Original size',
    MangaScaleType.smartFit => 'Smart fit',
  };

  String _backgroundLabel(ReaderBackground e) => switch (e) {
    ReaderBackground.black => 'Black',
    ReaderBackground.gray => 'Gray',
    ReaderBackground.white => 'White',
    ReaderBackground.auto => 'Auto',
  };

  String _tintLabel(PageTint e) => switch (e) {
    PageTint.none => 'None',
    PageTint.sepia => 'Sepia',
    PageTint.warm => 'Warm',
    PageTint.cool => 'Cool',
  };
}
