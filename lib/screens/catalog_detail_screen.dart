/// Detail page for one catalog item: cover + title + authors
/// + subjects, Save + Like actions, synopsis, chapter list with read
/// marks and "Continue reading" (books), chapter list (manga), or the
/// Read button (comics), and comments. The chapter list fills in once
/// the book's full text downloads (AppState starts that download when
/// the item is opened); a failed download shows a retry instead of an
/// empty list.
library;

import 'package:flutter/material.dart';

import '../models/catalog.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/shared.dart';

class CatalogDetailScreen extends StatefulWidget {
  const CatalogDetailScreen({
    super.key,
    required this.appState,
    required this.theme,
    required this.onAuthPrompt,
  });

  final AppState appState;
  final ThemeProvider theme;
  final VoidCallback onAuthPrompt;

  @override
  State<CatalogDetailScreen> createState() => _CatalogDetailScreenState();
}

class _CatalogDetailScreenState extends State<CatalogDetailScreen> {
  @override
  void initState() {
    super.initState();
    widget.appState.setInnerBackHandler(_backToBrowse);
  }

  @override
  void dispose() {
    widget.appState.setInnerBackHandler(null);
    super.dispose();
  }

  void _backToBrowse() => widget.appState.navigate(AppView.browse);

  void _requireAuth(VoidCallback action) {
    if (widget.appState.user == null) {
      widget.onAuthPrompt();
      return;
    }
    action();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.theme.palette;
    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) {
        final item = widget.appState.selectedCatalogItem;
        if (item == null) {
          return Center(
            child: EmptyState(
              palette: p,
              icon: Icons.menu_book,
              title: 'No book selected',
              sub: 'Pick a book from Browse to see it here.',
            ),
          );
        }
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _topBar(p, item),
              _hero(p, item),
              _actions(p, item),
              _synopsis(p, item),
              _chapters(p, item),
              _comments(p, item),
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }

  Widget _topBar(AppPalette p, CatalogItem item) {
    final c = p.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.borderFaint)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: c.text),
            onPressed: _backToBrowse,
            tooltip: 'Back to Browse',
          ),
          Expanded(
            child: Text(
              item.title,
              style: displayStyle(p, size: 16).copyWith(
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(AppPalette p, CatalogItem item) {
    final c = p.c;
    final a = p.accent;
    final typeLabel = switch (item.type) {
      CatalogType.ebook => 'E-BOOK',
      CatalogType.novel => 'NOVEL',
      CatalogType.comic => 'COMIC',
      CatalogType.manga => 'MANGA',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 110,
            height: 150,
            decoration: BoxDecoration(
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(1),
              child: item.coverUrl != null
                  ? NetImage(
                      url: item.coverUrl!,
                      width: 108,
                      height: 148,
                      borderRadius: BorderRadius.circular(7),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: c.surface2,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(
                        Icons.menu_book,
                        size: 36,
                        color: c.muted,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  typeLabel,
                  style: monoStyle(p,
                      size: 10, color: a.accent, weight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  item.title,
                  style: displayStyle(p, size: 20).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  item.authorLabel,
                  style: bodyStyle(p,
                      size: 13, color: c.textSub, weight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.subjects.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final subject in item.subjects)
                        TagChip(palette: p, tag: subject),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(AppPalette p, CatalogItem item) {
    final appState = widget.appState;
    final saved = appState.isCatalogSaved(item.id);
    final liked = appState.catalogLikedByMe;
    final likeCount = appState.catalogLikedBy.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: GoldButton(
              palette: p,
              label: saved ? 'Saved' : 'Save',
              icon: saved ? Icons.bookmark : Icons.bookmark_border,
              onPressed: () => _requireAuth(
                () => appState.toggleCatalogSave(item),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GhostButton(
              palette: p,
              label: liked
                  ? 'Liked · $likeCount'
                  : 'Like · $likeCount',
              icon: liked ? Icons.favorite : Icons.favorite_border,
              onPressed: () => _requireAuth(
                () => appState.reactToCatalogItem(item.id),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Synopsis from the source, when the source gives one. Books
  /// fetch theirs from the Open Library work record when the detail
  /// page opens (AppState `_ensureSynopsis`); manga and comics carry
  /// theirs in the list item.
  Widget _synopsis(AppPalette p, CatalogItem item) {
    final c = p.c;
    final appState = widget.appState;
    final loading = appState.synopsisLoading;
    final synopsis = item.synopsis;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(palette: p, text: 'Synopsis'),
          const SizedBox(height: 10),
          if (loading && synopsis == null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: p.accent.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Loading synopsis…',
                  style: bodyStyle(p, size: 13, color: c.faint),
                ),
              ],
            )
          else if (synopsis == null || synopsis.isEmpty)
            Text(
              'No synopsis available for this title.',
              style: bodyStyle(p, size: 13, color: c.faint),
            )
          else
            SelectableText(
              synopsis,
              style: bodyStyle(p, size: 14, color: c.textSub, height: 1.7),
            ),
        ],
      ),
    );
  }

  Widget _chapters(AppPalette p, CatalogItem item) {
    // Manga chapters are page lists from MangaDex, comics have no
    // chapters at all — they open in the PDF viewer instead.
    if (item.type == CatalogType.manga) return _mangaChapters(p, item);
    if (item.type == CatalogType.comic) return _readComic(p, item);
    final c = p.c;
    final appState = widget.appState;
    final chapters = appState.catalogChapters;
    final loading = appState.catalogTextLoading;
    final failed = appState.catalogTextError;
    final progress = appState.catalogProgress;
    final read = progress?.readChapterIndices.toSet() ?? <int>{};
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SectionLabel(
                  palette: p,
                  text: chapters.isEmpty
                      ? 'Chapters'
                      : 'Chapters · ${chapters.length}',
                ),
              ),
              if (progress != null && chapters.isNotEmpty)
                Text(
                  '${read.length}/${chapters.length} read',
                  style: monoStyle(p, size: 10, color: c.faint),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (progress != null && chapters.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GoldButton(
                palette: p,
                label: 'Continue reading — '
                    '${chapters[progress.lastChapterIndex.clamp(0, chapters.length - 1)].title}',
                icon: Icons.play_arrow,
                onPressed: () => appState.openCatalogChapter(
                  progress.lastChapterIndex,
                ),
              ),
            ),
          if (loading && chapters.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: p.accent.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Loading chapters…',
                    style: bodyStyle(p, size: 13, color: c.faint),
                  ),
                ],
              ),
            )
          else if (failed && chapters.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Could not load this book. Check your connection '
                    'and try again.',
                    style: bodyStyle(p, size: 13, color: c.textSub),
                  ),
                  const SizedBox(height: 10),
                  GoldButton(
                    palette: p,
                    label: 'Retry',
                    icon: Icons.refresh,
                    onPressed: () => appState.reloadCatalogChapters(),
                    minHeight: 40,
                  ),
                ],
              ),
            )
          else
            ...chapters.map((chapter) {
              final isRead = read.contains(chapter.index);
              final isCurrent =
                  progress != null &&
                  progress.lastChapterIndex == chapter.index;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: loading
                      ? null
                      : () => appState.openCatalogChapter(chapter.index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 12),
                    decoration: BoxDecoration(
                      border:
                          Border(bottom: BorderSide(color: c.borderFaint)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${chapter.index + 1}',
                          style: monoStyle(p, size: 11, color: c.faint),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            chapter.title,
                            style: bodyStyle(p,
                                size: 14,
                                color: isCurrent ? p.accent.accent : c.text,
                                weight: isCurrent
                                    ? FontWeight.w700
                                    : FontWeight.w400),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isRead)
                          Icon(Icons.check_circle,
                              size: 18, color: p.accent.accent),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right, size: 18, color: c.muted),
                      ],
                    ),
                  ),
                ),
              );
            }),
          if (!loading && !failed && chapters.isEmpty)
            Text(
              'No chapters found for this book yet.',
              style: bodyStyle(p, size: 13, color: c.faint),
            ),
        ],
      ),
    );
  }

  /// Manga chapter list (English chapters with real pages, from
  /// MangaDex). Same shape as the book chapters above, without read
  /// marks — page-level progress is not tracked yet. Tapping a
  /// chapter opens the page reader.
  Widget _mangaChapters(AppPalette p, CatalogItem item) {
    final c = p.c;
    final appState = widget.appState;
    final chapters = appState.mangaChapters;
    final loading = appState.mangaChaptersLoading;
    final failed = appState.mangaChaptersError;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(
            palette: p,
            text: chapters.isEmpty
                ? 'Chapters'
                : 'Chapters · ${chapters.length}',
          ),
          const SizedBox(height: 10),
          if (loading && chapters.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: p.accent.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Loading chapters…',
                    style: bodyStyle(p, size: 13, color: c.faint),
                  ),
                ],
              ),
            )
          else if (failed && chapters.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Could not load the chapters. Check your '
                    'connection and try again.',
                    style: bodyStyle(p, size: 13, color: c.textSub),
                  ),
                  const SizedBox(height: 10),
                  GoldButton(
                    palette: p,
                    label: 'Retry',
                    icon: Icons.refresh,
                    onPressed: () => appState.reloadMangaChapters(),
                    minHeight: 40,
                  ),
                ],
              ),
            )
          else
            ...chapters.asMap().entries.map((entry) {
              final index = entry.key;
              final chapter = entry.value;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: loading
                      ? null
                      : () => appState.openMangaChapter(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 12),
                    decoration: BoxDecoration(
                      border:
                          Border(bottom: BorderSide(color: c.borderFaint)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          chapter.number.isEmpty ? '–' : chapter.number,
                          style: monoStyle(p, size: 11, color: c.faint),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            chapter.label,
                            style: bodyStyle(p, size: 14, color: c.text),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${chapter.pages} pages',
                          style: monoStyle(p, size: 10, color: c.faint),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right, size: 18, color: c.muted),
                      ],
                    ),
                  ),
                ),
              );
            }),
          if (!loading && !failed && chapters.isEmpty)
            Text(
              'No readable chapters in English yet.',
              style: bodyStyle(p, size: 13, color: c.faint),
            ),
        ],
      ),
    );
  }

  /// Comic read section: the issue opens in the in-app PDF viewer.
  /// The PDF URL resolves from the issue's IA metadata when the
  /// detail page opens; the button waits on that.
  Widget _readComic(AppPalette p, CatalogItem item) {
    final c = p.c;
    final appState = widget.appState;
    final resolving = appState.comicPdfResolving;
    final failed = appState.comicPdfError;
    final ready = item.pdfUrl != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(palette: p, text: 'Read this comic'),
          const SizedBox(height: 10),
          Text(
            'The full issue opens in the in-app PDF viewer — swipe '
            'through the pages.',
            style: bodyStyle(p, size: 13, color: c.textSub),
          ),
          const SizedBox(height: 12),
          if (failed)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Could not find the issue file. Check your connection '
                'and reopen this comic.',
                style: bodyStyle(p, size: 13, color: c.textSub),
              ),
            )
          else
            GoldButton(
              palette: p,
              label: resolving ? 'Finding the issue…' : 'Read now',
              icon: Icons.picture_as_pdf,
              loading: resolving,
              onPressed:
                  ready ? () => appState.openCatalogPdf() : null,
            ),
        ],
      ),
    );
  }

  Widget _comments(AppPalette p, CatalogItem item) {
    final c = p.c;
    final appState = widget.appState;
    final user = appState.user;
    final comments = appState.catalogComments;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(
            palette: p,
            text: 'Comments · ${comments.length}',
          ),
          const SizedBox(height: 12),
          if (user == null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Sign in to join the discussion.',
                      style: bodyStyle(p, size: 13, color: c.textSub),
                    ),
                  ),
                  GoldButton(
                    palette: p,
                    label: 'Sign in',
                    onPressed: widget.onAuthPrompt,
                    minHeight: 40,
                  ),
                ],
              ),
            )
          else
            CommentComposer(
              palette: p,
              user: user,
              hintText: 'Share your thoughts on this book…',
              onPost: (text) => appState.addCatalogComment(item.id, text),
            ),
          const SizedBox(height: 16),
          if (comments.isEmpty)
            Text(
              'No comments yet. Be the first to share your thoughts.',
              style: bodyStyle(p, size: 13, color: c.faint),
            )
          else
            ...comments.map((comment) => _commentCard(p, item, comment)),
        ],
      ),
    );
  }

  Widget _commentCard(AppPalette p, CatalogItem item, PaperComment comment) {
    final c = p.c;
    final a = p.accent;
    final user = widget.appState.user;
    final liked = user != null && comment.likedBy.contains(user.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AvatarImage(
                  url: comment.avatar,
                  size: 30,
                  borderColor: c.border,
                  borderWidth: 2,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.username,
                      style:
                          bodyStyle(p, size: 13, weight: FontWeight.w600),
                    ),
                    Text(
                      timeAgo(comment.createdAt),
                      style: monoStyle(p, size: 10, color: c.faint),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            SelectableText(
              comment.text,
              style: bodyStyle(p, size: 14, color: c.textSub, height: 1.7),
            ),
            const SizedBox(height: 12),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _requireAuth(
                  () => widget.appState.toggleCatalogCommentLike(
                    item.id,
                    comment.id,
                  ),
                ),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: liked ? a.accent : c.border,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        liked ? Icons.favorite : Icons.favorite_border,
                        size: 16,
                        color: liked ? a.accent : c.muted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        formatCount(comment.likes),
                        style: monoStyle(p,
                            size: 11,
                            color: liked ? a.accent : c.faint),
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
