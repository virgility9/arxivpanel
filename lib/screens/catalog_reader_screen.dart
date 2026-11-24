/// In-app text reader for one catalog chapter: selectable text with
/// reader customization (font size/family, line height, alignment,
/// reading theme, margins, brightness — the settings sheet, same
/// style as the manga reader), prev/next chapter footer, and reading
/// position saved on exit (the detail screen's "Continue reading"
/// resumes it). The system back button returns to the detail screen,
/// same as the back arrow.
library;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../models/reader_settings.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/shared.dart';
import 'book_reader_settings_sheet.dart';

class CatalogReaderScreen extends StatefulWidget {
  const CatalogReaderScreen({
    super.key,
    required this.appState,
    required this.theme,
  });

  final AppState appState;
  final ThemeProvider theme;

  @override
  State<CatalogReaderScreen> createState() => _CatalogReaderScreenState();
}

class _CatalogReaderScreenState extends State<CatalogReaderScreen> {
  final ScrollController _scroll = ScrollController();
  bool _restored = false;

  /// The chapter this State instance is showing. The shell keys the
  /// screen by chapter index, so a chapter change remounts the screen
  /// and the saved position is always written against the chapter that
  /// was actually on screen (the app-wide index has already moved on
  /// by the time dispose runs).
  late final int _chapterIndex;

  @override
  void initState() {
    super.initState();
    _chapterIndex = widget.appState.selectedChapterIndex;
    widget.appState.setInnerBackHandler(_backToDetail);
    widget.appState.ensureBookReaderSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restorePosition());
  }

  @override
  void dispose() {
    _savePosition();
    widget.appState.setInnerBackHandler(null);
    _scroll.dispose();
    super.dispose();
  }

  void _backToDetail() {
    _savePosition();
    widget.appState.navigate(AppView.catalogDetail);
  }

  /// Jumps to the saved position inside this chapter (once). Runs after
  /// the first frame so the scroll extent is known.
  void _restorePosition() {
    if (_restored || !mounted) return;
    _restored = true;
    final progress = widget.appState.catalogProgress;
    final chapter = widget.appState.selectedChapter;
    if (progress == null || chapter == null) return;
    if (progress.lastChapterIndex != _chapterIndex) {
      return;
    }
    if (progress.lastCharOffset <= 0 || chapter.text.isEmpty) return;
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    if (max <= 0) return;
    final fraction =
        (progress.lastCharOffset / chapter.text.length).clamp(0.0, 1.0);
    _scroll.jumpTo(fraction * max);
  }

  /// Saves the scroll fraction as a char offset inside the chapter.
  void _savePosition() {
    if (!_scroll.hasClients) return;
    final appState = widget.appState;
    final chapter = appState.selectedChapter;
    final item = appState.selectedCatalogItem;
    if (chapter == null || item == null || chapter.text.isEmpty) return;
    final max = _scroll.position.maxScrollExtent;
    final fraction =
        max <= 0 ? 0.0 : (_scroll.offset / max).clamp(0.0, 1.0);
    appState.saveCatalogChapterPosition(
      item.id,
      _chapterIndex,
      (fraction * chapter.text.length).round(),
    );
  }

  /// A-/A+ write the same font-size setting the sheet's slider
  /// writes, so the size now survives chapter changes (it used to
  /// reset to 17 on every chapter).
  void _changeFontSize(double delta) {
    final s = widget.appState.bookReaderSettings;
    final next = (s.fontSize + delta).clamp(12.0, 28.0).toDouble();
    widget.appState.setBookReaderSettings(s.copyWith(fontSize: next));
  }

  void _openSettings() {
    showBookReaderSettingsSheet(
      context: context,
      appState: widget.appState,
      theme: widget.theme,
    );
  }

  /// Reading-theme colours. Auto follows the app theme; the rest are
  /// fixed paper/dark/sepia pairs.
  ({Color bg, Color text}) _readingColors(
    BookReaderSettings s,
    AppPalette p,
  ) {
    return switch (s.readingTheme) {
      BookReadingTheme.auto => (bg: p.c.surface, text: p.c.text),
      BookReadingTheme.paper => (
        bg: const Color(0xFFF7F1E3),
        text: const Color(0xFF2A2419),
      ),
      BookReadingTheme.dark => (
        bg: const Color(0xFF121212),
        text: const Color(0xFFE8E2D5),
      ),
      BookReadingTheme.sepia => (
        bg: const Color(0xFFEFE3C8),
        text: const Color(0xFF3A2E1F),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.theme.palette;
    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) {
        final appState = widget.appState;
        final item = appState.selectedCatalogItem;
        final chapter = appState.selectedChapter;
        if (item == null || chapter == null) {
          return Center(
            child: EmptyState(
              palette: p,
              icon: Icons.menu_book,
              title: 'No chapter open',
              sub: 'Pick a chapter from the book to read it here.',
            ),
          );
        }
        final chapters = appState.catalogChapters;
        final index = appState.selectedChapterIndex;
        final s = appState.bookReaderSettings;
        final colors = _readingColors(s, p);
        final textColor = colors.text;
        final faintColor = textColor.withAlpha(150);
        final borderColor = textColor.withAlpha(40);
        final margin = s.marginValue;
        return Container(
          color: colors.bg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: textColor),
                      onPressed: _backToDetail,
                      tooltip: 'Back to book',
                    ),
                    Expanded(
                      child: Text(
                        chapter.title,
                        style: displayStyle(p, size: 16).copyWith(
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GhostButton(
                      palette: p,
                      label: 'A-',
                      onPressed: s.fontSize > 12
                          ? () => _changeFontSize(-2)
                          : null,
                      minHeight: 40,
                    ),
                    const SizedBox(width: 4),
                    GhostButton(
                      palette: p,
                      label: 'A+',
                      onPressed: s.fontSize < 28
                          ? () => _changeFontSize(2)
                          : null,
                      minHeight: 40,
                    ),
                    IconButton(
                      icon: Icon(Icons.settings, color: textColor),
                      onPressed: _openSettings,
                      tooltip: 'Reader settings',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(margin, 12, margin, 0),
                child: Text(
                  'CHAPTER ${index + 1} OF ${chapters.length}',
                  style: monoStyle(p, size: 10, color: faintColor),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      controller: _scroll,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(margin, 8, margin, 16),
                        child: SelectableText(
                          chapter.text,
                          textAlign: s.align == BookAlignment.justify
                              ? TextAlign.justify
                              : TextAlign.left,
                          style: bodyStyle(
                            p,
                            size: s.fontSize,
                            height: s.lineHeightValue,
                          ).copyWith(
                            fontFamily: s.fontFamilyName,
                            color: textColor,
                          ),
                        ),
                      ),
                    ),
                    if (s.dimOpacity > 0)
                      IgnorePointer(
                        child: Container(
                          color: Colors.black.withOpacity(s.dimOpacity),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GhostButton(
                        palette: p,
                        label: 'Previous',
                        icon: Icons.chevron_left,
                        onPressed: index > 0
                            ? () => appState.openCatalogChapter(index - 1)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GoldButton(
                        palette: p,
                        label: 'Next',
                        icon: Icons.chevron_right,
                        onPressed: index + 1 < chapters.length
                            ? () => appState.openCatalogChapter(index + 1)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
