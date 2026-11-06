/// Paper card ported from `PaperCard` in `src/components/LibraryView.tsx`.
///
/// Vertical grid card: cover image on top with field + page badges, then
/// title, author row, one tag chip, and a bottom action row (views,
/// comments, bookmark, reaction picker). Sized for the library grid
/// (2 columns on phones, 3–4 on wider screens): the title is capped at
/// 2 lines and only the first tag is shown.
///
/// The card sizes to its own content (no Spacer, no Expanded): a short
/// title with no tags used to leave a big empty gap between the author
/// row and the action row, because the old fixed-height grid cell
/// stretched the card and the Spacer filled the slack. Now the action
/// row sits directly under the author/tag rows, and the grid (see
/// library_screen.dart) lays the cards out at their own heights.
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
  /// The reaction popover lives in the app [Overlay] (not in the card's own
  /// stack) so it dismisses on outside tap and never clips at card edges.
  OverlayEntry? _reactionOverlay;

  @override
  void dispose() {
    _removeReactionOverlay();
    super.dispose();
  }

  void _removeReactionOverlay() {
    _reactionOverlay?.remove();
    _reactionOverlay = null;
  }

  void _toggleReactions() {
    if (_reactionOverlay != null) {
      _removeReactionOverlay();
      return;
    }
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (ctx) {
        final screen = MediaQuery.of(ctx).size;
        // Anchor the popover above the card's bottom-right action area.
        const pickerWidth = 300.0;
        const pickerHeight = 60.0;
        var left = screen.width - pickerWidth - 16;
        var top = screen.height - pickerHeight - 120;
        final cardBox = context.findRenderObject() as RenderBox?;
        if (cardBox != null && cardBox.hasSize) {
          final pos = cardBox.localToGlobal(Offset.zero);
          left = pos.dx + cardBox.size.width - pickerWidth - 8;
          top = pos.dy + cardBox.size.height - pickerHeight - 52;
        }
        // clamp() returns num; toDouble() keeps the inferred double type.
        left = left.clamp(8.0, screen.width - pickerWidth - 8).toDouble();
        top = top.clamp(8.0, screen.height - pickerHeight - 8).toDouble();
        return Stack(
          children: [
            // Outside-tap scrim: transparent, closes the popover.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _removeReactionOverlay,
              ),
            ),
            Positioned(
              left: left,
              top: top,
              child: _reactionPopover(ctx),
            ),
          ],
        );
      },
    );
    _reactionOverlay = entry;
    overlay.insert(entry);
  }

  /// The emoji popover rendered inside the overlay.
  Widget _reactionPopover(BuildContext ctx) {
    final palette = widget.theme.palette;
    final c = palette.c;
    final a = palette.accent;
    final paper = widget.paper;
    final user = widget.appState.user;
    final reacted = user == null ? null : paper.reactionOf(user.id);
    return Material(
      color: c.surface,
      elevation: 6,
      shadowColor: c.shadow,
      borderRadius: BorderRadius.circular(12),
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
                _requireAuth(
                    () => widget.appState.reactToPaper(paper.id, emoji));
                _removeReactionOverlay();
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: active
                      ? a.accent.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

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
    final coverH = isNarrow ? 132.0 : 150.0;

    return Container(
      color: c.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cover
          GestureDetector(
            onTap: () => widget.appState.openPaper(paper),
            child: SizedBox(
              height: coverH,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NetImage(url: paper.coverImage),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          c.surface.withValues(alpha: 0.0),
                          c.surface
                        ],
                        stops: const [0.4, 0.7, 1.0],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _miniBadge(
                        paper.field.split(' ').first.toUpperCase(), a.accent),
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
          // Content — no Expanded/Spacer here: the card must size to
          // its own content, or a short title with no tags leaves a
          // big empty gap above the action row (see header comment).
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => widget.appState.openPaper(paper),
                  child: Text(
                    paper.title,
                    style: displayStyle(palette, size: isNarrow ? 15 : 16),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    AvatarImage(
                        url: paper.authorAvatar,
                        size: 18,
                        borderColor: c.border,
                        borderWidth: 1),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        paper.author,
                        style: bodyStyle(palette, size: 11, color: c.muted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('·',
                        style: TextStyle(color: c.fainter, fontSize: 10)),
                    const SizedBox(width: 4),
                    Text(paper.year,
                        style: monoStyle(palette, size: 10, color: c.faint)),
                  ],
                ),
                const SizedBox(height: 6),
                if (paper.tags.isNotEmpty)
                  Row(
                    children: [
                      Flexible(
                        child: TagChip(
                            palette: palette, tag: paper.tags.first),
                      ),
                    ],
                  ),
                // Fixed gap, not a Spacer: the action row sits
                // directly under the author/tag rows.
                const SizedBox(height: 10),
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: c.surface2)),
                  ),
                  child: Row(
                    children: [
                      Text('${formatCount(paper.views)}v',
                          style:
                              monoStyle(palette, size: 10, color: c.faint)),
                      const SizedBox(width: 8),
                      Text('${paper.comments.length}💬',
                          style:
                              monoStyle(palette, size: 10, color: c.faint)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _requireAuth(() =>
                            widget.appState.toggleBookmark(paper.id)),
                        child: Padding(
                          // Visual stays compact; hit area meets 44px.
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 10),
                          child: Text(
                            bookmarked ? '🔖' : '🏷️',
                            style: TextStyle(
                              fontSize: 14,
                              color: bookmarked ? a.accent : c.fainter,
                            ),
                          ),
                        ),
                      ),
                      // Reaction picker trigger — the popover itself is
                      // an OverlayEntry (see _toggleReactions), so it
                      // dismisses on outside tap and never clips.
                      GestureDetector(
                        onTap: _toggleReactions,
                        // Extra vertical padding keeps the pill compact
                        // while the tap target meets the 44px minimum.
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: reacted != null
                                  ? a.accent.withValues(alpha: 0.15)
                                  : c.surface2,
                              border: Border.all(
                                  color: reacted != null
                                      ? a.accent
                                      : c.border),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(reacted ?? '+',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: reacted != null
                                            ? a.accent
                                            : c.muted)),
                                const SizedBox(width: 4),
                                Text('$totalReactions',
                                    style: monoStyle(palette, size: 10)),
                              ],
                            ),
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
    );
  }

  Widget _miniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: widget.theme.palette.c.bg.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: monoStyle(widget.theme.palette, size: 9, color: color),
      ),
    );
  }
}
