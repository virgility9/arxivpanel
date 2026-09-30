/// Polls / Community Rankings screen, ported from `PollsView.tsx`.
///
/// Papers ranked by community engagement with a metric tab switcher
/// (Most Reacted / Most Read / Most Discussed), a top-3 medal podium,
/// an animated full rankings list, and a "how rankings work" insight box.
library;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/shared.dart';

/// Hardcoded contest accent (matches `#7c6af7` in PollsView.tsx).
const _violet = Color(0xFF7C6AF7);

/// Medal colors for the top 3 ranks.
const _medalColors = <Color>[
  Color(0xFFE8B04B), // gold
  Color(0xFFB0B8C1), // silver
  Color(0xFFCD7F32), // bronze
];

/// Medal-tinted card backgrounds (React `MEDAL_BG` values).
const _medalBgs = <Color>[
  Color(0x1FE8B04B), // rgba(232,176,75,0.12)
  Color(0x14B0B8C1), // rgba(176,184,193,0.08)
  Color(0x1ACD7F32), // rgba(205,127,50,0.10)
];

/// Medal-tinted card borders (React `MEDAL_BORDER` values).
const _medalBorders = <Color>[
  Color(0x66E8B04B), // rgba(232,176,75,0.4)
  Color(0x40B0B8C1), // rgba(176,184,193,0.25)
  Color(0x4DCD7F32), // rgba(205,127,50,0.3)
];

const _medals = <String>['🥇', '🥈', '🥉'];

class PollsScreen extends StatefulWidget {
  const PollsScreen({super.key, required this.appState, required this.theme});

  final AppState appState;
  final ThemeProvider theme;

  @override
  State<PollsScreen> createState() => _PollsScreenState();
}

enum _Metric { reactions, views, comments }

class _PollsScreenState extends State<PollsScreen> {
  _Metric _metric = _Metric.reactions;

  AppPalette get p => widget.theme.palette;
  AppColors get c => p.c;

  int _score(Paper paper) {
    switch (_metric) {
      case _Metric.reactions:
        return paper.totalReactions;
      case _Metric.views:
        return paper.views;
      case _Metric.comments:
        return paper.comments.length;
    }
  }

  String _scoreLabel() {
    switch (_metric) {
      case _Metric.reactions:
        return 'reactions';
      case _Metric.views:
        return 'views';
      case _Metric.comments:
        return 'comments';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ranked = [...widget.appState.papers]
      ..sort((a, b) => _score(b).compareTo(_score(a)));
    final maxScore = ranked.isEmpty ? 1 : (_score(ranked.first) == 0 ? 1 : _score(ranked.first));
    final wide = MediaQuery.of(context).size.width >= 700;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(wide),
          _buildTabs(),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  wide ? 24 : 16,
                  wide ? 40 : 24,
                  wide ? 24 : 16,
                  wide ? 80 : 100, // bottom padding for mobile nav
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPodium(ranked, wide),
                    _buildRankingsList(ranked, maxScore, wide),
                    const SizedBox(height: 40),
                    _buildInsightBox(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ header

  Widget _buildHeader(bool wide) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              wide ? 24 : 16,
              wide ? 44 : 28,
              wide ? 24 : 16,
              wide ? 32 : 20,
            ),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'COMMUNITY RANKINGS',
                    style: monoStyle(
                      p,
                      size: 10,
                      weight: FontWeight.w400,
                      color: _violet,
                      letterSpacing: 0.15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  RichText(
                    text: TextSpan(
                      style: displayStyle(
                        p,
                        size: wide ? 44 : 28,
                        weight: FontWeight.w700,
                        height: 1.1,
                      ),
                      children: const [
                        TextSpan(text: 'Popularity '),
                        TextSpan(
                          text: 'Contest',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: _violet,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Papers ranked by real community engagement — reactions, reading time, and discussion.',
                    style: bodyStyle(p, size: 14, color: c.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------- tabs

  Widget _buildTabs() {
    final tabs = [
      (key: _Metric.reactions, icon: '🔥', label: 'Most Reacted'),
      (key: _Metric.views, icon: '👁', label: 'Most Read'),
      (key: _Metric.comments, icon: '💬', label: 'Most Discussed'),
    ];
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
        color: c.bg,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Row(
            children: [
              for (final tab in tabs)
                _MetricTab(
                  icon: tab.icon,
                  label: tab.label,
                  active: _metric == tab.key,
                  activeColor: _violet,
                  onTap: () => setState(() => _metric = tab.key),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ podium

  Widget _buildPodium(List<Paper> ranked, bool wide) {
    final top3 = ranked.take(3).toList();
    if (top3.isEmpty) {
      return EmptyState(
        palette: p,
        icon: '🏆',
        title: 'No papers ranked yet',
        sub: 'Rankings will appear here once papers gather engagement.',
      );
    }
    final cards = [
      for (var i = 0; i < top3.length; i++)
        _PodiumCard(
          paper: top3[i],
          index: i,
          wide: wide,
          score: _score(top3[i]),
          scoreLabel: _scoreLabel(),
          onTap: () => widget.appState.openPaper(top3[i]),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 16),
                  Expanded(child: cards[i]),
                ],
              ],
            )
          : Column(
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  cards[i],
                ],
              ],
            ),
    );
  }

  // ------------------------------------------------------------- ranked list

  Widget _buildRankingsList(List<Paper> ranked, int maxScore, bool wide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            'FULL RANKINGS',
            style: monoStyle(
              p,
              size: 10,
              color: c.faint,
              letterSpacing: 0.1,
            ),
          ),
        ),
        for (var i = 0; i < ranked.length; i++)
          _RankingRow(
            paper: ranked[i],
            index: i,
            wide: wide,
            score: _score(ranked[i]),
            maxScore: maxScore,
            onTap: () => widget.appState.openPaper(ranked[i]),
          ),
      ],
    );
  }

  // -------------------------------------------------------------- insight

  Widget _buildInsightBox() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: _violet, width: 3)),
        ),
        padding: const EdgeInsets.only(left: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HOW RANKINGS WORK',
              style: monoStyle(
                p,
                size: 10,
                color: _violet,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: bodyStyle(p, size: 13, color: c.muted, height: 1.7),
                children: const [
                  TextSpan(
                    text: 'Most Reacted',
                    style: TextStyle(color: Color(0xFFB0A898), fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: ' counts all emoji reactions (🔥🧠👏❤️✨🌱) left by readers. '),
                  TextSpan(
                    text: 'Most Read',
                    style: TextStyle(color: Color(0xFFB0A898), fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: ' counts unique page opens. '),
                  TextSpan(
                    text: 'Most Discussed',
                    style: TextStyle(color: Color(0xFFB0A898), fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: ' counts comments. Rankings update as you read and react.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Metric tab (2px bottom indicator, violet when active)
// ---------------------------------------------------------------------------

class _MetricTab extends StatelessWidget {
  const _MetricTab({
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = const Color(0xFF7A7690);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? activeColor : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active ? activeColor : muted,
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Podium card
// ---------------------------------------------------------------------------

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({
    required this.paper,
    required this.index,
    required this.wide,
    required this.score,
    required this.scoreLabel,
    required this.onTap,
  });

  final Paper paper;
  final int index;
  final bool wide;
  final int score;
  final String scoreLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final medalColor = _medalColors[index];
    return Material(
      color: _medalBgs[index],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _medalBorders[index], width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: wide ? _verticalLayout(medalColor) : _horizontalLayout(medalColor),
      ),
    );
  }

  Widget _cover(double width, double height, Color medalColor) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          NetImage(url: paper.coverImage, width: width, height: height),
          // gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: wide ? Alignment.topCenter : Alignment.centerLeft,
                  end: wide ? Alignment.bottomCenter : Alignment.centerRight,
                  colors: wide
                      ? const [Colors.transparent, Color(0xCC0C0C12)]
                      : const [Colors.transparent, Color(0x800C0C12)],
                  stops: const [0.3, 1.0],
                ),
              ),
            ),
          ),
          // medal overlay top-left
          Positioned(
            top: 10,
            left: 10,
            child: Text(
              _medals[index],
              style: TextStyle(fontSize: wide ? 24 : 20, height: 1),
            ),
          ),
          // big rank number bottom-right (wide only)
          if (wide)
            Positioned(
              bottom: 10,
              right: 12,
              child: Text(
                '#${index + 1}',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: medalColor.withValues(alpha: 0.6),
                  height: 1,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _info(Color medalColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          paper.title,
          style: const TextStyle(
            fontFamily: 'serif',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFFE4DFD0),
            height: 1.35,
          ),
          maxLines: wide ? 4 : 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          '${paper.author} · ${paper.year}',
          style: const TextStyle(fontSize: 11, color: Color(0xFF7A7690)),
        ),
        const Spacer(),
        Row(
          children: [
            Text(
              formatCount(score),
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: wide ? 24 : 20,
                fontWeight: FontWeight.w700,
                color: medalColor,
                height: 1,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              scoreLabel,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: Color(0xFF5A5668),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _verticalLayout(Color medalColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cover(double.infinity, 160, medalColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: SizedBox(height: 170, child: _info(medalColor)),
          ),
        ],
      ),
    );
  }

  Widget _horizontalLayout(Color medalColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10.5),
      child: Row(
        children: [
          _cover(90, 110, medalColor),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              // Fixed height so _info's Spacer has a bounded constraint.
              child: SizedBox(height: 82, child: _info(medalColor)),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Animated ranking row
// ---------------------------------------------------------------------------

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.paper,
    required this.index,
    required this.wide,
    required this.score,
    required this.maxScore,
    required this.onTap,
  });

  final Paper paper;
  final int index;
  final bool wide;
  final int score;
  final int maxScore;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isTop3 = index < 3;
    final accent = isTop3 ? _medalColors[index] : _violet;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: wide ? 14 : 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF1C1C2A))),
          ),
          child: Row(
            children: [
              // rank
              SizedBox(
                width: wide ? 36 : 28,
                child: Center(
                  child: isTop3
                      ? Text(
                          _medals[index],
                          style: TextStyle(fontSize: wide ? 22 : 18, height: 1),
                        )
                      : Text(
                          '#${index + 1}',
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: wide ? 16 : 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF3A3A50),
                            height: 1,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              // cover thumb
              NetImage(
                url: paper.coverImage,
                width: wide ? 48 : 40,
                height: wide ? 64 : 54,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(width: 14),
              // title + bar
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paper.title,
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: wide ? 14 : 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFE4DFD0),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C1C2A),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: TweenAnimationBuilder<double>(
                                key: ValueKey('bar_${paper.id}'),
                                tween: Tween(begin: 0, end: score / maxScore),
                                duration: const Duration(milliseconds: 900),
                                builder: (context, value, _) {
                                  return FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: value.clamp(0.0, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            accent,
                                            accent.withValues(alpha: 0.53),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatCount(score),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: isTop3 ? _medalColors[index] : const Color(0xFF7A7690),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '›',
                style: TextStyle(color: Color(0xFF3A3A50), fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
