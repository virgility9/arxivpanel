/// Library tab: the user's saved collection — everything bookmarked,
/// grouped by type, so nothing has to be browsed for twice. Papers
/// first, then the catalog sections (e-books, novels, comics, manga).
/// Read-only collection: posting happens from Browse's Local Library tab.
library;

import 'package:flutter/material.dart';

import '../models/catalog.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/catalog_card.dart';
import '../widgets/paper_card.dart';
import '../widgets/shared.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.appState,
    required this.theme,
    required this.onAuthPrompt,
  });

  final AppState appState;
  final ThemeProvider theme;
  final VoidCallback onAuthPrompt;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

/// How the saved books are grouped. Papers always come first, in their
/// own section, because they use a different card.
enum _GroupBy { type, none }

enum _SortBy { recent, title, author }

enum _ViewMode { grid, list }

/// One section of saved catalog items (a type, or "all").
class _SaveGroup {
  const _SaveGroup(this.key, this.label, this.saves);
  final String key;
  final String label;
  final List<CatalogSave> saves;
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _search = '';
  final TextEditingController _searchController = TextEditingController();

  _GroupBy _groupBy = _GroupBy.type;
  _SortBy _sortBy = _SortBy.recent;
  _ViewMode _view = _ViewMode.grid;

  /// Keys of the sections the user folded away.
  final Set<String> _collapsed = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(String q, String title, String author) =>
      q.isEmpty ||
      title.toLowerCase().contains(q) ||
      author.toLowerCase().contains(q);

  static int _cmpText(String a, String b) =>
      a.toLowerCase().compareTo(b.toLowerCase());

  /// Saved catalog items for the current search, ordered by [_sortBy].
  List<CatalogSave> _sortedSaves(String q) {
    final saves = widget.appState.catalogSaves
        .where((save) => _matches(q, save.title, save.author))
        .toList();
    switch (_sortBy) {
      case _SortBy.recent:
        saves.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      case _SortBy.title:
        saves.sort((a, b) => _cmpText(a.title, b.title));
      case _SortBy.author:
        saves.sort((a, b) => _cmpText(a.author, b.author));
    }
    return saves;
  }

  /// Splits [saves] (already sorted) into sections. By type: e-books,
  /// novels, light novels, then manga and comics (one Browse tab, so one
  /// group). With "Recent" the sections are ordered by their newest
  /// save, so what you saved last is on top; otherwise the fixed order
  /// above. "None" is one flat section.
  List<_SaveGroup> _groupsFor(List<CatalogSave> saves) {
    if (saves.isEmpty) return const [];
    if (_groupBy == _GroupBy.none) {
      return [_SaveGroup('all', 'ALL SAVED', saves)];
    }
    bool isManga(CatalogSave s) =>
        s.type == CatalogType.comic || s.type == CatalogType.manga;
    final groups = <_SaveGroup>[
      _SaveGroup('ebooks', 'E-BOOKS',
          saves.where((s) => s.type == CatalogType.ebook).toList()),
      _SaveGroup('novels', 'NOVELS',
          saves.where((s) => s.type == CatalogType.novel).toList()),
      _SaveGroup('lightNovels', 'LIGHT NOVELS',
          saves.where((s) => s.type == CatalogType.lightNovel).toList()),
      _SaveGroup('manga', 'MANGA AND COMICS', saves.where(isManga).toList()),
    ].where((g) => g.saves.isNotEmpty).toList();
    if (_sortBy == _SortBy.recent) {
      groups.sort((a, b) => b.saves.first.savedAt
          .compareTo(a.saves.first.savedAt));
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.theme.palette;
    final c = p.c;
    final isNarrow = MediaQuery.of(context).size.width < 700;

    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) {
        final user = widget.appState.user;
        if (user == null) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
              child: Center(
                child: Column(
                  children: [
                    EmptyState(
                      palette: p,
                      icon: Icons.bookmark,
                      title: 'Sign in to see your saved collection',
                      sub: 'Your saved papers, books, comics and manga '
                          'live here once you sign in.',
                    ),
                    const SizedBox(height: 20),
                    GoldButton(
                      palette: p,
                      label: 'Sign in',
                      minHeight: 44,
                      onPressed: widget.onAuthPrompt,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final saved = [
          for (final id in widget.appState.bookmarks)
            widget.appState.paperById(id),
        ].whereType<Paper>().toList();
        switch (_sortBy) {
          case _SortBy.recent:
            saved.sort((a, b) => _dateOf(b).compareTo(_dateOf(a)));
          case _SortBy.title:
            saved.sort((a, b) => _cmpText(a.title, b.title));
          case _SortBy.author:
            saved.sort((a, b) => _cmpText(a.author, b.author));
        }
        final q = _search.trim().toLowerCase();
        final filtered = saved.where((paper) {
          return q.isEmpty ||
              paper.title.toLowerCase().contains(q) ||
              paper.author.toLowerCase().contains(q) ||
              paper.tags.any((t) => t.toLowerCase().contains(q));
        }).toList();
        final groups = _groupsFor(_sortedSaves(q));
        final hasCatalogSaves = groups.isNotEmpty;
        final anySavedAtAll =
            saved.isNotEmpty || widget.appState.catalogSaves.isNotEmpty;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search row (same shape as the Local Library hero).
              Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: c.border)),
                ),
                padding: EdgeInsets.fromLTRB(
                  isNarrow ? 16 : 24,
                  isNarrow ? 16 : 24,
                  isNarrow ? 16 : 24,
                  isNarrow ? 16 : 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _search = v),
                      decoration: InputDecoration(
                        hintText:
                            'Search your saved papers, books, light novels, comics and manga…',
                        prefixIcon:
                            Icon(Icons.search, color: c.faint, size: 20),
                        prefixIconConstraints:
                            const BoxConstraints(minWidth: 44),
                        suffixIcon: _search.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                icon: Icon(Icons.clear,
                                    color: c.faint, size: 18),
                                constraints: const BoxConstraints(
                                    minWidth: 44, minHeight: 44),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _search = '');
                                },
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isNarrow ? 16 : 24,
                  isNarrow ? 12 : 20,
                  isNarrow ? 16 : 24,
                  80,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: filtered.isEmpty && !hasCatalogSaves
                        ? EmptyState(
                            palette: p,
                            icon: Icons.bookmark,
                            title: !anySavedAtAll
                                ? 'Nothing saved yet'
                                : 'No saved items found',
                            sub: !anySavedAtAll
                                ? 'Tap the bookmark on a paper, a book, '
                                    'a light novel, a comic or a manga to keep it here.'
                                : 'Try a different search',
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _controls(p, showGroup: hasCatalogSaves),
                              const SizedBox(height: 6),
                              if (filtered.isNotEmpty)
                                _section(
                                  p,
                                  key: 'papers',
                                  label: 'PAPERS · ${filtered.length}',
                                  body: _papersGrid(filtered),
                                ),
                              for (final g in groups)
                                _section(
                                  p,
                                  key: g.key,
                                  label: '${g.label} · ${g.saves.length}',
                                  body: _view == _ViewMode.grid
                                      ? _catalogGrid(g.saves)
                                      : _catalogList(g.saves),
                                ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // Controls: group / sort / view
  // -------------------------------------------------------------------------

  Widget _controls(AppPalette p, {required bool showGroup}) {
    return Wrap(
      spacing: 20,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (showGroup)
          _segmented<_GroupBy>(
            p,
            label: 'GROUP',
            value: _groupBy,
            options: const {_GroupBy.type: 'Type', _GroupBy.none: 'None'},
            onChanged: (v) => setState(() => _groupBy = v),
          ),
        _segmented<_SortBy>(
          p,
          label: 'SORT',
          value: _sortBy,
          options: const {
            _SortBy.recent: 'Recent',
            _SortBy.title: 'Title',
            _SortBy.author: 'Author',
          },
          onChanged: (v) => setState(() => _sortBy = v),
        ),
        if (showGroup) _viewToggle(p),
      ],
    );
  }

  Widget _chip(
    AppPalette p, {
    required bool selected,
    required VoidCallback onTap,
    required Widget child,
    String? semanticLabel,
  }) {
    final c = p.c;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 34),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.surface2 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? c.border : Colors.transparent,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _segmented<T>(
    AppPalette p, {
    required String label,
    required T value,
    required Map<T, String> options,
    required ValueChanged<T> onChanged,
  }) {
    final c = p.c;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: monoStyle(p, size: 10, color: c.faint)),
        const SizedBox(width: 8),
        for (final e in options.entries)
          _chip(
            p,
            selected: e.key == value,
            onTap: () => onChanged(e.key),
            child: Text(
              e.value,
              style: bodyStyle(
                p,
                size: 13,
                color: e.key == value ? c.text : c.muted,
                weight: e.key == value ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
      ],
    );
  }

  Widget _viewToggle(AppPalette p) {
    final c = p.c;
    Widget icon(_ViewMode mode, IconData data, String label) => _chip(
          p,
          selected: _view == mode,
          semanticLabel: label,
          onTap: () => setState(() => _view = mode),
          child: Icon(
            data,
            size: 18,
            color: _view == mode ? c.text : c.muted,
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon(_ViewMode.grid, Icons.grid_view_rounded, 'Grid view'),
        icon(_ViewMode.list, Icons.view_list_rounded, 'List view'),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Sections
  // -------------------------------------------------------------------------

  /// One collapsible section: gold caps label with its count, a hairline,
  /// and a chevron. Tapping the header folds the body away.
  Widget _section(
    AppPalette p, {
    required String key,
    required String label,
    required Widget body,
  }) {
    final c = p.c;
    final collapsed = _collapsed.contains(key);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: !collapsed,
            child: InkWell(
              onTap: () => setState(() {
                if (!_collapsed.remove(key)) _collapsed.add(key);
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Text(
                      label,
                      style: monoStyle(p, size: 10, color: p.accent.accent)
                          .copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.12,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        color: c.border,
                      ),
                    ),
                    AnimatedRotation(
                      turns: collapsed ? -0.25 : 0,
                      duration: const Duration(milliseconds: 160),
                      child: Icon(Icons.expand_more, size: 20, color: c.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: collapsed
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: body,
                  ),
          ),
        ],
      ),
    );
  }

  /// Saved papers grid: the paper card is unchanged (same columns as
  /// before).
  Widget _papersGrid(List<Paper> papers) {
    return LayoutBuilder(
      builder: (context, listConstraints) {
        final width = listConstraints.maxWidth;
        final columns = width < 700
            ? 2
            : width < 1100
                ? 3
                : 4;
        const spacing = 12.0;
        final cellWidth = (width - spacing * (columns - 1)) / columns;
        return SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.start,
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final paper in papers)
                SizedBox(
                  width: cellWidth,
                  child: RepaintBoundary(
                    child: PaperCard(
                      key: ValueKey(paper.id),
                      paper: paper,
                      appState: widget.appState,
                      theme: widget.theme,
                      onAuthPrompt: widget.onAuthPrompt,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Saved items are snapshots, so the card's item is rebuilt from the
  /// save — the stored IA ids keep the chapters working without a
  /// source fetch.
  CatalogItem _itemFor(CatalogSave save) => CatalogItem(
        id: save.id,
        type: save.type,
        title: save.title,
        authors: [save.author],
        subjects: const [],
        iaIds: save.iaIds,
        coverUrl: save.coverUrl,
        synopsis: save.synopsis,
      );

  /// Compact grid: three columns on a phone, so about six books fit on
  /// one screen instead of two.
  Widget _catalogGrid(List<CatalogSave> saves) {
    return LayoutBuilder(
      builder: (context, listConstraints) {
        final width = listConstraints.maxWidth;
        final columns = width < 700
            ? 3
            : width < 1100
                ? 5
                : 6;
        const spacing = 12.0;
        final cellWidth = (width - spacing * (columns - 1)) / columns;
        return SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.start,
            spacing: spacing,
            runSpacing: 18,
            children: [
              for (final save in saves)
                SizedBox(
                  width: cellWidth,
                  child: RepaintBoundary(
                    child: Builder(builder: (context) {
                      final item = _itemFor(save);
                      return CatalogCompactCard(
                        key: ValueKey(item.id),
                        item: item,
                        appState: widget.appState,
                        theme: widget.theme,
                        onOpen: () => widget.appState.openCatalogItem(item),
                      );
                    }),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// One row per book; the type label shows only when the list is not
  /// already grouped by type.
  Widget _catalogList(List<CatalogSave> saves) {
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final save in saves)
              Builder(builder: (context) {
                final item = _itemFor(save);
                return CatalogListTile(
                  key: ValueKey(item.id),
                  item: item,
                  appState: widget.appState,
                  theme: widget.theme,
                  showType: _groupBy == _GroupBy.none,
                  onOpen: () => widget.appState.openCatalogItem(item),
                );
              }),
          ],
        ),
      ),
    );
  }

  static DateTime _dateOf(Paper paper) {
    try {
      return DateTime.parse(paper.publishedAt);
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }
}
