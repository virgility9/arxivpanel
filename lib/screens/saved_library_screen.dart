/// Library tab: the user's saved collection — everything bookmarked,
/// grouped by type, so nothing has to be browsed for twice. Papers
/// first (Phase 2 adds the saved catalog sections here). Read-only
/// collection: posting happens from Browse's Local Library tab.
library;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
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

class _LibraryScreenState extends State<LibraryScreen> {
  String _search = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
                      sub: 'Your saved papers and books live here once '
                          'you sign in.',
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
        saved.sort((a, b) => _dateOf(b).compareTo(_dateOf(a)));
        final q = _search.trim().toLowerCase();
        final filtered = saved.where((paper) {
          return q.isEmpty ||
              paper.title.toLowerCase().contains(q) ||
              paper.author.toLowerCase().contains(q) ||
              paper.tags.any((t) => t.toLowerCase().contains(q));
        }).toList();

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
                        hintText: 'Search your saved papers…',
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
                  isNarrow ? 16 : 32,
                  isNarrow ? 16 : 24,
                  80,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: filtered.isEmpty
                        ? EmptyState(
                            palette: p,
                            icon: Icons.bookmark,
                            title: saved.isEmpty
                                ? 'Nothing saved yet'
                                : 'No saved papers found',
                            sub: saved.isEmpty
                                ? 'Tap the bookmark on a paper to keep '
                                    'it here.'
                                : 'Try a different search',
                          )
                        : Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              _sectionLabel(
                                  p, 'PAPERS · ${filtered.length}'),
                              const SizedBox(height: 14),
                              LayoutBuilder(
                                builder: (context, listConstraints) {
                                  final width = listConstraints.maxWidth;
                                  final columns = width < 700
                                      ? 2
                                      : width < 1100
                                          ? 3
                                          : 4;
                                  const spacing = 12.0;
                                  final cellWidth = (width -
                                          spacing * (columns - 1)) /
                                      columns;
                                  return SizedBox(
                                    width: double.infinity,
                                    child: Wrap(
                                      alignment: WrapAlignment.start,
                                      spacing: spacing,
                                      runSpacing: spacing,
                                      children: [
                                        for (final paper in filtered)
                                          SizedBox(
                                            width: cellWidth,
                                            child: RepaintBoundary(
                                              child: PaperCard(
                                                key: ValueKey(paper.id),
                                                paper: paper,
                                                appState: widget.appState,
                                                theme: widget.theme,
                                                onAuthPrompt:
                                                    widget.onAuthPrompt,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
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

  /// Gold caps group label, matching the app's section-label style.
  Widget _sectionLabel(AppPalette p, String label) {
    return Text(
      label,
      style: monoStyle(p, size: 10, color: p.accent.accent).copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.12,
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
