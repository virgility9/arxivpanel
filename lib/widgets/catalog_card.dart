/// Catalog card for the Browse grids and the saved Library. Follows
/// [PaperCard]'s layout language — framed cover, gold caps type label
/// with the save button at the right end of that row, big bold serif
/// title, author — but no action row: liking and commenting live on the
/// detail screen, where the per-item streams are active (a list card
/// cannot know an item's like state without a stream per card).
library;

import 'package:flutter/material.dart';

import '../models/catalog.dart';
import '../state/app_state.dart';
import '../theme/theme_provider.dart';
import 'motion.dart';
import 'shared.dart';

/// Gold-caps label for a catalog type, shared by every card style.
String catalogTypeLabel(CatalogType type) => switch (type) {
      CatalogType.ebook => 'E-BOOK',
      CatalogType.novel => 'NOVEL',
      CatalogType.comic => 'COMIC',
      CatalogType.manga => 'MANGA',
    };

class CatalogCard extends StatelessWidget {
  const CatalogCard({
    super.key,
    required this.item,
    required this.appState,
    required this.theme,
    required this.onOpen,
    this.onAuthPrompt,
  });

  final CatalogItem item;
  final AppState appState;
  final ThemeProvider theme;
  final VoidCallback onOpen;
  final VoidCallback? onAuthPrompt;

  String get _typeLabel => catalogTypeLabel(item.type);

  void _toggleSave() {
    if (appState.user == null) {
      onAuthPrompt?.call();
      return;
    }
    appState.toggleCatalogSave(item);
  }

  @override
  Widget build(BuildContext context) {
    final palette = theme.palette;
    final c = palette.c;
    final a = palette.accent;
    final saved = appState.isCatalogSaved(item.id);
    final isNarrow = MediaQuery.of(context).size.width < 700;
    final titleStyle = displayStyle(palette, size: isNarrow ? 19 : 21)
        .copyWith(fontWeight: FontWeight.w700);

    return PressScale(
      child: Container(
        color: c.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover — framed figure, same as the paper card. Portrait
            // frame (3:4): covers are portrait art — book covers,
            // manga covers, comic issues — so the frame matches them
            // and NetImage's contain fit shows the whole image
            // instead of stretching or cutting it. No cover from the
            // source? A plain block with a book icon instead of a
            // broken-image icon.
            GestureDetector(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: c.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(1),
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: item.coverUrl != null
                          ? NetImage(
                              url: item.coverUrl!,
                              width: double.infinity,
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
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type label, gold caps — the save button sits at the
                  // right end of this row, like the paper card.
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _typeLabel,
                          style: monoStyle(palette,
                              size: 10,
                              color: a.accent,
                              weight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: _toggleSave,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 6),
                          child: PopIcon(
                            active: saved,
                            child: Icon(
                              saved
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              size: 18,
                              color: saved ? a.accent : c.muted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Title always occupies exactly two lines of height,
                  // so a short or long title never changes the card's
                  // size — same hidden-placeholder trick as PaperCard.
                  GestureDetector(
                    onTap: onOpen,
                    child: Stack(
                      children: [
                        ExcludeSemantics(
                          child: Opacity(
                            opacity: 0,
                            child: Text(
                              '\n',
                              style: titleStyle,
                              maxLines: 2,
                            ),
                          ),
                        ),
                        Text(
                          item.title,
                          style: titleStyle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.authorLabel,
                    style: bodyStyle(palette,
                        size: 12, color: c.text, weight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Framed portrait cover shared by the compact card and the list row.
/// The whole image shows (contain), like [CatalogCard]; no cover from
/// the source gets a plain block with a book icon.
class _CompactCover extends StatelessWidget {
  const _CompactCover({
    required this.url,
    required this.theme,
    this.width,
    this.height,
  });

  final String? url;
  final ThemeProvider theme;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final c = theme.palette.c;
    final radius = BorderRadius.circular(6);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border.all(color: c.border),
        borderRadius: radius,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: url != null
            ? NetImage(
                url: url!,
                width: width ?? double.infinity,
                height: height,
              )
            : Center(child: Icon(Icons.menu_book, size: 24, color: c.muted)),
      ),
    );
  }
}

/// Small filled bookmark used over a compact cover; tapping it removes
/// the save. The tap area is larger than the drawn chip.
class _UnsaveChip extends StatelessWidget {
  const _UnsaveChip({required this.theme, required this.onTap});

  final ThemeProvider theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = theme.palette;
    return Semantics(
      button: true,
      label: 'Remove from saved',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: palette.c.bg.withValues(alpha: 0.78),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bookmark,
                size: 16,
                color: palette.accent.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dense card for the saved Library grid: cover, two-line title and
/// author. The saved collection is already grouped by type, so there is
/// no type label here (the group header says it), and the bookmark is a
/// small chip over the cover — everything on this screen is saved.
class CatalogCompactCard extends StatelessWidget {
  const CatalogCompactCard({
    super.key,
    required this.item,
    required this.appState,
    required this.theme,
    required this.onOpen,
  });

  final CatalogItem item;
  final AppState appState;
  final ThemeProvider theme;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = theme.palette;
    final c = palette.c;
    return PressScale(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: onOpen,
                child: AspectRatio(
                  aspectRatio: 2 / 3,
                  child: _CompactCover(url: item.coverUrl, theme: theme),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: _UnsaveChip(
                  theme: theme,
                  onTap: () => appState.toggleCatalogSave(item),
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: onOpen,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: displayStyle(palette, size: 14, height: 1.25)
                        .copyWith(fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.authorLabel,
                    style: bodyStyle(palette, size: 11, color: c.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One-line-per-book row for the saved Library list view. [showType]
/// adds the gold type label — wanted when the list is not grouped by
/// type, redundant under a type header.
class CatalogListTile extends StatelessWidget {
  const CatalogListTile({
    super.key,
    required this.item,
    required this.appState,
    required this.theme,
    required this.onOpen,
    this.showType = false,
  });

  final CatalogItem item;
  final AppState appState;
  final ThemeProvider theme;
  final VoidCallback onOpen;
  final bool showType;

  @override
  Widget build(BuildContext context) {
    final palette = theme.palette;
    final c = palette.c;
    return InkWell(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.borderFaint)),
        ),
        child: Row(
          children: [
            _CompactCover(
              url: item.coverUrl,
              theme: theme,
              width: 46,
              height: 66,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showType) ...[
                    Text(
                      catalogTypeLabel(item.type),
                      style: monoStyle(palette,
                          size: 9,
                          color: palette.accent.accent,
                          weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                  ],
                  Text(
                    item.title,
                    style: displayStyle(palette, size: 15, height: 1.25)
                        .copyWith(fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.authorLabel,
                    style: bodyStyle(palette, size: 12, color: c.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            _UnsaveChip(
              theme: theme,
              onTap: () => appState.toggleCatalogSave(item),
            ),
          ],
        ),
      ),
    );
  }
}
