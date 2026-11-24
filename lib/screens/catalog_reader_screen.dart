/// In-app text reader for one catalog chapter: selectable text with
/// A-/A+ font size, prev/next chapter footer, and reading position
/// saved on exit (the detail screen's "Continue reading" resumes it).
/// The system back button returns to the detail screen, same as the
/// back arrow.
library;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/theme_provider.dart';
import 'shared.dart';

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
  double _fontSize = 17;
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

  void _changeFontSize(double delta) {
    setState(() {
      _fontSize = (_fontSize + delta).clamp(14.0, 24.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.theme.palette;
    final c = p.c;
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.borderFaint)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: c.text),
                    onPressed: _backToDetail,
                    tooltip: 'Back to book',
                  ),
                  Expanded(
                    child: Text(
                      chapter.title,
                      style: displayStyle(p, size: 16).copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GhostButton(
                    palette: p,
                    label: 'A-',
                    onPressed:
                        _fontSize > 14 ? () => _changeFontSize(-2) : null,
                    minHeight: 40,
                  ),
                  const SizedBox(width: 4),
                  GhostButton(
                    palette: p,
                    label: 'A+',
                    onPressed:
                        _fontSize < 24 ? () => _changeFontSize(2) : null,
                    minHeight: 40,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                'CHAPTER ${index + 1} OF ${chapters.length}',
                style: monoStyle(p, size: 10, color: c.faint),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SelectableText(
                    chapter.text,
                    style: bodyStyle(p, size: _fontSize, height: 1.8),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.borderFaint)),
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
        );
      },
    );
  }
}
