/// Library screen: the "Reading Room" archive view ported from
/// `LibraryView.tsx`.
///
/// Hero section (eyebrow, serif title, counts), a search field, horizontally
/// scrollable field chips, a right-aligned sort row, then the filtered/sorted
/// paper list rendered with [PaperCard].
library;

import 'package:flutter/material.dart';

import '../data/constants.dart';
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
  String _field = 'All Fields';
  String _sort = 'popular';
  String _search = '';
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _sortOptions = ['popular', 'newest', 'views'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Paper> _filtered(List<Paper> papers) {
    final q = _search.trim().toLowerCase();
    final out = papers.where((p) {
      final matchField = _field == 'All Fields' || p.field == _field;
      final matchSearch = q.isEmpty ||
          p.title.toLowerCase().contains(q) ||
          p.author.toLowerCase().contains(q) ||
          p.tags.any((t) => t.toLowerCase().contains(q));
      return matchField && matchSearch;
    }).toList();

    int dateCompare(Paper a, Paper b) {
      DateTime pa;
      DateTime pb;
      try {
        pa = DateTime.parse(a.publishedAt);
      } catch (_) {
        pa = DateTime.fromMillisecondsSinceEpoch(0);
      }
      try {
        pb = DateTime.parse(b.publishedAt);
      } catch (_) {
        pb = DateTime.fromMillisecondsSinceEpoch(0);
      }
      return pb.compareTo(pa);
    }

    switch (_sort) {
      case 'newest':
        out.sort(dateCompare);
        break;
      case 'views':
        out.sort((a, b) => b.views.compareTo(a.views));
        break;
      case 'popular':
      default:
        out.sort((a, b) => b.totalReactions.compareTo(a.totalReactions));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.theme.palette;
    final c = p.c;
    final a = p.accent;

    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) {
        final papers = widget.appState.approvedPapers;
        final filtered = _filtered(papers);
        final isNarrow = MediaQuery.of(context).size.width < 700;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ------------------------------------------------ Hero ----
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
                    // Search + filter button. All filtering/sorting now
                    // lives in the bottom sheet — no horizontal swipe
                    // rows that can break on narrow screens.
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (v) => setState(() => _search = v),
                            decoration: InputDecoration(
                              hintText: 'Search titles, authors, tags…',
                              prefixIcon: Icon(Icons.search,
                                  color: c.faint, size: 20),
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
                        const SizedBox(width: 10),
                        _filterButton(p),
                      ],
                    ),
                  ),
                ),
              ),
              // ---------------------------------------- Paper list ----
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isNarrow ? 0 : 24,
                  isNarrow ? 20 : 40,
                  isNarrow ? 0 : 24,
                  80,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: !widget.appState.papersResolved
                        // First Firestore emission hasn't arrived yet —
                        // distinguish loading from genuinely empty.
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 64),
                            child: Center(
                              child: Column(
                                children: [
                                  CircularProgressIndicator(color: a.accent),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Loading the archive…',
                                    style:
                                        bodyStyle(p, size: 13, color: c.muted),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : filtered.isEmpty
                        ? EmptyState(
                            palette: p,
                            icon: '📭',
                            title: 'No papers found',
                            sub: 'Try a different search or field filter',
                          )
                        : isNarrow
                            // SizedBox forces the list to the full available
                            // width: without it the Column sizes itself from
                            // the cards' intrinsic width, and IntrinsicHeight
                            // + Expanded inside PaperCard can collapse that
                            // to a degenerate width (seen: the card Row laid
                            // out at 1px, so the 100px cover stuck out 99px).
                            ? SizedBox(
                                width: double.infinity,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (var i = 0;
                                        i < filtered.length;
                                        i++) ...[
                                      PaperCard(
                                        key: ValueKey(filtered[i].id),
                                        paper: filtered[i],
                                        appState: widget.appState,
                                        theme: widget.theme,
                                        onAuthPrompt: widget.onAuthPrompt,
                                      ),
                                      Container(height: 1, color: c.border),
                                    ],
                                  ],
                                ),
                              )
                            : LayoutBuilder(
                                builder: (context, listConstraints) {
                                  // Two-column Wrap instead of a fixed
                                  // childAspectRatio grid: cards keep their
                                  // intrinsic height, so long titles/tags can
                                  // never overflow the cell.
                                  final colWidth =
                                      (listConstraints.maxWidth - 1) / 2;
                                  return Wrap(
                                    spacing: 1,
                                    runSpacing: 1,
                                    children: [
                                      for (final paper in filtered)
                                        Container(
                                          width: colWidth,
                                          color: c.border,
                                          child: PaperCard(
                                            key: ValueKey(paper.id),
                                            paper: paper,
                                            appState: widget.appState,
                                            theme: widget.theme,
                                            onAuthPrompt: widget.onAuthPrompt,
                                          ),
                                        ),
                                    ],
                                  );
                                },
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

  /// Whether any filter differs from the defaults.
  bool get _hasActiveFilters => _field != 'All Fields' || _sort != 'popular';

  /// Tune-icon button beside the search field. Shows a gold dot while any
  /// filter is active; opens the filter bottom sheet on tap.
  Widget _filterButton(AppPalette p) {
    final c = p.c;
    final a = p.accent;
    final active = _hasActiveFilters;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => _openFilterSheet(p),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(color: active ? a.accent : c.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.tune,
                color: active ? a.accent : c.muted,
                size: 22,
              ),
            ),
          ),
        ),
        if (active)
          Positioned(
            top: -3,
            right: -3,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: a.accent,
                shape: BoxShape.circle,
                border: Border.all(color: c.surface, width: 2.5),
              ),
            ),
          ),
      ],
    );
  }

  /// Modern filter UI: a bottom sheet with the field chips in a Wrap (no
  /// horizontal swiping needed) and sort options as radio rows. The middle
  /// scrolls on short screens while the apply button stays pinned.
  void _openFilterSheet(AppPalette p) {
    final c = p.c;
    final a = p.accent;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final resultCount = _filtered(widget.appState.papers).length;
          final maxSheetHeight =
              MediaQuery.of(sheetCtx).size.height * 0.85;
          return Container(
            constraints: BoxConstraints(maxHeight: maxSheetHeight),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: c.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: [
                      Text(
                        'Filters',
                        style: displayStyle(p, size: 18).copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            _field = 'All Fields';
                            _sort = 'popular';
                          });
                          setState(() {
                            _field = 'All Fields';
                            _sort = 'popular';
                          });
                        },
                        child: Text(
                          'Reset',
                          style: bodyStyle(
                            p,
                            size: 13,
                            color: a.accent,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'FIELD',
                          style: monoStyle(
                            p,
                            size: 10,
                            color: c.faint,
                          ).copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final f in AppConstants.fields)
                              SelectChip(
                                palette: p,
                                label: f,
                                selected: _field == f,
                                onTap: () {
                                  setSheetState(() => _field = f);
                                  setState(() => _field = f);
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'SORT BY',
                          style: monoStyle(
                            p,
                            size: 10,
                            color: c.faint,
                          ).copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final s in _sortOptions) ...[
                          _sortOptionRow(p, s, setSheetState),
                          const SizedBox(height: 6),
                        ],
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(sheetCtx).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: a.accent,
                          foregroundColor: a.accentFg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Show $resultCount result${resultCount == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Full-width radio-style sort option row for the filter sheet.
  Widget _sortOptionRow(
      AppPalette p, String s, StateSetter setSheetState) {
    final c = p.c;
    final a = p.accent;
    final selected = _sort == s;
    final label = s[0].toUpperCase() + s.substring(1);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setSheetState(() => _sort = s);
          setState(() => _sort = s);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: selected
                ? a.accent.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? a.accent : c.border,
            ),
          ),
          child: Row(
            children: [
              Text(
                label,
                style: bodyStyle(
                  p,
                  size: 14,
                  weight:
                      selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              const Spacer(),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? a.accent : c.faint,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
