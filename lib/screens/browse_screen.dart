/// Browse tab: the app's front door. Five inner tabs — Local Library
/// (the app's own submitted papers) plus E-books, Novels, Comics and
/// Manga. The catalog tabs are read-only: users browse and read there,
/// they never post. The active tab lives in [AppState.browseTab] (not
/// in this screen's local state) so the shell's Submit button and the
/// screen stay in sync, and the tab survives swipes.
library;

import 'package:flutter/material.dart';

import '../models/catalog.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/catalog_card.dart';
import '../widgets/shared.dart';
import 'library_screen.dart';

class BrowseScreen extends StatelessWidget {
  const BrowseScreen({
    super.key,
    required this.appState,
    required this.theme,
    required this.onAuthPrompt,
  });

  final AppState appState;
  final ThemeProvider theme;
  final VoidCallback onAuthPrompt;

  static const _tabs = <({BrowseTab tab, String label})>[
    (tab: BrowseTab.localLibrary, label: 'Local Library'),
    (tab: BrowseTab.ebooks, label: 'E-books'),
    (tab: BrowseTab.novels, label: 'Novels'),
    (tab: BrowseTab.comics, label: 'Comics'),
    (tab: BrowseTab.manga, label: 'Manga'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final tab = appState.browseTab;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _tabRow(p),
            Expanded(child: _tabBody(p, tab)),
          ],
        );
      },
    );
  }

  /// Horizontally scrollable tab strip, pinned above the tab content.
  /// Active tab gets the gold text + underline, like the desktop nav.
  Widget _tabRow(AppPalette p) {
    final c = p.c;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final t in _tabs)
              _browseTabButton(p, t, t.tab == appState.browseTab),
          ],
        ),
      ),
    );
  }

  Widget _browseTabButton(
      AppPalette p, ({BrowseTab tab, String label}) t, bool active) {
    final c = p.c;
    final a = p.accent;
    return InkWell(
      onTap: () => appState.setBrowseTab(t.tab),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? a.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          t.label,
          style: bodyStyle(
            p,
            size: 14,
            color: active ? a.accent : c.muted,
            weight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _tabBody(AppPalette p, BrowseTab tab) {
    switch (tab) {
      case BrowseTab.localLibrary:
        return LocalLibraryTab(
          appState: appState,
          theme: theme,
          onAuthPrompt: onAuthPrompt,
        );
      case BrowseTab.ebooks:
        return _EbooksTab(
          appState: appState,
          theme: theme,
          onAuthPrompt: onAuthPrompt,
        );
      case BrowseTab.novels:
        return _comingSoon(
          p,
          icon: Icons.auto_stories,
          title: 'Novels are on the way',
          sub: 'Free novels from Project Gutenberg land here in a later '
              'update — browse the Local Library for now.',
        );
      case BrowseTab.comics:
        return _comingSoon(
          p,
          icon: Icons.collections_bookmark,
          title: 'Comics are on the way',
          sub: 'Free comics from the Internet Archive land here in a '
              'later update — browse the Local Library for now.',
        );
      case BrowseTab.manga:
        return _comingSoon(
          p,
          icon: Icons.image,
          title: 'Manga is on the way',
          sub: 'Manga from MangaDex lands here in a later update — '
              'browse the Local Library for now.',
        );
    }
  }

  Widget _comingSoon(
    AppPalette p, {
    required IconData icon,
    required String title,
    required String sub,
  }) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
        child: EmptyState(
          palette: p,
          icon: icon,
          title: title,
          sub: sub,
        ),
      ),
    );
  }
}

/// E-books tab: free books from Open Library (full text from the
/// Internet Archive), read-only — users browse and read here, they
/// never post. Search is by title/author; Enter runs the search, the
/// clear button returns to the default education list.
class _EbooksTab extends StatefulWidget {
  const _EbooksTab({
    required this.appState,
    required this.theme,
    required this.onAuthPrompt,
  });

  final AppState appState;
  final ThemeProvider theme;
  final VoidCallback onAuthPrompt;

  @override
  State<_EbooksTab> createState() => _EbooksTabState();
}

class _EbooksTabState extends State<_EbooksTab> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.appState.fetchEbooks();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _runSearch() {
    widget.appState.fetchEbooks(
      search: _search,
      forceRefresh: true,
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _search = '');
    widget.appState.fetchEbooks(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.theme.palette;
    final c = p.c;
    final isNarrow = MediaQuery.of(context).size.width < 700;
    final appState = widget.appState;
    final books = appState.ebooks;
    final loading = appState.ebooksLoading;
    final failed = appState.ebooksError;

    return Column(
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
                onSubmitted: (_) => _runSearch(),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search free e-books…',
                  prefixIcon: Icon(Icons.search, color: c.faint, size: 20),
                  prefixIconConstraints: const BoxConstraints(minWidth: 44),
                  suffixIcon: _search.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: Icon(Icons.clear, color: c.faint, size: 18),
                          constraints: const BoxConstraints(
                              minWidth: 44, minHeight: 44),
                          onPressed: _clearSearch,
                        ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isNarrow ? 16 : 24,
                isNarrow ? 16 : 32,
                isNarrow ? 16 : 24,
                80,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: _body(p, books, loading, failed),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _body(
    AppPalette p,
    List<CatalogItem> books,
    bool loading,
    bool failed,
  ) {
    if (loading && books.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Column(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: p.accent.accent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading e-books…',
              style: bodyStyle(p, size: 13, color: p.c.faint),
            ),
          ],
        ),
      );
    }
    if (failed && books.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
        child: Column(
          children: [
            EmptyState(
              palette: p,
              icon: Icons.wifi_off,
              title: 'Could not load e-books',
              sub: 'Check your connection and try again.',
            ),
            const SizedBox(height: 20),
            GoldButton(
              palette: p,
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: _runSearch,
            ),
          ],
        ),
      );
    }
    if (books.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
        child: EmptyState(
          palette: p,
          icon: Icons.menu_book,
          title: 'No e-books found',
          sub: 'Try a different search.',
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, listConstraints) {
        final width = listConstraints.maxWidth;
        final columns = width < 700 ? 2 : width < 1100 ? 3 : 4;
        const spacing = 12.0;
        final cellWidth = (width - spacing * (columns - 1)) / columns;
        return SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.start,
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final book in books)
                SizedBox(
                  width: cellWidth,
                  child: RepaintBoundary(
                    child: CatalogCard(
                      key: ValueKey(book.id),
                      item: book,
                      appState: widget.appState,
                      theme: widget.theme,
                      onAuthPrompt: widget.onAuthPrompt,
                      onOpen: () => widget.appState.openCatalogItem(book),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
