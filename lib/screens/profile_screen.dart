/// Profile screen: centered identity header (avatar, name, joined date),
/// Edit Profile / Sign Out actions, 2×2 stat cards, and tabbed lists
/// (My Papers / History / Saved).
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/shared.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen(
      {super.key,
      required this.appState,
      required this.theme,
      required this.onAuthPrompt});

  final AppState appState;
  final ThemeProvider theme;
  final VoidCallback onAuthPrompt;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _tab = 0;

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

  /// Persists the edit dialog form, then closes the dialog on success.
  Future<void> _save(BuildContext dialogCtx, AppUser user) async {
    final username = _nameCtrl.text.trim();
    try {
      await widget.appState.updateUser(
        user.copyWith(
          username: username.isEmpty ? user.username : username,
          institution: _instCtrl.text.trim(),
          bio: _bioCtrl.text,
          website: _webCtrl.text.trim(),
        ),
      );
      if (!mounted) return;
      Navigator.of(dialogCtx).pop();
    } catch (_) {
      // updateUser already toasts on success; surface failures too instead
      // of leaving the dialog open with no feedback.
      widget.appState.showToast('Could not save profile', '⚠️');
    }
  }

  /// Edit-profile dialog: display name, institution, bio, website.
  Future<void> _openEditDialog(AppUser user) async {
    _resetEditFields(user);
    final p = widget.theme.palette;
    final c = p.c;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        title: Text(
          'Edit Profile',
          style: displayStyle(p, size: 18, weight: FontWeight.w600),
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LabeledField(
                  palette: p,
                  label: 'Display Name',
                  child: TextField(
                    controller: _nameCtrl,
                    style: bodyStyle(p, size: 14),
                  ),
                ),
                const SizedBox(height: 12),
                LabeledField(
                  palette: p,
                  label: 'Institution',
                  child: TextField(
                    controller: _instCtrl,
                    style: bodyStyle(p, size: 14),
                    decoration: const InputDecoration(
                      hintText: 'University / Lab',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                LabeledField(
                  palette: p,
                  label: 'Bio',
                  child: TextField(
                    controller: _bioCtrl,
                    maxLines: 3,
                    style: bodyStyle(p, size: 14),
                    decoration: const InputDecoration(
                      hintText:
                          'Tell the research community about yourself…',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
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
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: c.muted)),
          ),
          GoldButton(
            palette: p,
            label: 'Save Changes',
            minHeight: 40,
            onPressed: () => _save(ctx, user),
          ),
        ],
      ),
    );
  }

  /// Sign-out with a confirmation step.
  Future<void> _confirmSignOut() async {
    final p = widget.theme.palette;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        title: Text(
          'Sign out?',
          style: displayStyle(p, size: 17, weight: FontWeight.w600),
        ),
        content: Text(
          'You will need to sign in again to access your papers and saved items.',
          style: bodyStyle(p, size: 14, color: p.c.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: p.c.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE06B6B),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (ok == true) await widget.appState.logout();
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
    if (ok == true) unawaited(widget.appState.deletePaper(paper.id));
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
        // AppShell normally guards this route, but never render a dead
        // blank screen if the profile is reached while signed out.
        if (user == null) {
          return SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: _buildSignInPrompt(p),
              ),
            ),
          );
        }

        final isNarrow = MediaQuery.of(context).size.width < 700;
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
              // --------------------------------------- centered header
              _header(p, c, a, user, isNarrow),
              const SizedBox(height: 24),

              // --------------------------------------------- body
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _bioBlock(p, c, user),
                        _statsGrid(
                          p,
                          isNarrow,
                          myPapers.length,
                          formatCount(totalViews),
                          totalReactions,
                          '${(totalReadSeconds / 60).round()}m',
                        ),
                        const SizedBox(height: 28),
                        _tabsRow(p, c, a, tabs, isNarrow),
                        const SizedBox(height: 8),
                        if (!widget.appState.papersResolved)
                          // Papers are still loading from Firestore; don't
                          // flash "No papers yet" on the tab counts.
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: Center(
                                child: CircularProgressIndicator()),
                          )
                        else if (_tab == 0)
                          myPapers.isEmpty
                              ? _emptyTab(
                                  p,
                                  icon: '📄',
                                  title: 'No papers yet',
                                  sub:
                                      'Papers you publish will show up here.',
                                  actionLabel: 'Submit a paper',
                                  onAction: () => widget.appState
                                      .navigate(AppView.post),
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
                              ? _emptyTab(
                                  p,
                                  icon: '📖',
                                  title: 'No reading history',
                                  sub: 'Papers you open will appear here.',
                                )
                              : _historyList(p, c, historyPapers)
                        else
                          savedPapers.isEmpty
                              ? _emptyTab(
                                  p,
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

  /// Centered identity header: gradient banner with overlapping avatar,
  /// name, joined date, and the Edit Profile / Sign Out actions.
  Widget _header(
    AppPalette p,
    AppColors c,
    AccentPalette a,
    AppUser user,
    bool isNarrow,
  ) {
    const bannerH = 120.0;
    const overlap = 44.0;
    final avatarSize = isNarrow ? 88.0 : 96.0;
    return Column(
      children: [
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
                    p.accent.accent.withValues(
                        alpha: p.mode == AppMode.dark ? 0.35 : 0.18),
                    c.surface2,
                    c.bg,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                border: Border(bottom: BorderSide(color: c.border)),
              ),
            ),
            Positioned(
              top: bannerH - overlap,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: a.accent.withValues(alpha: 0.25),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: AvatarImage(
                    url: user.avatar,
                    size: avatarSize,
                    borderColor: a.accent,
                    borderWidth: 2.5,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: overlap + 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            user.username,
            style: displayStyle(p, size: 22, weight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Joined ${formatMonthYear(user.joinedAt)}',
          style: monoStyle(p, size: 11, color: c.muted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isNarrow ? 16 : 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Row(
                children: [
                  Expanded(
                    child: GoldButton(
                      palette: p,
                      label: 'Edit Profile',
                      minHeight: 44,
                      onPressed: () => _openEditDialog(user),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GhostButton(
                    palette: p,
                    label: 'Sign Out',
                    color: const Color(0xFFE06B6B),
                    minHeight: 44,
                    onPressed: _confirmSignOut,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Centered bio + website, rendered only when there is something to show.
  Widget _bioBlock(AppPalette p, AppColors c, AppUser user) {
    final hasBio = user.bio.isNotEmpty;
    final hasSite = user.website != null && user.website!.isNotEmpty;
    if (!hasBio && !hasSite) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          if (hasBio)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                user.bio,
                style: bodyStyle(p, size: 14, color: c.textSub, height: 1.6),
                textAlign: TextAlign.center,
              ),
            ),
          if (hasSite)
            InkWell(
              onTap: () => _openWebsite(user.website!),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  user.website!,
                  style: monoStyle(p, size: 11, color: p.info).copyWith(
                    decoration: TextDecoration.underline,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Opens the profile website in a browser; tolerates bare domains.
  Future<void> _openWebsite(String raw) async {
    var uri = Uri.tryParse(raw.trim());
    if (uri == null) return;
    if (uri.scheme.isEmpty) uri = Uri.tryParse('https://${raw.trim()}');
    if (uri == null) return;
    if (!await launchUrl(uri)) {
      widget.appState.showToast('Could not open website', '⚠️');
    }
  }

  /// Rendered when the profile route is reached while signed out (AppShell
  /// normally guards this, but a blank screen is never acceptable).
  Widget _buildSignInPrompt(AppPalette p) {
    final c = p.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 96, horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('👤', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 20),
          Text(
            'Your Scholar Profile',
            style: displayStyle(p, size: 26, weight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Sign in to see your papers, reading history, and saved items.',
            style: bodyStyle(p, size: 15, color: c.muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: GoldButton(
              palette: p,
              label: 'Sign In to Continue',
              onPressed: widget.onAuthPrompt,
              minHeight: 52,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- stats

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
      // Tiles must fit the icon tile + value + label with room to spare.
      childAspectRatio: 1.25,
      children: [
        _statCard(
          p,
          icon: '📄',
          value: '$papers',
          label: 'Papers',
          color: p.accent.accent,
        ),
        _statCard(
          p,
          icon: '👁',
          value: views,
          label: 'Total Views',
          color: const Color(0xFF7C6AF7),
        ),
        _statCard(
          p,
          icon: '🔥',
          value: '$reactions',
          label: 'Reactions Received',
          color: const Color(0xFFE06B6B),
        ),
        _statCard(
          p,
          icon: '⏱',
          value: readTime,
          label: 'Read Time',
          color: const Color(0xFF4ADE80),
        ),
      ],
    );
  }

  /// One stat card: tinted icon tile, colored value, uppercase label.
  Widget _statCard(
    AppPalette p, {
    required String icon,
    required String value,
    required String label,
    required Color color,
  }) {
    final c = p.c;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Text(icon, style: const TextStyle(fontSize: 17)),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: monoStyle(p, size: 9, color: c.muted, letterSpacing: 0.05),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- tabs

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

  /// Empty tab state: dashed circle icon, title, subtitle, optional action.
  Widget _emptyTab(
    AppPalette p, {
    required String icon,
    required String title,
    required String sub,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final c = p.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: CustomPaint(
              painter: _DashedCirclePainter(color: c.faint),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 28)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: displayStyle(p, size: 16, weight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            sub,
            style: bodyStyle(p, size: 13, color: c.muted),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            GoldButton(
              palette: p,
              label: actionLabel,
              minHeight: 44,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- lists

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

/// Dashed circle used by the profile empty states.
class _DashedCirclePainter extends CustomPainter {
  _DashedCirclePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final r = size.width / 2 - 2;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: r,
    );
    const dashPx = 6.0;
    const gapPx = 5.0;
    final circ = 2 * pi * r;
    var drawn = 0.0;
    while (drawn < circ) {
      final startAngle = (drawn / circ) * 2 * pi - pi / 2;
      final sweep = (dashPx / circ) * 2 * pi;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      drawn += dashPx + gapPx;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
