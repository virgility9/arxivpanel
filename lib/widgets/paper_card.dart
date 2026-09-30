/// Paper card ported from `PaperCard` in `src/components/LibraryView.tsx`.
///
/// Horizontal card: cover strip on the left with field + page badges, then
/// title, author row, tag chips, and a bottom action row (views, comments,
/// bookmark, reaction picker).
library;

import 'package:flutter/material.dart';

import '../data/constants.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/theme_provider.dart';
import 'shared.dart';

class PaperCard extends StatefulWidget {
  const PaperCard({
    super.key,
    required this.paper,
    required this.appState,
    required this.theme,
    this.onAuthPrompt,
  });

  final Paper paper;
  final AppState appState;
  final ThemeProvider theme;
  final VoidCallback? onAuthPrompt;

  @override
  State<PaperCard> createState() => _PaperCardState();
}

class _PaperCardState extends State<PaperCard> {
  bool _showReactions = false;

  void _requireAuth(VoidCallback action) {
    if (widget.appState.user == null) {
      widget.onAuthPrompt?.call();
      return;
    }
    action();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.theme.palette;
    final c = palette.c;
    final a = palette.accent;
    final paper = widget.paper;
    final user = widget.appState.user;
    final reacted = user == null ? null : paper.reactionOf(user.id);
    final totalReactions = paper.totalReactions;
    final bookmarked = widget.appState.isBookmarked(paper.id);
    final isNarrow = MediaQuery.of(context).size.width < 700;

    return Container(
      color: c.surface,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover strip
            GestureDetector(
              onTap: () => widget.appState.openPaper(paper),
              child: SizedBox(
                width: isNarrow ? 100 : 120,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NetImage(url: paper.coverImage),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, c.surface.withValues(alpha: 0.0), c.surface],
                          stops: const [0.4, 0.7, 1.0],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _miniBadge(paper.field.split(' ').first.toUpperCase(), a.accent),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: _miniBadge('${paper.pages}p', c.faint),
                    ),
                  ],
                ),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => widget.appState.openPaper(paper),
                      child: Text(
                        paper.title,
                        style: displayStyle(palette, size: isNarrow ? 15 : 16),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        AvatarImage(url: paper.authorAvatar, size: 18, borderColor: c.border, borderWidth: 1),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            paper.author,
                            style: bodyStyle(palette, size: 11, color: c.muted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text('·', style: TextStyle(color: c.fainter, fontSize: 10)),
                        const SizedBox(width: 4),
                        Text(paper.year, style: monoStyle(palette, size: 10, color: c.faint)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: paper.tags.take(2).map((t) => TagChip(palette: palette, tag: t)).toList(),
                    ),
                    const Spacer(),
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: c.surface2)),
                      ),
                      child: Row(
                        children: [
                          Text('${formatCount(paper.views)}v', style: monoStyle(palette, size: 10, color: c.faint)),
                          const SizedBox(width: 8),
                          Text('${paper.comments.length}💬', style: monoStyle(palette, size: 10, color: c.faint)),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => _requireAuth(() => widget.appState.toggleBookmark(paper.id)),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Text(
                                bookmarked ? '🔖' : '🏷️',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: bookmarked ? a.accent : c.fainter,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          // Reaction picker
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              if (_showReactions)
                                Positioned(
                                  bottom: 40,
                                  right: 0,
                                  child: Material(
                                    color: c.surface,
                                    elevation: 8,
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: c.border),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: AppConstants.reactions.map((emoji) {
                                          final active = reacted == emoji;
                                          return GestureDetector(
                                            onTap: () {
                                              _requireAuth(() => widget.appState.reactToPaper(paper.id, emoji));
                                              setState(() => _showReactions = false);
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: active ? a.accent.withValues(alpha: 0.2) : Colors.transparent,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(emoji, style: const TextStyle(fontSize: 22)),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                              GestureDetector(
                                onTap: () => setState(() => _showReactions = !_showReactions),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: reacted != null ? a.accent.withValues(alpha: 0.15) : c.surface2,
                                    border: Border.all(color: reacted != null ? a.accent : c.border),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(reacted ?? '+', style: TextStyle(fontSize: 13, color: reacted != null ? a.accent : c.muted)),
                                      const SizedBox(width: 4),
                                      Text('$totalReactions', style: monoStyle(palette, size: 10)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C12).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 9,
          color: color,
          letterSpacing: 0.06,
        ),
      ),
    );
  }
}
