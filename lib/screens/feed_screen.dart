/// News Feed tab: admin-posted news (Firestore `news`) on top, then live
/// education/science headlines fetched from the web.
///
/// Live headlines come from [AppState.liveNews] (rss2json JSON, cached
/// 5 min); tapping a story opens it in the browser. Pull down to refresh.
/// Admins can post news from the header button and delete their posts
/// from the card.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/constants.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
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

  @override
  void initState() {
    super.initState();
    // Defer past the first frame: fetchLiveNews notifies listeners, and
    // notifying during initState would call setState mid-build.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.appState.fetchLiveNews(),
    );
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

  String _dateOf(NewsItem item) =>
      formatShortDate(item.publishedAt.toIso8601String().substring(0, 10));

  @override
  Widget build(BuildContext context) {
    final p = widget.theme.palette;
    final c = p.c;
    final a = p.accent;
    final isNarrow = MediaQuery.of(context).size.width < 700;
    final isAdmin = widget.appState.user?.isAdmin == true;
    final adminNews = widget.appState.adminNews;
    final liveNews = widget.appState.liveNews;

    return RefreshIndicator(
      color: a.accent,
      backgroundColor: c.surface,
      onRefresh: () => widget.appState.fetchLiveNews(forceRefresh: true),
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
                      if (adminNews.isNotEmpty) ...[
                        _sectionLabel(p, 'POSTED BY ARXIV'),
                        const SizedBox(height: 12),
                        for (final item in adminNews) ...[
                          _NewsCard(
                            item: item,
                            palette: p,
                            isAdminPost: true,
                            canDelete: isAdmin,
                            onOpen: () => _openUrl(item.url),
                            onDelete: () => _confirmDelete(p, item),
                            dateLabel: _dateOf(item),
                          ),
                          const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 20),
                      ],
                      _sectionLabel(p, 'LIVE FROM THE WEB'),
                      const SizedBox(height: 12),
                      if (widget.appState.liveNewsLoading && liveNews.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: Column(
                              children: [
                                CircularProgressIndicator(color: a.accent),
                                const SizedBox(height: 16),
                                Text(
                                  'Fetching the latest headlines…',
                                  style: bodyStyle(p, size: 13, color: c.muted),
                                ),
                              ],
                            ),
                          ),
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
                            item: item,
                            palette: p,
                            onOpen: () => _openUrl(item.url),
                            dateLabel: _dateOf(item),
                          ),
                          const SizedBox(height: 12),
                        ],
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
                      'NEWS FEED',
                      style: monoStyle(p, size: 10, color: a.accent).copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Popular in education & science',
                      style: displayStyle(p, size: narrow ? 20 : 24),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Live headlines from the web, plus posts from Arxiv.',
                      style: bodyStyle(p, size: 13, color: c.muted),
                    ),
                  ],
                ),
              ),
              if (isAdmin) ...[
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
                        if (!mounted) return;
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

class _NewsCard extends StatelessWidget {
  const _NewsCard({
    required this.item,
    required this.palette,
    this.isAdminPost = false,
    this.canDelete = false,
    required this.onOpen,
    this.onDelete,
    required this.dateLabel,
  });

  final NewsItem item;
  final AppPalette palette;
  final bool isAdminPost;
  final bool canDelete;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final c = palette.c;
    final a = palette.accent;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: item.url.isEmpty ? null : onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isAdminPost ? a.accent.withValues(alpha: 0.06) : c.surface,
            border: Border.all(
              color: isAdminPost ? a.accent.withValues(alpha: 0.5) : c.border,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
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
                            color: isAdminPost ? a.accent : c.surface2,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            isAdminPost ? 'ARXIV' : item.source.toUpperCase(),
                            style: monoStyle(
                              palette,
                              size: 9,
                              color: isAdminPost ? a.accentFg : c.muted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dateLabel,
                          style: monoStyle(palette, size: 10, color: c.faint),
                        ),
                        const Spacer(),
                        if (canDelete)
                          InkWell(
                            onTap: onDelete,
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
                      style: displayStyle(palette, size: 16),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.summary.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.summary,
                        style: bodyStyle(palette, size: 13, color: c.muted),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (item.url.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Read the full story ↗',
                        style: bodyStyle(palette, size: 12, color: a.accent),
                      ),
                    ],
                  ],
                ),
              ),
              if (item.imageUrl.isNotEmpty) ...[
                const SizedBox(width: 12),
                NetImage(
                  url: item.imageUrl,
                  width: 72,
                  height: 72,
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
