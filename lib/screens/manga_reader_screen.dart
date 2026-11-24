/// In-app page reader for one manga chapter: full-page images from
/// MangaDex's at-home server, swiped horizontally, with a page
/// indicator and prev/next chapter footer. The system back button
/// returns to the detail screen, same as the back arrow. Page
/// progress is not saved yet (a later update can add it).
library;

import 'package:flutter/material.dart';

import '../models/catalog.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/theme_provider.dart';
import '../widgets/shared.dart';

class MangaReaderScreen extends StatefulWidget {
  const MangaReaderScreen({
    super.key,
    required this.appState,
    required this.theme,
  });

  final AppState appState;
  final ThemeProvider theme;

  @override
  State<MangaReaderScreen> createState() => _MangaReaderScreenState();
}

class _MangaReaderScreenState extends State<MangaReaderScreen> {
  final PageController _pages = PageController();
  int _pageIndex = 0;

  /// The chapter this State instance is showing. The shell keys the
  /// screen by chapter index, so a chapter change remounts the screen
  /// and the page index resets to the first page.
  late final int _chapterIndex;

  @override
  void initState() {
    super.initState();
    _chapterIndex = widget.appState.selectedMangaChapterIndex;
    widget.appState.setInnerBackHandler(_backToDetail);
  }

  @override
  void dispose() {
    widget.appState.setInnerBackHandler(null);
    _pages.dispose();
    super.dispose();
  }

  void _backToDetail() {
    widget.appState.navigate(AppView.catalogDetail);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.theme.palette;
    final c = p.c;
    final isNarrow = MediaQuery.of(context).size.width < 700;
    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) {
        final appState = widget.appState;
        final item = appState.selectedCatalogItem;
        final chapter = appState.selectedMangaChapter;
        final pageUrls = appState.mangaPageUrls;
        final loading = appState.mangaPagesLoading;
        if (item == null || chapter == null || pageUrls.isEmpty) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
              child: EmptyState(
                palette: p,
                icon: Icons.image,
                title: loading ? 'Loading pages…' : 'No pages to show',
                sub: loading
                    ? 'Fetching this chapter from MangaDex.'
                    : 'Try another chapter.',
              ),
            ),
          );
        }
        final chapterCount = appState.mangaChapters.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top bar: back + chapter label.
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.border)),
              ),
              padding: EdgeInsets.fromLTRB(
                isNarrow ? 8 : 16,
                isNarrow ? 8 : 12,
                isNarrow ? 8 : 16,
                isNarrow ? 8 : 12,
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back to ${item.title}',
                    icon: Icon(Icons.arrow_back, color: c.text, size: 22),
                    onPressed: _backToDetail,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chapter.label,
                          style: displayStyle(p,
                              size: 16, weight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          item.title,
                          style: monoStyle(p, size: 10, color: c.faint),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Page ${_pageIndex + 1} of ${pageUrls.length}',
                    style: monoStyle(p, size: 10, color: c.faint),
                  ),
                ],
              ),
            ),
            // Pages: swipe horizontally; NetImage defaults to contain,
            // so the whole page shows, never cropped.
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: pageUrls.length,
                onPageChanged: (i) => setState(() => _pageIndex = i),
                itemBuilder: (context, i) {
                  return Center(
                    child: NetImage(url: pageUrls[i]),
                  );
                },
              ),
            ),
            // Footer: prev/next chapter.
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.border)),
              ),
              padding: EdgeInsets.fromLTRB(
                isNarrow ? 16 : 24,
                12,
                isNarrow ? 16 : 24,
                isNarrow ? 16 : 24,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GhostButton(
                      palette: p,
                      label: 'Previous',
                      icon: Icons.chevron_left,
                      onPressed: _chapterIndex > 0 && !loading
                          ? () => appState.openMangaChapter(_chapterIndex - 1)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GoldButton(
                      palette: p,
                      label: 'Next chapter',
                      icon: Icons.chevron_right,
                      onPressed: _chapterIndex < chapterCount - 1 && !loading
                          ? () => appState.openMangaChapter(_chapterIndex + 1)
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
