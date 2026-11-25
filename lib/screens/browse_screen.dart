/// Browse tab: the app's front door. Five inner tabs — Local Library
/// (the app's own submitted papers) plus E-books, Novels, Light
/// Novels, and Manga and Comics (manga from MangaDex and comics from
/// the Internet Archive in one tab). The catalog tabs are read-only: users browse
/// and read there, they never post. The active tab lives in
/// [AppState.browseTab] (not in this screen's local state) so the
/// shell's Submit button and the screen stay in sync, and the tab
/// survives swipes.
library;

import 'package:flutter/material.dart';

import '../models/catalog.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../utils/debouncer.dart';
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
    (tab: BrowseTab.lightNovels, label: 'Light Novels'),
    (tab: BrowseTab.manga, label: 'Manga and Comics'),
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
        return _NovelsTab(
          appState: appState,
          theme: theme,
          onAuthPrompt: onAuthPrompt,
        );
      case BrowseTab.lightNovels:
        return _LightNovelsTab(
          appState: appState,
          theme: theme,
          onAuthPrompt: onAuthPrompt,
        );
      case BrowseTab.manga:
        return _MangaComicsTab(
          appState: appState,
          theme: theme,
          onAuthPrompt: onAuthPrompt,
        );
    }
  }

}

/// Load-more row under a catalog grid: a spinner while the next page
/// loads, else a Load more button when the source has more pages.
Widget _loadMoreRow(
  AppPalette p,
  bool loadingMore,
  VoidCallback onLoadMore,
) {
  if (loadingMore) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: p.accent.accent,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Loading more…',
          style: bodyStyle(p, size: 13, color: p.c.faint),
        ),
      ],
    );
  }
  return Center(
    child: GoldButton(
      palette: p,
      label: 'Load more',
      icon: Icons.expand_more,
      onPressed: onLoadMore,
    ),
  );
}

/// E-books tab: free books from Open Library (full text from the
/// Internet Archive), read-only — users browse and read here, they
/// never post. Search is debounced typeahead: typing pauses 300ms
/// then the search runs (Enter runs it at once); a repeat query is
/// answered from the 5-minute cache, so backspacing feels instant.
/// The clear button returns to the default education list.
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
  final Debouncer _debouncer = Debouncer();
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
    _debouncer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Runs the search for the current field text. No force-refresh by
  /// default, so a repeat query is answered from the cache; Retry
  /// passes forceRefresh to go to the network.
  void _runSearch({bool forceRefresh = false}) {
    widget.appState.fetchEbooks(
      search: _search,
      forceRefresh: forceRefresh,
    );
  }

  void _clearSearch() {
    _debouncer.cancel();
    _searchController.clear();
    setState(() => _search = '');
    widget.appState.fetchEbooks();
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
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) {
                        setState(() => _search = v);
                        _debouncer(() => _runSearch());
                      },
                      onSubmitted: (_) {
                        _debouncer.cancel();
                        _runSearch();
                      },
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search free e-books…',
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
                                onPressed: _clearSearch,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Reload',
                    icon: Icon(Icons.refresh, color: c.faint, size: 20),
                    constraints:
                        const BoxConstraints(minWidth: 44, minHeight: 44),
                    onPressed: () {
                      _debouncer.cancel();
                      _runSearch(forceRefresh: true);
                    },
                  ),
                ],
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
                  child: _body(
                    p,
                    books,
                    loading,
                    failed,
                    appState.ebooksHasMore,
                    appState.ebooksLoadingMore,
                    widget.appState.loadMoreEbooks,
                  ),
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
    bool hasMore,
    bool loadingMore,
    VoidCallback onLoadMore,
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
              onPressed: () => _runSearch(forceRefresh: true),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
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
        ),
        if (hasMore || loadingMore) ...[
          const SizedBox(height: 20),
          _loadMoreRow(p, loadingMore, onLoadMore),
        ],
      ],
    );
  }
}

/// Novels tab: free novels from Open Library (fiction subject, full
/// text from the Internet Archive), read-only — same shape as
/// [_EbooksTab]. Only novels with a readable full text are listed.
class _NovelsTab extends StatefulWidget {
  const _NovelsTab({
    required this.appState,
    required this.theme,
    required this.onAuthPrompt,
  });

  final AppState appState;
  final ThemeProvider theme;
  final VoidCallback onAuthPrompt;

  @override
  State<_NovelsTab> createState() => _NovelsTabState();
}

class _NovelsTabState extends State<_NovelsTab> {
  final TextEditingController _searchController = TextEditingController();
  final Debouncer _debouncer = Debouncer();
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.appState.fetchNovels();
    });
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _runSearch({bool forceRefresh = false}) {
    widget.appState.fetchNovels(
      search: _search,
      forceRefresh: forceRefresh,
    );
  }

  void _clearSearch() {
    _debouncer.cancel();
    _searchController.clear();
    setState(() => _search = '');
    widget.appState.fetchNovels();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.theme.palette;
    final c = p.c;
    final isNarrow = MediaQuery.of(context).size.width < 700;
    final appState = widget.appState;
    final books = appState.novels;
    final loading = appState.novelsLoading;
    final failed = appState.novelsError;

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
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) {
                        setState(() => _search = v);
                        _debouncer(() => _runSearch());
                      },
                      onSubmitted: (_) {
                        _debouncer.cancel();
                        _runSearch();
                      },
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search free novels…',
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
                                onPressed: _clearSearch,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Reload',
                    icon: Icon(Icons.refresh, color: c.faint, size: 20),
                    constraints:
                        const BoxConstraints(minWidth: 44, minHeight: 44),
                    onPressed: () {
                      _debouncer.cancel();
                      _runSearch(forceRefresh: true);
                    },
                  ),
                ],
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
                  child: _body(
                    p,
                    books,
                    loading,
                    failed,
                    appState.novelsHasMore,
                    appState.novelsLoadingMore,
                    widget.appState.loadMoreNovels,
                  ),
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
    bool hasMore,
    bool loadingMore,
    VoidCallback onLoadMore,
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
              'Loading novels…',
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
              title: 'Could not load novels',
              sub: 'Check your connection and try again.',
            ),
            const SizedBox(height: 20),
            GoldButton(
              palette: p,
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: () => _runSearch(forceRefresh: true),
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
          icon: Icons.auto_stories,
          title: 'No novels found',
          sub: 'Try a different search.',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
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
        ),
        if (hasMore || loadingMore) ...[
          const SizedBox(height: 20),
          _loadMoreRow(p, loadingMore, onLoadMore),
        ],
      ],
    );
  }
}

/// Light Novels tab: light novel volumes from RanobeDB (English
/// releases, newest first), read-only — same shape as [_NovelsTab].
/// RanobeDB is metadata only, so every listed volume stays and the
/// readable copy is resolved per item when its detail page opens.
class _LightNovelsTab extends StatefulWidget {
  const _LightNovelsTab({
    required this.appState,
    required this.theme,
    required this.onAuthPrompt,
  });

  final AppState appState;
  final ThemeProvider theme;
  final VoidCallback onAuthPrompt;

  @override
  State<_LightNovelsTab> createState() => _LightNovelsTabState();
}

class _LightNovelsTabState extends State<_LightNovelsTab> {
  final TextEditingController _searchController = TextEditingController();
  final Debouncer _debouncer = Debouncer();
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.appState.fetchLightNovels();
    });
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _runSearch({bool forceRefresh = false}) {
    widget.appState.fetchLightNovels(
      search: _search,
      forceRefresh: forceRefresh,
    );
  }

  void _clearSearch() {
    _debouncer.cancel();
    _searchController.clear();
    setState(() => _search = '');
    widget.appState.fetchLightNovels();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.theme.palette;
    final c = p.c;
    final isNarrow = MediaQuery.of(context).size.width < 700;
    final appState = widget.appState;
    final books = appState.lightNovels;
    final loading = appState.lightNovelsLoading;
    final failed = appState.lightNovelsError;

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
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) {
                        setState(() => _search = v);
                        _debouncer(() => _runSearch());
                      },
                      onSubmitted: (_) {
                        _debouncer.cancel();
                        _runSearch();
                      },
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search light novels…',
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
                                onPressed: _clearSearch,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Reload',
                    icon: Icon(Icons.refresh, color: c.faint, size: 20),
                    constraints:
                        const BoxConstraints(minWidth: 44, minHeight: 44),
                    onPressed: () {
                      _debouncer.cancel();
                      _runSearch(forceRefresh: true);
                    },
                  ),
                ],
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
                  child: _body(
                    p,
                    books,
                    loading,
                    failed,
                    appState.lightNovelsHasMore,
                    appState.lightNovelsLoadingMore,
                    widget.appState.loadMoreLightNovels,
                  ),
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
    bool hasMore,
    bool loadingMore,
    VoidCallback onLoadMore,
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
              'Loading light novels…',
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
              title: 'Could not load light novels',
              sub: 'Check your connection and try again.',
            ),
            const SizedBox(height: 20),
            GoldButton(
              palette: p,
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: () => _runSearch(forceRefresh: true),
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
          icon: Icons.auto_stories,
          title: 'No light novels found',
          sub: 'Try a different search.',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
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
        ),
        if (hasMore || loadingMore) ...[
          const SizedBox(height: 20),
          _loadMoreRow(p, loadingMore, onLoadMore),
        ],
      ],
    );
  }
}

/// Manga and Comics tab: manga from MangaDex (most followed first)
/// and comic issues from the Internet Archive (only issues with a
/// readable Text PDF), in one tab with a shared search — same shape
/// as [_EbooksTab], with one section per source. Tapping an item
/// opens its detail page (manga chapters, or the comic PDF viewer).
class _MangaComicsTab extends StatefulWidget {
  const _MangaComicsTab({
    required this.appState,
    required this.theme,
    required this.onAuthPrompt,
  });

  final AppState appState;
  final ThemeProvider theme;
  final VoidCallback onAuthPrompt;

  @override
  State<_MangaComicsTab> createState() => _MangaComicsTabState();
}

class _MangaComicsTabState extends State<_MangaComicsTab> {
  final TextEditingController _searchController = TextEditingController();
  final Debouncer _debouncer = Debouncer();
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.appState.fetchManga();
      widget.appState.fetchComics();
    });
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _runSearch({bool forceRefresh = false}) {
    widget.appState.fetchManga(
      search: _search,
      forceRefresh: forceRefresh,
    );
    widget.appState.fetchComics(
      search: _search,
      forceRefresh: forceRefresh,
    );
  }

  void _clearSearch() {
    _debouncer.cancel();
    _searchController.clear();
    setState(() => _search = '');
    widget.appState.fetchManga();
    widget.appState.fetchComics();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.theme.palette;
    final c = p.c;
    final isNarrow = MediaQuery.of(context).size.width < 700;
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
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) {
                        setState(() => _search = v);
                        _debouncer(() => _runSearch());
                      },
                      onSubmitted: (_) {
                        _debouncer.cancel();
                        _runSearch();
                      },
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search manga and comics…',
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
                                onPressed: _clearSearch,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Reload',
                    icon: Icon(Icons.refresh, color: c.faint, size: 20),
                    constraints:
                        const BoxConstraints(minWidth: 44, minHeight: 44),
                    onPressed: () {
                      _debouncer.cancel();
                      _runSearch(forceRefresh: true);
                    },
                  ),
                ],
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
                  child: _body(p),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _body(AppPalette p) {
    final appState = widget.appState;
    final manga = appState.manga;
    final comics = appState.comics;
    final mangaLoading = appState.mangaLoading;
    final comicsLoading = appState.comicsLoading;
    final mangaFailed = appState.mangaError;
    final comicsFailed = appState.comicsError;

    // Both lists still loading and both empty: one spinner.
    if ((mangaLoading || comicsLoading) &&
        manga.isEmpty &&
        comics.isEmpty) {
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
              'Loading manga and comics…',
              style: bodyStyle(p, size: 13, color: p.c.faint),
            ),
          ],
        ),
      );
    }
    // Both failed and both empty: one error state with Retry.
    if (mangaFailed && comicsFailed && manga.isEmpty && comics.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
        child: Column(
          children: [
            EmptyState(
              palette: p,
              icon: Icons.wifi_off,
              title: 'Could not load manga and comics',
              sub: 'Check your connection and try again.',
            ),
            const SizedBox(height: 20),
            GoldButton(
              palette: p,
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: () => _runSearch(forceRefresh: true),
            ),
          ],
        ),
      );
    }
    // Both empty (and settled): one empty state.
    if (manga.isEmpty &&
        comics.isEmpty &&
        !mangaLoading &&
        !comicsLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
        child: EmptyState(
          palette: p,
          icon: Icons.image,
          title: 'No manga or comics found',
          sub: 'Try a different search.',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section(
          p,
          'Manga',
          manga,
          mangaLoading,
          mangaFailed,
          appState.mangaHasMore,
          appState.mangaLoadingMore,
          widget.appState.loadMoreManga,
          () => widget.appState.fetchManga(
            search: _search,
            forceRefresh: true,
          ),
        ),
        const SizedBox(height: 28),
        _section(
          p,
          'Comics',
          comics,
          comicsLoading,
          comicsFailed,
          appState.comicsHasMore,
          appState.comicsLoadingMore,
          widget.appState.loadMoreComics,
          () => widget.appState.fetchComics(
            search: _search,
            forceRefresh: true,
          ),
        ),
      ],
    );
  }

  /// One source section: label with count, then its grid — or its
  /// own loading / error / empty state when it has no items yet.
  Widget _section(
    AppPalette p,
    String label,
    List<CatalogItem> items,
    bool loading,
    bool failed,
    bool hasMore,
    bool loadingMore,
    VoidCallback onLoadMore,
    VoidCallback onRetry,
  ) {
    final c = p.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          palette: p,
          text: items.isEmpty ? label : '$label · ${items.length}',
        ),
        const SizedBox(height: 12),
        if (loading && items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: p.accent.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Loading ${label.toLowerCase()}…',
                  style: bodyStyle(p, size: 13, color: c.faint),
                ),
              ],
            ),
          )
        else if (failed && items.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Could not load ${label.toLowerCase()}. Check your '
                  'connection and try again.',
                  style: bodyStyle(p, size: 13, color: c.textSub),
                ),
                const SizedBox(height: 10),
                GoldButton(
                  palette: p,
                  label: 'Retry',
                  icon: Icons.refresh,
                  onPressed: onRetry,
                  minHeight: 40,
                ),
              ],
            ),
          )
        else if (items.isEmpty)
          Text(
            'No ${label.toLowerCase()} found.',
            style: bodyStyle(p, size: 13, color: c.faint),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _grid(p, items),
              if (hasMore || loadingMore) ...[
                const SizedBox(height: 20),
                _loadMoreRow(p, loadingMore, onLoadMore),
              ],
            ],
          ),
      ],
    );
  }

  Widget _grid(AppPalette p, List<CatalogItem> items) {
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
              for (final item in items)
                SizedBox(
                  width: cellWidth,
                  child: RepaintBoundary(
                    child: CatalogCard(
                      key: ValueKey(item.id),
                      item: item,
                      appState: widget.appState,
                      theme: widget.theme,
                      onAuthPrompt: widget.onAuthPrompt,
                      onOpen: () => widget.appState.openCatalogItem(item),
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
