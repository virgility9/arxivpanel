/// Paper card ported from `PaperCard` in `src/components/LibraryView.tsx`.
///
/// Layout follows virgil's reference card (2026-11-07): a framed cover
/// image, the field in gold caps, a big bold title, "author · year",
/// a divider, then the action row — eye + views, comment, bookmark,
/// and a round accent button with a heart that opens the reaction
/// picker. No tag chip, no badges on the cover, no reaction count.
/// Sized for the library grid (2 columns on phones, 3–4 on wider
/// screens); the title is capped at 2 lines.
///
/// The card sizes to its own content (no Spacer, no Expanded): a short
/// title used to leave a big empty gap between the author row and the
/// action row, because the old fixed-height grid cell stretched the
/// card and the Spacer filled the slack. Now the action row sits
/// directly under the author row, and the grid (see
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
    final bookmarked = widget.appState.isBookmarked(paper.id);
    final isNarrow = MediaQuery.of(context).size.width < 700;
    final coverH = isNarrow ? 132.0 : 150.0;

    return Container(
      color: c.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cover — framed figure, like the reference card: inset
          // with a hairline border, no badges overlaid on the image.
          GestureDetector(
            onTap: () => widget.appState.openPaper(paper),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: c.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(1),
                  child: NetImage(
                    url: paper.coverImage,
                    width: double.infinity,
                    height: coverH,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ),
            ),
          ),
          // Content — no Expanded/Spacer here: the card must size to
          // its own content, or a short title leaves a big empty gap
          // above the action row (see header comment). Order follows
          // the reference card: field label, big title, author, then
          // the divider and the action row.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Field label, gold caps — like the reference card.
                Text(
                  paper.field.toUpperCase(),
                  style: monoStyle(palette,
                      size: 10, color: a.accent, weight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => widget.appState.openPaper(paper),
                  child: Text(
                    paper.title,
                    style: displayStyle(palette, size: isNarrow ? 19 : 21)
                        .copyWith(fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        paper.author,
                        style: bodyStyle(palette,
                            size: 12,
                            color: c.text,
                            weight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(' · ',
                        style: TextStyle(color: c.fainter, fontSize: 12)),
                    Text(paper.year,
                        style: monoStyle(palette, size: 10, color: c.faint)),
                  ],
                ),
                // Fixed gap, not a Spacer: the action row sits
                // directly under the author row.
                const SizedBox(height: 10),
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: c.surface2)),
                  ),
                  child: Row(
                    children: [
                      _actionIcon(
                        icon: Icons.visibility_outlined,
                        onTap: () => widget.appState.openPaper(paper),
                      ),
                      const SizedBox(width: 4),
                      Text(formatCount(paper.views),
                          style:
                              monoStyle(palette, size: 10, color: c.faint)),
                      const SizedBox(width: 12),
                      _actionIcon(
                        icon: Icons.mode_comment_outlined,
                        onTap: () => widget.appState.openPaper(paper),
                      ),
                      const SizedBox(width: 12),
                      _actionIcon(
                        icon: bookmarked
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        color: bookmarked ? a.accent : null,
                        onTap: () => _requireAuth(() =>
                            widget.appState.toggleBookmark(paper.id)),
                      ),
                      const Spacer(),
                      // Reaction picker trigger — a round accent button
                      // with a heart, like the reference card. The
                      // popover itself is an OverlayEntry (see
                      // _toggleReactions), so it dismisses on outside
                      // tap and never clips.
                      GestureDetector(
                        onTap: _toggleReactions,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: a.accent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            reacted != null
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 22,
                            color: a.accentFg,
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

  /// Small icon button for the views / comment / bookmark slots in the
  /// action row. The icon stays compact; the padding keeps the tap
  /// target close to the 44px reaction button.
  Widget _actionIcon({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Icon(icon,
            size: 18, color: color ?? widget.theme.palette.c.muted),
      ),
    );
  }
}
