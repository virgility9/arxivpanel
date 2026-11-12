/// News Feed tab with two inner tabs: "News for today" (admin-posted news
/// from Firestore `news` on top, then live education/science headlines
/// fetched from the web) and "Published papers" (the latest papers from
/// arXiv, fetched live through the arXiv API via rss2json — same
/// no-new-dependency path as the headlines).
///
/// Live headlines come from [AppState.liveNews] (rss2json JSON, cached
/// 5 min); tapping a story opens it in the browser. Pull down to refresh.
/// Admins can post news from the header button and delete their posts
/// from the card.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/constants.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/motion.dart';
import '../widgets/shared.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key, required this.appState, required this.theme});

  final AppState appState;
  final ThemeProvider theme;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  bool _posting = false;
  String? _formError;
  // Inner tabs: 0 = News for today, 1 = Published papers.
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    // Defer past the first frame: fetchLiveNews/fetchArxivPapers notify
    // listeners, and notifying during initState would call setState
    // mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.appState.fetchLiveNews();
      widget.appState.fetchArxivPapers();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      widget.appState.showToast('Could not open the article.', '⚠️');
    }
  }

  Future<void> _shareNews(NewsItem item) async {
    if (item.url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: item.url));
    widget.appState.showToast('Link copied', '🔗');
  }

  String _dateOf(NewsItem item) => timeAgo(item.publishedAt);

  @override
  Widget build(BuildContext context) {
    final p = widget.theme.palette;
    final c = p.c;
    final a = p.accent;
    final isNarrow = MediaQuery.of(context).size.width < 700;
    final isAdmin = widget.appState.user?.isAdmin == true;
    final adminNews = widget.appState.adminNews;
    final liveNews = widget.appState.liveNews;
    final arxivPapers = widget.appState.arxivPapers;

    return RefreshIndicator(
      color: a.accent,
      backgroundColor: c.surface,
      onRefresh: () => _tabIndex == 0
          ? widget.appState.fetchLiveNews(forceRefresh: true)
          : widget.appState.fetchArxivPapers(forceRefresh: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(p, isNarrow, isAdmin),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isNarrow ? 16 : 24,
                    isNarrow ? 20 : 32,
                    isNarrow ? 16 : 24,
                    100,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTabSwitcher(p),
                      const SizedBox(height: 20),
                      MotionSwitcher(
                        slide: false,
                        child: KeyedSubtree(
                          key: ValueKey(_tabIndex),
                          child: _tabIndex == 0
                              ? _buildNewsTab(p, adminNews, liveNews, isAdmin)
                              : _buildPapersTab(p, arxivPapers),
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

  /// News tab content: admin posts, then live headlines. Extracted so
  /// the tab switch in [build] stays a one-liner.
  Widget _buildNewsTab(
    AppPalette p,
    List<NewsItem> adminNews,
    List<NewsItem> liveNews,
    bool isAdmin,
  ) {
    final c = p.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (adminNews.isNotEmpty) ...[
          _sectionLabel(p, 'POSTED BY ARXIV'),
          const SizedBox(height: 12),
          for (final item in adminNews) ...[
            _NewsCard(
              key: ValueKey(item.id),
              item: item,
              palette: p,
              isAdminPost: true,
              canDelete: isAdmin,
              onOpen: () => _openUrl(item.url),
              onDelete: () => _confirmDelete(p, item),
              onShare: () => _shareNews(item),
              dateLabel: _dateOf(item),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 20),
        ],
        _sectionLabel(p, 'LIVE FROM THE WEB'),
        const SizedBox(height: 12),
        if (widget.appState.liveNewsLoading && liveNews.isEmpty)
          Column(
            children: [
              for (var i = 0; i < 3; i++) ...[
                _NewsSkeletonCard(palette: p),
                if (i < 2) const SizedBox(height: 12),
              ],
            ],
          )
        else if (widget.appState.liveNewsError &&
            liveNews.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                const Text('📶', style: TextStyle(fontSize: 32)),
                const SizedBox(height: 12),
                Text(
                  'Couldn\'t load live news',
                  style: displayStyle(
                    p,
                    size: 17,
                    color: c.muted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Check your connection and try again.',
                  style: bodyStyle(p, size: 13, color: c.muted),
                ),
                const SizedBox(height: 16),
                GoldButton(
                  palette: p,
                  label: 'Retry',
                  minHeight: 44,
                  onPressed: () => widget.appState.fetchLiveNews(
                    forceRefresh: true,
                  ),
                ),
              ],
            ),
          )
        else if (liveNews.isEmpty && adminNews.isEmpty)
          EmptyState(
            palette: p,
            icon: '📰',
            title: 'No news yet',
            sub: 'Pull down to refresh, or check back later',
          )
        else
          for (final item in liveNews) ...[
            _NewsCard(
              key: ValueKey(item.id),
              item: item,
              palette: p,
              onOpen: () => _openUrl(item.url),
              onShare: () => _shareNews(item),
              dateLabel: _dateOf(item),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  /// Published papers tab: the latest papers from arXiv, newest first.
  /// Same loading/error/empty states as the news tab; tapping a card
  /// opens the paper on arXiv.org in the browser.
  Widget _buildPapersTab(AppPalette p, List<NewsItem> arxivPapers) {
    final c = p.c;
    if (widget.appState.arxivPapersLoading && arxivPapers.isEmpty) {
      return Column(
        children: [
          for (var i = 0; i < 3; i++) ...[
            _NewsSkeletonCard(palette: p),
            if (i < 2) const SizedBox(height: 12),
          ],
        ],
      );
    }
    if (widget.appState.arxivPapersError && arxivPapers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            const Text('📶', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 12),
            Text(
              'Couldn\'t load papers',
              style: displayStyle(
                p,
                size: 17,
                color: c.muted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Check your connection and try again.',
              style: bodyStyle(p, size: 13, color: c.muted),
            ),
            const SizedBox(height: 16),
            GoldButton(
              palette: p,
              label: 'Retry',
              minHeight: 44,
              onPressed: () => widget.appState.fetchArxivPapers(
                forceRefresh: true,
              ),
            ),
          ],
        ),
      );
    }
    if (arxivPapers.isEmpty) {
      return EmptyState(
        palette: p,
        icon: '📄',
        title: 'No papers yet',
        sub: 'Pull down to refresh, or check back later',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in arxivPapers) ...[
          _NewsCard(
            key: ValueKey(item.id),
            item: item,
            palette: p,
            showAuthor: true,
            onOpen: () => _openUrl(item.url),
            onShare: () => _shareNews(item),
            dateLabel: _dateOf(item),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  /// Two-segment switcher for the inner Feed tabs.
  Widget _buildTabSwitcher(AppPalette p) {
    final c = p.c;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _tabSegment(p, 'News for today', 0),
          _tabSegment(p, 'Published papers', 1),
        ],
      ),
    );
  }

  Widget _tabSegment(AppPalette p, String label, int index) {
    final selected = _tabIndex == index;
    final c = p.c;
    final a = p.accent;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? a.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: bodyStyle(
              p,
              size: 13,
              color: selected ? a.accentFg : c.muted,
              weight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppPalette p, bool narrow, bool isAdmin) {
    final c = p.c;
    final a = p.accent;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        narrow ? 16 : 24,
        narrow ? 16 : 24,
        narrow ? 16 : 24,
        narrow ? 16 : 24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tabIndex == 0 ? 'NEWS FEED' : 'PUBLISHED PAPERS',
                      style: monoStyle(p, size: 10, color: a.accent).copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _tabIndex == 0
                          ? 'Popular in education & science'
                          : 'Latest from arXiv',
                      style: displayStyle(p, size: narrow ? 20 : 24),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _tabIndex == 0
                          ? 'Live headlines from the web, plus posts from Arxiv.'
                          : 'New papers from arXiv.org, latest first.',
                      style: bodyStyle(p, size: 13, color: c.muted),
                    ),
                  ],
                ),
              ),
              if (isAdmin && _tabIndex == 0) ...[
                const SizedBox(width: 12),
                GoldButton(
                  palette: p,
                  label: 'Post news',
                  minHeight: 44,
                  onPressed: _openPostNews,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(AppPalette p, String label) {
    return Text(
      label,
      style: monoStyle(
        p,
        size: 10,
        color: p.c.faint,
      ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.12),
    );
  }

  void _confirmDelete(AppPalette p, NewsItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: p.c.border),
        ),
        title: Text('Delete this news post?', style: displayStyle(p, size: 17)),
        content: Text(
          item.title,
          style: bodyStyle(p, size: 13, color: p.c.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              AppConstants.cancelLabel,
              style: bodyStyle(p, size: 13, color: p.accent.accent),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await widget.appState.deleteNews(item.id);
            },
            child: Text(
              'Delete',
              style: TextStyle(fontSize: 13, color: p.danger),
            ),
          ),
        ],
      ),
    );
  }

  void _openPostNews() {
    final p = widget.theme.palette;
    _titleController.clear();
    _summaryController.clear();
    _urlController.clear();
    _formError = null;
    _posting = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: p.c.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: p.c.border),
            ),
            title: Text('Post news', style: displayStyle(p, size: 17)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Headline',
                      hintText: 'What happened?',
                    ),
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _summaryController,
                    decoration: const InputDecoration(
                      labelText: 'Summary',
                      hintText: 'One or two sentences (optional)',
                    ),
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'Link',
                      hintText: 'https://… (optional)',
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  if (_formError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _formError!,
                      style: bodyStyle(p, size: 12, color: p.danger),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  AppConstants.cancelLabel,
                  style: bodyStyle(p, size: 13, color: p.accent.accent),
                ),
              ),
              TextButton(
                onPressed: _posting
                    ? null
                    : () async {
                        final title = _titleController.text.trim();
                        if (title.isEmpty) {
                          setDialogState(
                            () => _formError = 'Add a headline first.',
                          );
                          return;
                        }
                        setDialogState(() {
                          _posting = true;
                          _formError = null;
                        });
                        final ok = await widget.appState.postNews(
                          title: title,
                          summary: _summaryController.text,
                          url: _urlController.text,
                        );
                        // `mounted` guards the Feed screen's own State,
                        // but `ctx` is the dialog's context — it needs
                        // its own check. Without it, popping (or
                        // setDialogState below) after the dialog was
                        // already dismissed uses a dead context.
                        if (!mounted || !ctx.mounted) return;
                        if (ok) {
                          Navigator.of(ctx).pop();
                        } else {
                          setDialogState(() {
                            _posting = false;
                            _formError = 'Could not post the news.';
                          });
                        }
                      },
                child: Text(
                  _posting ? 'Posting…' : 'Post',
                  style: bodyStyle(p, size: 13, color: p.accent.accent),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A news story rendered like a social post, matching the reference
/// design: full-width image on top, bold headline, summary with a
/// "See more" expander, relative time, and a like / share row.
///
/// The like is a local on-screen toggle only — it is not saved anywhere
/// (news has no reactions in Firestore). Share copies the article link.
/// There is deliberately no comment button: like / unlike + share only.
class _NewsCard extends StatefulWidget {
  const _NewsCard({
    super.key,
    required this.item,
    required this.palette,
    this.isAdminPost = false,
    this.canDelete = false,
    // Papers tab only: shows the "author · category" byline under the
    // title. News items carry no author, so news cards never pass it.
    this.showAuthor = false,
    required this.onOpen,
    this.onDelete,
    required this.onShare,
    required this.dateLabel,
  });

  final NewsItem item;
  final AppPalette palette;
  final bool isAdminPost;
  final bool canDelete;
  final bool showAuthor;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;
  final VoidCallback onShare;
  final String dateLabel;

  @override
  State<_NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<_NewsCard> {
  /// Like state lives only on screen for now — it is not saved anywhere.
  bool _liked = false;

  /// Long summaries start collapsed at 3 lines with a "See more" link.
  bool _expanded = false;

  /// Set when the cover image fails to load: the image block is dropped
  /// entirely instead of leaving a tall empty box with a 📄 in it.
  bool _imageFailed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final palette = widget.palette;
    final c = palette.c;
    final a = palette.accent;
    final hasLink = item.url.isNotEmpty;
    final longSummary = item.summary.length > 180;

    return PressScale(
      child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: hasLink ? widget.onOpen : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: widget.isAdminPost
                ? a.accent.withValues(alpha: 0.06)
                : c.surface,
            border: Border.all(
              color: widget.isAdminPost
                  ? a.accent.withValues(alpha: 0.5)
                  : c.border,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Full-width cover image, like a social post. Admin posts
              // carry no image, so they start straight at the text. A
              // thumbnail that fails to load hides the block instead of
              // leaving an empty box behind.
              if (item.imageUrl.isNotEmpty && !_imageFailed)
                NetImage(
                  url: item.imageUrl,
                  width: double.infinity,
                  height: 190,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  onError: () {
                    if (!_imageFailed) {
                      setState(() => _imageFailed = true);
                    }
                  },
                ),
              Padding(
                // Tight bottom padding: the buttons already carry 12px
                // of vertical padding for their tap target, so a full
                // 16px here left a dead gap under the like/share row
                // (12 + 16 = 28px below the icons, only 12px above).
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: widget.isAdminPost
                                ? a.accent
                                : c.surface2,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            widget.isAdminPost
                                ? 'ARXIV'
                                : item.source.toUpperCase(),
                            style: monoStyle(
                              palette,
                              size: 9,
                              color: widget.isAdminPost
                                  ? a.accentFg
                                  : c.muted,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (widget.canDelete)
                          InkWell(
                            onTap: widget.onDelete,
                            borderRadius: BorderRadius.circular(14),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Text(
                                '🗑️',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.title,
                      style: displayStyle(palette, size: 17).copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.showAuthor &&
                        (item.author.isNotEmpty ||
                            item.category.isNotEmpty)) ...[
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (item.author.isNotEmpty) item.author,
                          if (item.category.isNotEmpty) item.category,
                        ].join(' · '),
                        style: bodyStyle(
                          palette,
                          size: 12,
                          color: c.muted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (item.summary.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.summary,
                        style: bodyStyle(
                          palette,
                          size: 13,
                          color: c.muted,
                        ),
                        maxLines: _expanded ? null : 3,
                        overflow: _expanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                      ),
                      if (longSummary) ...[
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () =>
                              setState(() => _expanded = !_expanded),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              _expanded ? 'See less' : 'See more',
                              style: bodyStyle(
                                palette,
                                size: 12,
                                color: a.accent,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 8),
                    // Relative time, like the reference post's "1d".
                    Text(
                      widget.dateLabel,
                      style: monoStyle(
                        palette,
                        size: 10,
                        color: c.faint,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: c.surface2),
                        ),
                      ),
                      child: Row(
                        children: [
                          _actionButton(
                            child: PopIcon(
                              active: _liked,
                              child: Icon(
                                _liked
                                    ? Icons.thumb_up
                                    : Icons.thumb_up_outlined,
                                size: 20,
                                color: _liked ? a.accent : c.muted,
                              ),
                            ),
                            onTap: () =>
                                setState(() => _liked = !_liked),
                          ),
                          _actionButton(
                            child: Icon(
                              Icons.share_outlined,
                              size: 20,
                              color: hasLink ? c.muted : c.faint,
                            ),
                            onTap: hasLink ? widget.onShare : null,
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
    );
  }

  /// One half of the like / share row. Greyed out with no
  /// tap when there is no article link to share. Pass [child]
  /// to render a custom icon (e.g. a [PopIcon] for the like).
  Widget _actionButton({
    required Widget child,
    required VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: child,
        ),
      ),
    );
  }
}

/// Placeholder post card shown while live headlines load, shaped like
/// a real `_NewsCard` (image block, title and summary bars, action row)
/// instead of a spinner. The grey bars shimmer with the same gold
/// sweep as the splash logo, and the cards are replaced by real
/// headlines the moment the fetch lands.
class _NewsSkeletonCard extends StatelessWidget {
  const _NewsSkeletonCard({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final c = palette.c;
    return Shimmer(
      child: Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 190,
            decoration: BoxDecoration(
              color: c.surface2,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bar(width: 72, height: 14),
                const SizedBox(height: 10),
                _bar(width: double.infinity, height: 16),
                const SizedBox(height: 8),
                _bar(width: 220, height: 16),
                const SizedBox(height: 8),
                _bar(width: double.infinity, height: 11),
                const SizedBox(height: 6),
                _bar(width: double.infinity, height: 11),
                const SizedBox(height: 6),
                _bar(width: 180, height: 11),
                const SizedBox(height: 8),
                _bar(width: 56, height: 10),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: c.surface2)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: _bar(width: 20, height: 20),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: _bar(width: 20, height: 20),
                          ),
                        ),
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
    );
  }

  Widget _bar({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: palette.c.surface2,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
