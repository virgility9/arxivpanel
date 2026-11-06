/// Paper card ported from `PaperCard` in `src/components/LibraryView.tsx`.
///
/// Layout follows virgil's reference card (2026-11-07): a framed cover
/// image, the field in gold caps with the save button at the right end
/// of that row, a big bold title, "author · year", a divider, then the
/// action row — eye + views, comment, and a round accent button with a
/// heart that toggles a like. No tag chip, no badges on the cover, no
/// reaction count.
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
  /// The heart is a simple like: tap to like, tap again to unlike.
  /// A like is the heart reaction; an older emoji reaction is
  /// replaced by it, and tapping while liked removes it — the toggle
  /// in [AppState.reactToPaper] handles all three cases.
  void _toggleLike() {
    _requireAuth(
        () => widget.appState.reactToPaper(widget.paper.id, '❤️'));
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
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
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
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Field label, gold caps — like the reference card.
                // The save button sits at the right end of this row.
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        paper.field.toUpperCase(),
                        style: monoStyle(palette,
                            size: 10,
                            color: a.accent,
                            weight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _requireAuth(() =>
                          widget.appState.toggleBookmark(paper.id)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 6),
                        child: Icon(
                          bookmarked
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          size: 18,
                          color: bookmarked ? a.accent : c.muted,
                        ),
                      ),
                    ),
                  ],
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
                      // Left cluster takes whatever width remains after
                      // the reaction button, so the row can never
                      // overflow the card: a long views count ellipsizes
                      // instead of pushing the button off the edge (the
                      // 22px overflow on 2026-11-07 was this row at
                      // 156px in a 134px-wide phone cell).
                      Expanded(
                        child: Row(
                          children: [
                            _actionIcon(
                              icon: Icons.visibility_outlined,
                              size: isNarrow ? 16 : 18,
                              onTap: () =>
                                  widget.appState.openPaper(paper),
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                formatCount(paper.views),
                                style: monoStyle(palette,
                                    size: 10, color: c.faint),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _actionIcon(
                              icon: Icons.mode_comment_outlined,
                              size: isNarrow ? 16 : 18,
                              onTap: () =>
                                  widget.appState.openPaper(paper),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Like button — a round accent button with a
                      // heart, like the reference card. Tapping it
                      // likes or unlikes; there is no emoji picker.
                      GestureDetector(
                        onTap: _toggleLike,
                        child: Container(
                          width: isNarrow ? 36 : 44,
                          height: isNarrow ? 36 : 44,
                          decoration: BoxDecoration(
                            color: a.accent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            reacted != null
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: isNarrow ? 18 : 22,
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

  /// Small icon button for the views / comment slots in the action
  /// row. The icon stays compact; the padding keeps the tap target
  /// close to the 36/44px reaction button.
  Widget _actionIcon({
    required IconData icon,
    required VoidCallback onTap,
    double size = 18,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
        child: Icon(icon,
            size: size, color: color ?? widget.theme.palette.c.muted),
      ),
    );
  }
}
