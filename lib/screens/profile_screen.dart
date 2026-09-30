/// Profile screen ported from `src/components/ProfilePage.tsx`.
///
/// Banner + overlapping identity row, edit-profile form, stats grid, and
/// tabbed lists (My Papers / History / Saved). Avatar file-upload from the
/// web app is intentionally skipped — the current avatar is kept.
library;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/shared.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.appState, required this.theme});

  final AppState appState;
  final ThemeProvider theme;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _tab = 0;
  bool _editing = false;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _instCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _webCtrl;

  @override
  void initState() {
    super.initState();
    final user = widget.appState.user;
    _nameCtrl = TextEditingController(text: user?.username ?? '');
    _instCtrl = TextEditingController(text: user?.institution ?? '');
    _bioCtrl = TextEditingController(text: user?.bio ?? '');
    _webCtrl = TextEditingController(text: user?.website ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _instCtrl.dispose();
    _bioCtrl.dispose();
    _webCtrl.dispose();
    super.dispose();
  }

  void _resetEditFields(AppUser user) {
    _nameCtrl.text = user.username;
    _instCtrl.text = user.institution ?? '';
    _bioCtrl.text = user.bio;
    _webCtrl.text = user.website ?? '';
  }

  void _save(AppUser user) {
    final username = _nameCtrl.text.trim();
    widget.appState.updateUser(
      user.copyWith(
        username: username.isEmpty ? user.username : username,
        institution: _instCtrl.text.trim(),
        bio: _bioCtrl.text,
        website: _webCtrl.text.trim(),
      ),
    );
    setState(() => _editing = false);
  }

  Future<void> _confirmDelete(Paper paper) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${paper.title}"?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE06B6B),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) widget.appState.deletePaper(paper.id);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.theme.palette;
    final c = p.c;
    final a = p.accent;

    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) {
        final user = widget.appState.user;
        if (user == null) return const SizedBox.shrink();

        final isNarrow = MediaQuery.of(context).size.width < 700;
        final bannerH = isNarrow ? 120.0 : 160.0;
        final avatarSize = isNarrow ? 72.0 : 96.0;
        final overlap = isNarrow ? 40.0 : 52.0;
        final hPad = isNarrow ? 16.0 : 24.0;

        // -------------------------------------------------- derived data
        final papers = widget.appState.papers;
        final myPapers = papers.where((pp) => pp.authorId == user.id).toList();
        final savedPapers = papers
            .where((pp) => widget.appState.bookmarks.contains(pp.id))
            .toList();

        final seen = <String>{};
        final historyPapers = <({Paper paper, ReadEntry entry})>[];
        for (final entry in widget.appState.readingHistory.reversed) {
          if (seen.contains(entry.paperId)) continue;
          final paper = widget.appState.paperById(entry.paperId);
          if (paper == null) continue;
          seen.add(entry.paperId);
          historyPapers.add((paper: paper, entry: entry));
        }

        final totalViews = myPapers.fold(0, (s, pp) => s + pp.views);
        final totalReactions = myPapers.fold(
          0,
          (s, pp) => s + pp.totalReactions,
        );
        final totalReadSeconds = widget.appState.readingHistory.fold(
          0,
          (s, e) => s + e.secondsSpent,
        );

        final tabs = [
          (label: 'My Papers', count: myPapers.length),
          (label: 'History', count: historyPapers.length),
          (label: 'Saved', count: savedPapers.length),
        ];

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ------------------------------------------------- banner
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: bannerH,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF1A1A2E),
                          const Color(0xFF16213E),
                          c.bg,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                      border: Border(bottom: BorderSide(color: c.border)),
                    ),
                  ),
                  // identity row overlapping the banner
                  Positioned(
                    top: bannerH - overlap,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 860),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: hPad),
                          child: _identityRow(p, c, user, isNarrow, avatarSize),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: avatarSize - overlap + 32),

              // -------------------------------------------------- body
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_editing)
                          _editForm(p, c, user, isNarrow)
                        else
                          _bioBlock(p, c, user),
                        const SizedBox(height: 28),
                        _statsGrid(
                          p,
                          isNarrow,
                          myPapers.length,
                          formatCount(totalViews),
                          totalReactions,
                          '${(totalReadSeconds / 60).round()}m',
                        ),
                        const SizedBox(height: 32),
                        _tabsRow(p, c, a, tabs, isNarrow),
                        const SizedBox(height: 24),
                        if (_tab == 0)
                          myPapers.isEmpty
                              ? EmptyState(
                                  palette: p,
                                  icon: '📝',
                                  title: 'No papers yet',
                                  sub:
                                      'Submit your first paper to see it here.',
                                )
                              : _paperList(
                                  p,
                                  c,
                                  myPapers,
                                  showStats: true,
                                  onDelete: _confirmDelete,
                                )
                        else if (_tab == 1)
                          historyPapers.isEmpty
                              ? EmptyState(
                                  palette: p,
                                  icon: '📖',
                                  title: 'No reading history',
                                  sub: 'Papers you open will appear here.',
                                )
                              : _historyList(p, c, historyPapers)
                        else
                          savedPapers.isEmpty
                              ? EmptyState(
                                  palette: p,
                                  icon: '🔖',
                                  title: 'No saved papers',
                                  sub:
                                      'Bookmark papers while reading to find them here.',
                                )
                              : _paperList(p, c, savedPapers),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: isNarrow ? 100 : 80),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------ sections

  Widget _identityRow(
    AppPalette p,
    AppColors c,
    AppUser user,
    bool isNarrow,
    double avatarSize,
  ) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 16,
      runSpacing: 12,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: p.accent.accent.withValues(alpha: 0.25),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: AvatarImage(
                url: user.avatar,
                size: avatarSize,
                borderColor: p.accent.accent,
                borderWidth: 3,
              ),
            ),
            const SizedBox(width: 16),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.username,
                    style: displayStyle(
                      p,
                      size: isNarrow ? 20 : 26,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (user.institution != null && user.institution!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        user.institution!,
                        style: monoStyle(p, size: 11, color: c.muted),
                      ),
                    ),
                  Text(
                    'Joined ${formatMonthYear(user.joinedAt)}',
                    style: monoStyle(p, size: 10, color: c.fainter),
                  ),
                ],
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GhostButton(
                palette: p,
                label: _editing ? 'Cancel' : 'Edit Profile',
                color: _editing ? const Color(0xFFE06B6B) : null,
                onPressed: () {
                  setState(() {
                    if (!_editing) _resetEditFields(user);
                    _editing = !_editing;
                  });
                },
              ),
              const SizedBox(width: 8),
              GhostButton(
                palette: p,
                label: 'Sign Out',
                color: const Color(0xFFE06B6B),
                onPressed: widget.appState.logout,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _editForm(AppPalette p, AppColors c, AppUser user, bool isNarrow) {
    final nameField = LabeledField(
      palette: p,
      label: 'Display Name',
      child: TextField(controller: _nameCtrl, style: bodyStyle(p, size: 14)),
    );
    final instField = LabeledField(
      palette: p,
      label: 'Institution',
      child: TextField(
        controller: _instCtrl,
        style: bodyStyle(p, size: 14),
        decoration: const InputDecoration(hintText: 'University / Lab'),
      ),
    );
    return Container(
      padding: EdgeInsets.all(isNarrow ? 16 : 24),
      margin: const EdgeInsets.only(bottom: 28),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Edit Profile', style: displayStyle(p, size: 17)),
          const SizedBox(height: 16),
          if (isNarrow) ...[
            nameField,
            const SizedBox(height: 14),
            instField,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: nameField),
                const SizedBox(width: 14),
                Expanded(child: instField),
              ],
            ),
          const SizedBox(height: 14),
          LabeledField(
            palette: p,
            label: 'Bio',
            child: TextField(
              controller: _bioCtrl,
              maxLines: 3,
              style: bodyStyle(p, size: 14),
              decoration: const InputDecoration(
                hintText: 'Tell the research community about yourself…',
              ),
            ),
          ),
          const SizedBox(height: 14),
          LabeledField(
            palette: p,
            label: 'Website / ORCID',
            child: TextField(
              controller: _webCtrl,
              style: bodyStyle(p, size: 14),
              decoration: const InputDecoration(
                hintText: 'https://orcid.org/…',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: GoldButton(
              palette: p,
              label: 'Save Changes',
              minHeight: 40,
              onPressed: () => _save(user),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bioBlock(AppPalette p, AppColors c, AppUser user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (user.bio.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              user.bio,
              style: bodyStyle(p, size: 14, color: c.textSub, height: 1.7),
            ),
          ),
        if (user.website != null && user.website!.isNotEmpty)
          Text(user.website!, style: monoStyle(p, size: 11, color: p.info)),
      ],
    );
  }

  Widget _statsGrid(
    AppPalette p,
    bool isNarrow,
    int papers,
    String views,
    int reactions,
    String readTime,
  ) {
    return GridView.count(
      crossAxisCount: isNarrow ? 2 : 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.75,
      children: [
        StatTile(
          palette: p,
          icon: '📄',
          value: '$papers',
          label: 'Papers',
          color: p.accent.accent,
        ),
        StatTile(
          palette: p,
          icon: '👁',
          value: views,
          label: 'Total Views',
          color: const Color(0xFF7C6AF7),
        ),
        StatTile(
          palette: p,
          icon: '🔥',
          value: '$reactions',
          label: 'Reactions received',
          color: const Color(0xFFE06B6B),
        ),
        StatTile(
          palette: p,
          icon: '⏱',
          value: readTime,
          label: 'Read time',
          color: const Color(0xFF4ADE80),
        ),
      ],
    );
  }

  Widget _tabsRow(
    AppPalette p,
    AppColors c,
    AccentPalette a,
    List<({String label, int count})> tabs,
    bool isNarrow,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            InkWell(
              onTap: () => setState(() => _tab = i),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isNarrow ? 14 : 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _tab == i ? a.accent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tabs[i].label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: _tab == i
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: _tab == i ? a.accent : c.muted,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: c.surface2,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${tabs[i].count}',
                        style: monoStyle(p, size: 11, color: c.muted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _paperRow(
    AppPalette p,
    AppColors c,
    Paper paper, {
    bool showStats = false,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: () => widget.appState.openPaper(paper),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.borderFaint)),
        ),
        child: Row(
          children: [
            NetImage(
              url: paper.coverImage,
              width: 40,
              height: 54,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    paper.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: displayStyle(
                      p,
                      size: showStats ? 14 : 13,
                      weight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 10,
                    runSpacing: 2,
                    children: [
                      Text(paper.field, style: monoStyle(p, size: 10)),
                      if (showStats) ...[
                        Text(
                          '${formatCount(paper.views)} views',
                          style: monoStyle(p, size: 10),
                        ),
                        Text(
                          '${paper.totalReactions} reactions',
                          style: monoStyle(p, size: 10),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Text('›', style: TextStyle(color: c.fainter, fontSize: 14)),
            ?trailing,
          ],
        ),
      ),
    );
  }

  Widget _paperList(
    AppPalette p,
    AppColors c,
    List<Paper> papers, {
    bool showStats = false,
    Future<void> Function(Paper paper)? onDelete,
  }) {
    return Column(
      children: [
        for (final paper in papers)
          _paperRow(
            p,
            c,
            paper,
            showStats: showStats,
            trailing: onDelete == null
                ? null
                : IconButton(
                    onPressed: () => onDelete(paper),
                    tooltip: 'Delete paper',
                    icon: const Text('🗑', style: TextStyle(fontSize: 16)),
                  ),
          ),
      ],
    );
  }

  Widget _historyList(
    AppPalette p,
    AppColors c,
    List<({Paper paper, ReadEntry entry})> items,
  ) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return Column(
      children: [
        for (final item in items)
          InkWell(
            onTap: () => widget.appState.openPaper(item.paper),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.borderFaint)),
              ),
              child: Row(
                children: [
                  NetImage(
                    url: item.paper.coverImage,
                    width: 40,
                    height: 54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.paper.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: displayStyle(
                            p,
                            size: 13,
                            weight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${months[item.entry.readAt.month - 1]} ${item.entry.readAt.day} · '
                          '${(item.entry.secondsSpent / 60).round()}m spent',
                          style: monoStyle(p, size: 10),
                        ),
                      ],
                    ),
                  ),
                  Text('›', style: TextStyle(color: c.fainter, fontSize: 14)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
