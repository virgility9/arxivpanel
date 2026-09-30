/// Reader screen ported from `src/components/PaperReader.tsx` of the React source.
///
/// Shows a single paper's hero (cover, metadata, reactions), tabbed content
/// (abstract / comments / PDF placeholder), and related papers.
///
/// The PDF tab embeds the paper's PDF in an iframe on web; on other
/// platforms it shows a card with the URL and a copy-link button. The scroll
/// progress bar from the web app was intentionally skipped (a web-only
/// affordance).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/constants.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/pdf_view.dart';
import '../widgets/shared.dart';

enum _ReaderTab { abstract, comments, pdf }

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.appState,
    required this.theme,
    required this.onAuthPrompt,
  });

  final AppState appState;
  final ThemeProvider theme;
  final VoidCallback onAuthPrompt;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  _ReaderTab _activeTab = _ReaderTab.abstract;

  /// Comment dates render like "Nov 14, 2024" (mirrors the React
  /// `toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" })`).
  String _fmtCommentDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    final sel = appState.selectedPaper;
    if (sel == null) return const SizedBox.shrink();
    final paper = sel;
    final p = widget.theme.palette;

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 640;
        final user = appState.user;
        final bookmarked = appState.isBookmarked(paper.id);

        final tabs = <_ReaderTab>[
          _ReaderTab.abstract,
          _ReaderTab.comments,
          if (paper.pdfUrl != null) _ReaderTab.pdf,
        ];

        void share() {
          // On web the app has no router/deep links, so the only honest
          // shareable link is the current page URL.
          final link = kIsWeb
              ? Uri.base.toString()
              : 'https://arxivpanel.app/papers/${paper.id}';
          Clipboard.setData(ClipboardData(text: link));
          appState.showToast('Link copied', '🔗');
        }

        return Column(
          children: [
            _buildTopBar(p, paper, bookmarked, narrow, share),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHero(p, paper, narrow),
                    _buildTabsBar(p, tabs, narrow, paper),
                    _buildTabContent(
                      p, paper, narrow, user, constraints.maxWidth,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------------ top bar

  Widget _topBarIconButton(
    AppPalette p, {
    required Widget child,
    required VoidCallback onPressed,
    Color? borderColor,
    Color? color,
    double minWidth = 44,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onPressed,
        child: Container(
          constraints: BoxConstraints(minWidth: minWidth, minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor ?? p.c.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: DefaultTextStyle(
              style: TextStyle(color: color ?? p.c.muted, fontSize: 14),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(
    AppPalette p,
    Paper paper,
    bool bookmarked,
    bool narrow,
    VoidCallback share,
  ) {
    final c = p.c;
    final a = p.accent;
    return Material(
      elevation: 0,
      color: c.bg,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.border)),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: narrow ? 16 : 24,
          vertical: narrow ? 10 : 12,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Row(
              children: [
                _topBarIconButton(
                  p,
                  minWidth: 44,
                  onPressed: () =>
                      widget.appState.navigate(AppView.library),
                  child: const Text('←'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    paper.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: displayStyle(
                      p,
                      size: narrow ? 12 : 14,
                      weight: FontWeight.w400,
                      color: c.muted,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _topBarIconButton(
                  p,
                  color: bookmarked ? a.accent : c.muted,
                  borderColor: bookmarked
                      ? a.accent.withValues(alpha: 0.3)
                      : null,
                  onPressed: () {
                    if (widget.appState.user == null) {
                      widget.onAuthPrompt();
                      return;
                    }
                    widget.appState.toggleBookmark(paper.id);
                  },
                  child: Text(bookmarked ? '🔖' : '🏷️'),
                ),
                const SizedBox(width: 8),
                _topBarIconButton(
                  p,
                  onPressed: share,
                  child: const Text('↗'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------- hero

  Widget _buildHero(
    AppPalette p,
    Paper paper,
    bool narrow,
  ) {
    final c = p.c;
    final hero = narrow
        ? _buildNarrowHero(p, paper)
        : _buildWideHero(p, paper);
    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: hero,
        ),
      ),
    );
  }

  Widget _coverBanner(
    AppPalette p,
    Paper paper, {
    required double width,
    required double height,
    required bool fadeBottom,
  }) {
    final c = p.c;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.85,
            child: NetImage(url: paper.coverImage),
          ),
          // Gradient fade painted over the image.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin:
                      fadeBottom ? Alignment.topCenter : Alignment.centerLeft,
                  end: fadeBottom
                      ? Alignment.bottomCenter
                      : Alignment.centerRight,
                  colors: [Colors.transparent, c.bg],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrowHero(AppPalette p, Paper paper) {
    final c = p.c;
    return Container(
      color: c.bg,
      child: Stack(
        children: [
          _coverBanner(p, paper,
              width: double.infinity, height: 200, fadeBottom: true),
          Padding(
            padding: const EdgeInsets.only(top: 156),
            child: _buildMeta(p, paper, narrow: true),
          ),
        ],
      ),
    );
  }

  Widget _buildWideHero(AppPalette p, Paper paper) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _coverBanner(p, paper, width: 240, height: 360, fadeBottom: false),
        Expanded(child: _buildMeta(p, paper, narrow: false)),
      ],
    );
  }

  Widget _buildMeta(AppPalette p, Paper paper, {required bool narrow}) {
    final c = p.c;
    final a = p.accent;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        narrow ? 16 : 32,
        narrow ? 0 : 28,
        narrow ? 16 : 32,
        narrow ? 24 : 28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Field badge + tags
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: a.accent.withValues(alpha: 0.15),
                  border: Border.all(
                      color: a.accent.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  paper.field.toUpperCase(),
                  style: monoStyle(
                    p,
                    size: 10,
                    color: a.accent,
                    letterSpacing: 0.08,
                  ),
                ),
              ),
              ...paper.tags
                  .take(narrow ? 2 : 4)
                  .map((t) => TagChip(palette: p, tag: t)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            paper.title,
            style: displayStyle(
              p,
              size: narrow ? 20 : 24,
              weight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          // Author row
          Row(
            children: [
              AvatarImage(
                url: paper.authorAvatar,
                size: 30,
                borderColor: c.border,
                borderWidth: 2,
              ),
              const SizedBox(width: 10),
              // Expanded + ellipsis: long institution names must not
              // overflow on narrow screens.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paper.author,
                      style:
                          bodyStyle(p, size: 13, weight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${paper.institution} · ${paper.year}',
                      style: bodyStyle(p, size: 11, color: c.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats
          Wrap(
            spacing: narrow ? 16 : 28,
            runSpacing: 12,
            children: [
              _statColumn(p, 'Views', formatCount(paper.views), narrow),
              _statColumn(p, 'Pages', '${paper.pages}', narrow),
              _statColumn(
                  p, 'Read time', '~${paper.readTimeMinutes}m', narrow),
              _statColumn(
                  p, 'Reactions', '${paper.totalReactions}', narrow),
              _statColumn(
                  p, 'Comments', '${paper.comments.length}', narrow),
            ],
          ),
          const SizedBox(height: 16),
          // Reactions
          Container(
            padding: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: AppConstants.reactions.map((emoji) {
                final count =
                    (paper.reactions[emoji] ?? const []).length;
                final active = _activeReactionFor(paper) == emoji;
                return _reactionButton(
                  p, paper, emoji, count, active);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Recomputes the user's active reaction for [paper] at build time.
  String? _activeReactionFor(Paper paper) {
    final user = widget.appState.user;
    if (user == null) return null;
    return paper.reactionOf(user.id);
  }

  Widget _statColumn(AppPalette p, String label, String value, bool narrow) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: monoStyle(p, size: 9, color: p.c.faint, letterSpacing: 0.1),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: displayStyle(p,
              size: narrow ? 16 : 20, weight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _reactionButton(
    AppPalette p,
    Paper paper,
    String emoji,
    int count,
    bool active,
  ) {
    final c = p.c;
    final a = p.accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (widget.appState.user == null) {
            widget.onAuthPrompt();
            return;
          }
          widget.appState.reactToPaper(paper.id, emoji);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active ? a.accent.withValues(alpha: 0.15) : c.surface2,
            border: Border.all(color: active ? a.accent : c.border),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 17)),
              if (count > 0) ...[
                const SizedBox(width: 5),
                Text(
                  '$count',
                  style: monoStyle(
                    p,
                    size: 11,
                    color: active ? a.accent : c.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------- tabs

  Widget _buildTabsBar(
    AppPalette p,
    List<_ReaderTab> tabs,
    bool narrow,
    Paper paper,
  ) {
    final c = p.c;
    final a = p.accent;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          // Horizontally scrollable so the tabs never cramp on narrow
          // screens (e.g. "Comments" + count badge + "PDF" at 360px).
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: tabs.map((tab) {
              final active = _activeTab == tab;
              return InkWell(
                onTap: () => setState(() => _activeTab = tab),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: narrow ? 16 : 24,
                    vertical: narrow ? 13 : 15,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: active ? a.accent : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _tabLabel(tab),
                        style: TextStyle(
                          color: active ? a.accent : c.muted,
                          fontSize: 14,
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      if (tab == _ReaderTab.comments) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 1),
                          decoration: BoxDecoration(
                            color: c.surface2,
                            border: Border.all(color: c.border),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${paper.comments.length}',
                            style: monoStyle(p, size: 11),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  String _tabLabel(_ReaderTab tab) {
    switch (tab) {
      case _ReaderTab.abstract:
        return 'Abstract';
      case _ReaderTab.comments:
        return 'Comments';
      case _ReaderTab.pdf:
        return 'PDF';
    }
  }

  Widget _buildTabContent(
    AppPalette p,
    Paper paper,
    bool narrow,
    AppUser? user,
    double maxWidth,
  ) {
    // Mirror the React padding: mobile "24px 16px", desktop "36px 0" (within
    // the 1100px wrapper which itself has 24px horizontal padding).
    final horizontal = narrow ? 16.0 : 24.0;
    final contentMax = narrow
        ? double.infinity
        : (maxWidth - horizontal * 2)
            .clamp(0.0, 1100.0 - horizontal * 2)
            .toDouble();
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontal,
        vertical: narrow ? 24 : 36,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentMax),
          child: switch (_activeTab) {
            _ReaderTab.abstract => _buildAbstractTab(p, paper, narrow),
            _ReaderTab.comments => _buildCommentsTab(p, paper, user),
            _ReaderTab.pdf => _buildPdfTab(p, paper),
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ abstract

  Widget _buildAbstractTab(AppPalette p, Paper paper, bool narrow) {
    final c = p.c;
    final related = widget.appState.papers
        .where((x) =>
            x.id != paper.id &&
            (x.field == paper.field ||
                x.tags.any(paper.tags.contains)))
        .take(3)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Abstract',
                  style: displayStyle(p, size: 18, weight: FontWeight.w600)),
              const SizedBox(height: 16),
              // Selectable so web readers can copy quotes.
              SelectableText(
                paper.abstract,
                style: bodyStyle(p,
                    size: narrow ? 15 : 16,
                    color: c.textSub,
                    height: 1.9),
              ),
              const SizedBox(height: 40),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = narrow ? 2 : 3;
                  final boxW =
                      (constraints.maxWidth - (cols - 1) * 12) / cols;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _infoBox(p, 'Institution', paper.institution, boxW),
                      _infoBox(p, 'Published',
                          formatMonthYear(paper.publishedAt), boxW),
                      _infoBox(p, 'Est. read time',
                          '${paper.readTimeMinutes} minutes', boxW),
                    ],
                  );
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
        if (related.isNotEmpty) ...[
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RELATED PAPERS',
                  style: monoStyle(p,
                      size: 10, color: c.faint, letterSpacing: 0.1),
                ),
                const SizedBox(height: 14),
                ...related.map((rel) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _relatedRow(p, rel),
                    )),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _infoBox(
      AppPalette p, String label, String value, double width) {
    final c = p.c;
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: monoStyle(p,
                  size: 9, color: c.faint, letterSpacing: 0.1),
            ),
            const SizedBox(height: 4),
            Text(value, style: bodyStyle(p, size: 13)),
          ],
        ),
      ),
    );
  }

  Widget _relatedRow(AppPalette p, Paper rel) {
    final c = p.c;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: c.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => widget.appState.openPaper(rel),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              NetImage(
                url: rel.coverImage,
                width: 40,
                height: 54,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rel.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          displayStyle(p, size: 13, weight: FontWeight.w400),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${rel.field} · ${rel.author}',
                      style: monoStyle(p, size: 10, color: c.faint),
                    ),
                  ],
                ),
              ),
              Text('›',
                  style: TextStyle(color: c.faint, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ comments

  Widget _buildCommentsTab(
    AppPalette p,
    Paper paper,
    AppUser? user,
  ) {
    final c = p.c;
    final a = p.accent;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: user == null
                ? Column(
                    children: [
                      const SizedBox(height: 10),
                      Text(
                        'Sign in to join the discussion',
                        textAlign: TextAlign.center,
                        style: bodyStyle(p, size: 14, color: c.muted),
                      ),
                      const SizedBox(height: 12),
                      GoldButton(
                        palette: p,
                        label: 'Sign In',
                        onPressed: widget.onAuthPrompt,
                        minHeight: 44,
                      ),
                      const SizedBox(height: 10),
                    ],
                  )
                : _CommentComposer(
                    palette: p,
                    user: user,
                    onPost: (text) =>
                        widget.appState.addComment(paper.id, text),
                  ),
          ),
          const SizedBox(height: 24),
          if (paper.comments.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    const Text('💬',
                        style: TextStyle(fontSize: 36)),
                    const SizedBox(height: 12),
                    Text(
                      'Be the first to comment',
                      style: displayStyle(p,
                          size: 16, color: c.muted),
                    ),
                  ],
                ),
              ),
            )
          else
            ...paper.comments.map(
                (comment) => _commentCard(p, paper, comment, user, a)),
        ],
      ),
    );
  }

  Widget _commentCard(
    AppPalette p,
    Paper paper,
    PaperComment comment,
    AppUser? user,
    AccentPalette a,
  ) {
    final c = p.c;
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
                      _fmtCommentDate(comment.createdAt),
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
                onTap: () {
                  if (user == null) {
                    widget.onAuthPrompt();
                    return;
                  }
                  widget.appState
                      .toggleCommentLike(paper.id, comment.id);
                },
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: c.border),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '♡',
                        style: TextStyle(
                          fontSize: 13,
                          color: liked ? a.accent : c.muted,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${comment.likes}',
                        style: TextStyle(
                          fontSize: 13,
                          color: liked ? a.accent : c.muted,
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

  // ---------------------------------------------------------------------- pdf

  Widget _buildPdfTab(AppPalette p, Paper paper) {
    final c = p.c;
    final url = paper.pdfUrl ?? '';
    final canEmbed = kIsWeb && url.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📄 Full Paper',
              style: displayStyle(p, size: 18, weight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (canEmbed)
            // On web the PDF renders inline in an iframe (Chrome's built-in
            // viewer). A bounded height is needed because the tab scrolls;
            // scale it to the viewport so it feels like a real document
            // viewer instead of a fixed 640px box.
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: (MediaQuery.of(context).size.height * 0.75)
                    .clamp(480.0, 900.0)
                    .toDouble(),
                child: buildPdfView(url),
              ),
            )
          else ...[
            Text(
              'The embedded PDF viewer is only available on web. Copy the link to open it in your browser.',
              style: bodyStyle(p, size: 14, color: c.textSub, height: 1.7),
            ),
            const SizedBox(height: 12),
            SelectableText(url, style: monoStyle(p, size: 11)),
          ],
          const SizedBox(height: 16),
          GoldButton(
            palette: p,
            label: 'Copy Link',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              widget.appState.showToast('Link copied', '🔗');
            },
          ),
        ],
      ),
    );
  }
}

/// Comment composer, extracted as its own [StatefulWidget] so typing in the
/// field only rebuilds the composer — previously `onChanged` called
/// `setState` on the whole reader screen per keystroke.
class _CommentComposer extends StatefulWidget {
  const _CommentComposer({
    required this.palette,
    required this.user,
    required this.onPost,
  });

  final AppPalette palette;
  final AppUser user;
  final ValueChanged<String> onPost;

  @override
  State<_CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<_CommentComposer> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final c = p.c;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AvatarImage(
          url: widget.user.avatar,
          size: 32,
          borderColor: c.border,
          borderWidth: 2,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TextField(
                controller: _ctrl,
                maxLines: 3,
                style: bodyStyle(p, size: 14),
                decoration: const InputDecoration(
                  hintText: 'Share your thoughts on this research…',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              GoldButton(
                palette: p,
                label: 'Post',
                onPressed: _ctrl.text.trim().isEmpty
                    ? null
                    : () {
                        widget.onPost(_ctrl.text.trim());
                        _ctrl.clear();
                        setState(() {});
                      },
                minHeight: 40,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
