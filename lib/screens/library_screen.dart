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
        final disciplines = papers.map((e) => e.field).toSet().length;
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
                  isNarrow ? 32 : 48,
                  isNarrow ? 16 : 24,
                  isNarrow ? 24 : 36,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'RESEARCH ARCHIVE — VOL. 2026',
                          style: monoStyle(
                            p,
                            size: 10,
                            color: a.accent,
                            letterSpacing: 0.15,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        _TitleBlock(
                          palette: p,
                          isNarrow: isNarrow,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${papers.length} papers · $disciplines disciplines',
                          style: bodyStyle(p, size: 14, color: c.muted),
                        ),
                        const SizedBox(height: 20),
                        // Search
                        TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _search = v),
                          decoration: InputDecoration(
                            hintText: 'Search titles, authors, tags…',
                            prefixIcon: Icon(Icons.search, color: c.faint, size: 20),
                            prefixIconConstraints: const BoxConstraints(minWidth: 44),
                            suffixIcon: _search.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear search',
                                    icon: Icon(Icons.clear, color: c.faint, size: 18),
                                    constraints: const BoxConstraints(
                                        minWidth: 44, minHeight: 44),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _search = '');
                                    },
                                  ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Field chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final f in AppConstants.fields)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: SelectChip(
                                    palette: p,
                                    label: f,
                                    selected: _field == f,
                                    onTap: () => setState(() => _field = f),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Sort row (right aligned)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            for (final s in _sortOptions)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: _SortChip(
                                  palette: p,
                                  label: s[0].toUpperCase() + s.substring(1),
                                  selected: _sort == s,
                                  onTap: () => setState(() => _sort = s),
                                ),
                              ),
                          ],
                        ),
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
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (var i = 0; i < filtered.length; i++) ...[
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
}

/// Two-line serif hero title: "The Scholars'" then italic accent "Reading Room".
class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.palette, required this.isNarrow});

  final AppPalette palette;
  final bool isNarrow;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: displayStyle(palette, size: isNarrow ? 34 : 52, weight: FontWeight.w700, height: 1.1),
        children: [
          const TextSpan(text: 'The Scholars\'\n'),
          TextSpan(
            text: 'Reading Room',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: palette.accent.accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sort option chip: mono font, selected gets surface2 bg + accent
/// border/text. Uses [InkWell] for ripple + semantics, and a 44px minimum
/// tap height.
class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.palette,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AppPalette palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = palette.c;
    final a = palette.accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.surface2 : Colors.transparent,
            border: Border.all(color: selected ? a.accent : c.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: monoStyle(
              palette,
              size: 11,
              color: selected ? a.accent : c.muted,
            ).copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
          ),
        ),
      ),
    );
  }
}
