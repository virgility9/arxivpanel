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

  String get _typeLabel => switch (item.type) {
        CatalogType.ebook => 'E-BOOK',
        CatalogType.novel => 'NOVEL',
        CatalogType.comic => 'COMIC',
        CatalogType.manga => 'MANGA',
      };

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
    final coverH = isNarrow ? 132.0 : 150.0;
    final titleStyle = displayStyle(palette, size: isNarrow ? 19 : 21)
        .copyWith(fontWeight: FontWeight.w700);

    return PressScale(
      child: Container(
        color: c.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover — framed figure, same as the paper card. No cover
            // from the source? A plain block with a book icon instead
            // of a broken-image icon.
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
                    child: item.coverUrl != null
                        ? NetImage(
                            url: item.coverUrl!,
                            width: double.infinity,
                            height: coverH,
                            borderRadius: BorderRadius.circular(7),
                          )
                        : Container(
                            height: coverH,
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
