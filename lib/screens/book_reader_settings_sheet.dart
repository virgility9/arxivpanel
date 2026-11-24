/// E-book / novel text reader settings sheet: the same sheet style
/// as the manga reader (pill options, check rows, sliders), one set
/// for all books — saved on every tap, no Save button. Font size here
/// is the same setting the A-/A+ buttons change, so it now survives
/// chapter changes (it used to reset to 17 on every chapter).
library;

import 'package:flutter/material.dart';

import '../models/reader_settings.dart';
import '../state/app_state.dart';
import '../theme/theme_provider.dart';
import '../widgets/reader_settings_widgets.dart';

Future<void> showBookReaderSettingsSheet({
  required BuildContext context,
  required AppState appState,
  required ThemeProvider theme,
}) {
  return showReaderSettingsSheet(
    context: context,
    theme: theme,
    child: _BookReaderSettingsSheet(appState: appState, theme: theme),
  );
}

class _BookReaderSettingsSheet extends StatelessWidget {
  const _BookReaderSettingsSheet({
    required this.appState,
    required this.theme,
  });

  final AppState appState;
  final ThemeProvider theme;

  void _set(BookReaderSettings Function(BookReaderSettings s) update) {
    appState.setBookReaderSettings(update(appState.bookReaderSettings));
  }

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final s = appState.bookReaderSettings;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ReaderSliderRow(
                palette: p,
                label: 'Font size',
                value: s.fontSize,
                min: 12,
                max: 28,
                divisions: 16,
                valueLabel: '${s.fontSize.round()}',
                onChanged: (v) => _set((s) => s.copyWith(fontSize: v)),
              ),
              const SizedBox(height: 20),
              ReaderSection(
                palette: p,
                title: 'Font',
                child: ReaderOptionRow(
                  children: [
                    for (final e in BookFontFamily.values)
                      ReaderOptionPill(
                        palette: p,
                        label: _fontLabel(e),
                        selected: s.fontFamily == e,
                        onTap: () => _set((v) => v.copyWith(fontFamily: e)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ReaderSection(
                palette: p,
                title: 'Line height',
                child: ReaderOptionRow(
                  children: [
                    for (final e in BookLineHeight.values)
                      ReaderOptionPill(
                        palette: p,
                        label: _lineHeightLabel(e),
                        selected: s.lineHeight == e,
                        onTap: () => _set((v) => v.copyWith(lineHeight: e)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ReaderSection(
                palette: p,
                title: 'Text align',
                child: ReaderOptionRow(
                  children: [
                    for (final e in BookAlignment.values)
                      ReaderOptionPill(
                        palette: p,
                        label: _alignLabel(e),
                        selected: s.align == e,
                        onTap: () => _set((v) => v.copyWith(align: e)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ReaderSection(
                palette: p,
                title: 'Reading theme',
                child: ReaderOptionRow(
                  children: [
                    for (final e in BookReadingTheme.values)
                      ReaderOptionPill(
                        palette: p,
                        label: _themeLabel(e),
                        selected: s.readingTheme == e,
                        onTap: () =>
                            _set((v) => v.copyWith(readingTheme: e)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ReaderSection(
                palette: p,
                title: 'Margins',
                child: ReaderOptionRow(
                  children: [
                    for (final e in BookMargins.values)
                      ReaderOptionPill(
                        palette: p,
                        label: _marginsLabel(e),
                        selected: s.margins == e,
                        onTap: () => _set((v) => v.copyWith(margins: e)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ReaderCheckRow(
                palette: p,
                label: 'Custom brightness',
                value: s.brightnessEnabled,
                onChanged: (v) =>
                    _set((s) => s.copyWith(brightnessEnabled: v)),
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
            ],
          ),
        );
      },
    );
  }

  String _fontLabel(BookFontFamily e) => switch (e) {
    BookFontFamily.serif => 'Serif',
    BookFontFamily.sans => 'Sans',
    BookFontFamily.mono => 'Mono',
  };

  String _lineHeightLabel(BookLineHeight e) => switch (e) {
    BookLineHeight.compact => 'Compact',
    BookLineHeight.normal => 'Normal',
    BookLineHeight.relaxed => 'Relaxed',
  };

  String _alignLabel(BookAlignment e) => switch (e) {
    BookAlignment.left => 'Left',
    BookAlignment.justify => 'Justified',
  };

  String _themeLabel(BookReadingTheme e) => switch (e) {
    BookReadingTheme.auto => 'Auto',
    BookReadingTheme.paper => 'Paper',
    BookReadingTheme.dark => 'Dark',
    BookReadingTheme.sepia => 'Sepia',
  };

  String _marginsLabel(BookMargins e) => switch (e) {
    BookMargins.narrow => 'Narrow',
    BookMargins.normal => 'Normal',
    BookMargins.wide => 'Wide',
  };
}
