/// Admin console ported from `src/components/AdminPanel.tsx`.
///
/// Desktop-style moderation console: side rail (or a segmented control on
/// narrow screens), a dashboard with live platform stats + a moderation
/// queue, a filterable papers list, a user-management section, and a paper
/// detail dialog with approve / reject / revision / archive / delete actions.
///
/// Every number and action on this screen is backed by Firestore: stats are
/// derived from the live papers/users streams, and moderation writes go
/// through [AppState] which toasts on failure so a rejected write can never
/// look like a success.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/app_icons.dart';
import '../widgets/shared.dart';

const _statusOptions = <MapEntry<String, String>>[
  MapEntry('all', 'All statuses'),
  MapEntry('pending', 'Pending'),
  MapEntry('approved', 'Approved'),
  MapEntry('rejected', 'Rejected'),
  MapEntry('revision', 'Revision requested'),
  MapEntry('archived', 'Archived'),
];

const _monthNames = [
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
const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _shortDate(DateTime d) =>
    '${_monthNames[d.month - 1]} ${d.day}, ${d.year}';

String _todayLabel() {
  final now = DateTime.now();
  return '${_weekdayNames[now.weekday - 1]}, ${_monthNames[now.month - 1]} ${now.day}';
}

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.appState, required this.theme});

  final AppState appState;
  final ThemeProvider theme;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _section = 0; // 0 = dashboard, 1 = papers, 2 = users
  int _statsRange = 7; // days shown in the Library Statistics chart: 7, 30, 90
  final _searchController = TextEditingController();
  final _userSearchController = TextEditingController();
  String _search = '';
  String _userSearch = '';
  String _statusFilter = 'all';
  String _fieldFilter = 'all';
  String _yearFilter = 'all';

  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_onAppState);
  }

  @override
  void dispose() {
    widget.appState.removeListener(_onAppState);
    _searchController.dispose();
    _userSearchController.dispose();
    super.dispose();
  }

  void _onAppState() {
    if (mounted) setState(() {});
  }

  void _openPapers([String status = 'all']) {
    setState(() {
      _statusFilter = status;
      _section = 1;
    });
  }

  void _openUsers() => setState(() => _section = 2);

  /// Generic destructive-action confirmation. Returns true when the user
  /// confirms.
  Future<bool> _confirmAction({
    required String title,
    required String body,
    String confirmLabel = 'Delete',
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: widget.theme.palette.danger,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return ok == true;
  }

  // ------------------------------------------------------------ derived data

  List<Paper> get _allPapers => widget.appState.papers;

  List<AppUser> get _allUsers => widget.appState.users;

  int get _totalViews => _allPapers.fold<int>(0, (s, p) => s + p.views);

  List<Paper> get _pendingQueue {
    final list = _allPapers
        .where((p) => p.status == PaperStatus.pending)
        .toList();
    list.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return list;
  }

  List<String> get _fields =>
      _allPapers.map((p) => p.field).toSet().toList()..sort();

  List<String> get _years =>
      _allPapers.map((p) => p.year).toSet().toList()
        ..sort((a, b) => b.compareTo(a));

  List<Paper> get _recentlyUploaded {
    final list = List<Paper>.of(_allPapers)
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return list.take(5).toList();
  }

  /// Mirrors the React `filteredPapers` useMemo.
  List<Paper> get _filteredPapers {
    final query = _search.trim().toLowerCase();
    final list = _allPapers.where((p) {
      if (_statusFilter != 'all' && p.status.name != _statusFilter) {
        return false;
      }
      if (_fieldFilter != 'all' && p.field != _fieldFilter) return false;
      if (_yearFilter != 'all' && p.year != _yearFilter) return false;
      if (query.isNotEmpty) {
        return p.title.toLowerCase().contains(query) ||
            p.author.toLowerCase().contains(query) ||
            p.institution.toLowerCase().contains(query);
      }
      return true;
    }).toList()..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return list;
  }

  List<AppUser> get _filteredUsers {
    final query = _userSearch.trim().toLowerCase();
    if (query.isEmpty) return _allUsers;
    return _allUsers.where((u) {
      return u.username.toLowerCase().contains(query) ||
          u.email.toLowerCase().contains(query);
    }).toList();
  }

  int _papersBy(AppUser u) =>
      _allPapers.where((p) => p.authorId == u.id).length;

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final p = widget.theme.palette;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildRail(p),
              Expanded(child: _buildContent(p, wide)),
            ],
          );
        }
        return Column(
          children: [
            _buildSegmented(p),
            Expanded(child: _buildContent(p, wide)),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------------- side rail

  Widget _buildRail(AppPalette p) {
    final c = p.c;
    final userCount =
        widget.appState.usersResolved ? widget.appState.users.length : 0;
    return Container(
      width: 230,
      color: c.surface,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppLogo(palette: p),
          const SizedBox(height: 6),
          Text(
            'ADMIN CONSOLE',
            style: monoStyle(p, size: 9, letterSpacing: 0.14),
          ),
          const SizedBox(height: 28),
          Text('WORKSPACE', style: monoStyle(p, size: 9, letterSpacing: 0.14)),
          const SizedBox(height: 10),
          _railNav(
            p,
            icon: Icons.dashboard,
            label: 'Dashboard',
            active: _section == 0,
            onTap: () => setState(() => _section = 0),
          ),
          const SizedBox(height: 4),
          _railNav(
            p,
            icon: Icons.description,
            label: 'Papers & Theses',
            active: _section == 1,
            badge: widget.appState.pendingPapers.length,
            onTap: () => _openPapers(),
          ),
          const SizedBox(height: 4),
          _railNav(
            p,
            icon: Icons.people,
            label: 'Users',
            active: _section == 2,
            badge: userCount,
            onTap: _openUsers,
          ),
          const Spacer(),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [p.accent.accent, p.accent.accentDim],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  'AP',
                  style: TextStyle(
                    color: p.accent.accentFg,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin',
                      style: bodyStyle(p, size: 13, weight: FontWeight.w600),
                    ),
                    Text(
                      'Super administrator',
                      style: bodyStyle(p, size: 11, color: c.muted),
                    ),
                  ],
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _railNav(
    AppPalette p, {
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
    int? badge,
  }) {
    final a = p.accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active ? a.accent.withValues(alpha: 0.12) : null,
            borderRadius: BorderRadius.circular(8),
            border: active
                ? Border.all(color: a.accent.withValues(alpha: 0.35))
                : null,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: active ? a.accent : p.c.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: bodyStyle(
                    p,
                    size: 13,
                    weight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active ? a.accent : p.c.textSub,
                  ),
                ),
              ),
              if (badge != null && badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: a.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badge',
                    style: TextStyle(
                      color: a.accentFg,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------- segmented (narrow)

  Widget _buildSegmented(AppPalette p) {
    final c = p.c;
    Widget tab(IconData icon, String label, int index) {
      final active = _section == index;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _section = index),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? p.accent.accent.withValues(alpha: 0.15) : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: active ? p.accent.accent : c.muted),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: bodyStyle(
                    p,
                    size: 13,
                    weight: active ? FontWeight.w700 : FontWeight.w400,
                    color: active ? p.accent.accent : c.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          tab(Icons.dashboard, 'Dashboard', 0),
          tab(Icons.description, 'Papers', 1),
          tab(Icons.people, 'Users', 2),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- content

  /// Phone widths get tighter panel padding (16 instead of 24) so cards
  /// don't eat the screen; tablets and desktop keep the roomy 24.
  bool get _isPhone => MediaQuery.of(context).size.width < 700;

  Widget _buildContent(AppPalette p, bool wide) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(_isPhone ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopbar(p),
          const SizedBox(height: 24),
          if (_section == 0)
            _buildDashboard(p, wide)
          else if (_section == 1)
            _buildPapers(p, wide)
          else
            _buildUsers(p),
        ],
      ),
    );
  }

  Widget _buildTopbar(AppPalette p) {
    final c = p.c;
    final titles = ['Dashboard', 'Paper & Thesis Management', 'User Management'];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ADMIN CONSOLE',
                style: monoStyle(
                  p,
                  size: 10,
                  weight: FontWeight.w600,
                  letterSpacing: 0.14,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                titles[_section],
                style: displayStyle(p, size: 28, weight: FontWeight.w700),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today, size: 14, color: c.muted),
              const SizedBox(width: 6),
              Text(
                _todayLabel(),
                style: monoStyle(p, size: 11, color: c.textSub),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------- dashboard

  Widget _buildDashboard(AppPalette p, bool wide) {
    // Don't flash zero-counts while the first Firestore emission is pending.
    if (!widget.appState.papersResolved) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 64),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWelcome(p, wide),
        const SizedBox(height: 24),
        _buildStatsGrid(p, wide),
        const SizedBox(height: 24),
        _buildStatisticsPanel(p, wide),
        const SizedBox(height: 24),
        _buildDashboardPanels(p, wide),
      ],
    );
  }

  Widget _card(
    AppPalette p,
    Widget child, {
    double radius = 16,
    Color? color,
    Color? borderColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? p.c.surface,
        border: Border.all(color: borderColor ?? p.c.border),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }

  Widget _buildWelcome(AppPalette p, bool wide) {
    final pending = widget.appState.pendingPapers.length;
    final inner = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OVERVIEW',
          style: monoStyle(
            p,
            size: 10,
            weight: FontWeight.w600,
            letterSpacing: 0.14,
            color: p.accent.accent,
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: displayStyle(p, size: 24, weight: FontWeight.w700),
            children: [
              const TextSpan(text: 'Welcome back, '),
              TextSpan(
                text: 'Administrator!',
                style: TextStyle(color: p.accent.accent),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          pending > 0
              ? '$pending ${pending == 1 ? 'paper needs' : 'papers need'} your review right now.'
              : 'Everything is reviewed — here is the state of the research community.',
          style: bodyStyle(p, size: 14, color: p.c.muted),
        ),
      ],
    );
    final button = GoldButton(
      palette: p,
      label: 'Review pending papers →',
      minHeight: 44,
      onPressed: () => _openPapers('pending'),
    );
    return _card(
      p,
      Padding(
        padding: EdgeInsets.all(_isPhone ? 16 : 24),
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: inner),
                  const SizedBox(width: 24),
                  button,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [inner, const SizedBox(height: 18), button],
              ),
      ),
      // Hero layer: a gold-tinted panel so the welcome reads as the top
      // layer of the dashboard, above the flat stat and list cards.
      color: p.accent.accent.withValues(alpha: 0.07),
      borderColor: p.accent.accent.withValues(alpha: 0.25),
    );
  }

  Widget _buildStatsGrid(AppPalette p, bool wide) {
    final pending = widget.appState.pendingPapers.length;
    final approved = _allPapers
        .where((x) => x.status == PaperStatus.approved)
        .length;
    final rejected = _allPapers
        .where((x) => x.status == PaperStatus.rejected)
        .length;
    final usersLabel = widget.appState.usersResolved
        ? formatCount(widget.appState.users.length)
        : '…';
    final cards = [
      _statCard(
        p,
        icon: AppIcon.papers,
        chipColor: const Color(0xFF9AA4B2),
        label: 'Total Papers',
        value: formatCount(_allPapers.length),
        trend: _papersThisWeek((_) => true),
        onTap: () => _openPapers(),
      ),
      _statCard(
        p,
        icon: AppIcon.pending,
        chipColor: const Color(0xFFE8913A),
        label: 'Pending Review',
        value: formatCount(pending),
        trend: _papersThisWeek((x) => x.status == PaperStatus.pending),
        onTap: () => _openPapers('pending'),
      ),
      _statCard(
        p,
        icon: AppIcon.published,
        chipColor: p.accent.accent,
        label: 'Published Papers',
        value: formatCount(approved),
        trend: _papersThisWeek((x) => x.status == PaperStatus.approved),
        onTap: () => _openPapers('approved'),
      ),
      _statCard(
        p,
        icon: AppIcon.users,
        chipColor: const Color(0xFF4A90E2),
        label: 'Registered Users',
        value: usersLabel,
        trend: _newUsersThisWeek(),
        onTap: _openUsers,
      ),
      _statCard(
        p,
        icon: AppIcon.views,
        chipColor: p.info,
        label: 'Total Views',
        value: formatCount(_totalViews),
      ),
      _statCard(
        p,
        icon: AppIcon.rejected,
        chipColor: p.danger,
        label: 'Rejected Papers',
        value: formatCount(rejected),
        trend: _papersThisWeek((x) => x.status == PaperStatus.rejected),
        onTap: () => _openPapers('rejected'),
      ),
    ];
    return GridView.count(
      crossAxisCount: wide ? 3 : 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      // Compact reference-style cells: chip row (28) + gap (8) + label
      // (~16) + padding (24) ≈ 76, so 84 leaves headroom. The number
      // FittedBox and the single-line ellipsized label mean the fixed
      // height can never clip, at any phone width.
      mainAxisExtent: 84,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cards,
    );
  }

  Widget _statCard(
    AppPalette p, {
    AppIcon? icon,
    Color? chipColor,
    required String label,
    required String value,
    int? trend,
    VoidCallback? onTap,
  }) {
    // Compact reference-style card: a tinted icon chip + big number on one
    // row, trend badge top-right, label beneath. Deliberately no sparkline
    // and no chevron (the reference has neither). The number FittedBox and
    // the single-line ellipsized label mean the fixed 84px cell can never
    // clip, at any phone width.
    final chip = chipColor ?? p.accent.accent;
    final body = Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: chip.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: icon == null
                    ? null
                    : Center(
                        child: AppIconImage(icon, size: 16, color: chip),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: displayStyle(p, size: 22, weight: FontWeight.w700),
                  ),
                ),
              ),
              if (trend != null) ...[
                const SizedBox(width: 8),
                _trendBadge(p, trend),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: bodyStyle(p, size: 12, color: p.c.muted),
          ),
        ],
      ),
    );
    final card = _card(p, body);
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: card,
      ),
    );
  }

  /// Weekly trend badge, restyled to the compact reference design: a flat
  /// colored arrow + count, no pill background. Counts are "this week"
  /// submissions/joins, so they never go negative — zero shows as ↑ +0.
  /// Total views has no badge (views carry no timestamps).
  Widget _trendBadge(AppPalette p, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.arrow_upward, size: 12, color: p.success),
        const SizedBox(width: 2),
        Text(
          '+$count',
          style: monoStyle(
            p,
            size: 11,
            color: p.success,
            weight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Papers matching [test] submitted in the last 7 days — the "+N" on the
  /// stat cards. Uses submittedAt (the only date papers carry); a paper
  /// approved this week but submitted earlier does not count.
  int _papersThisWeek(bool Function(Paper) test) {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return _allPapers
        .where((paper) => test(paper) && paper.submittedAt.isAfter(cutoff))
        .length;
  }

  /// Users whose joinedAt (stored as "YYYY-MM-DD") falls in the last 7 days.
  int _newUsersThisWeek() {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return widget.appState.users.where((user) {
      final joined = DateTime.tryParse(user.joinedAt);
      return joined != null && joined.isAfter(cutoff);
    }).length;
  }

  /// Daily buckets for the Library Statistics chart: papers submitted and
  /// users joined on each of the last [range] days, oldest first.
  ({List<int> papers, List<int> users, List<DateTime> days}) _statsSeries(
    int range,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days =
        List<DateTime>.generate(range, (i) => today.subtract(Duration(days: range - 1 - i)));
    final paperCounts = List<int>.filled(range, 0);
    final userCounts = List<int>.filled(range, 0);
    for (final paper in _allPapers) {
      final d = DateTime(
        paper.submittedAt.year,
        paper.submittedAt.month,
        paper.submittedAt.day,
      );
      final idx = d.difference(days.first).inDays;
      if (idx >= 0 && idx < range) paperCounts[idx]++;
    }
    for (final user in widget.appState.users) {
      final parsed = DateTime.tryParse(user.joinedAt);
      if (parsed == null) continue;
      final d = DateTime(parsed.year, parsed.month, parsed.day);
      final idx = d.difference(days.first).inDays;
      if (idx >= 0 && idx < range) userCounts[idx]++;
    }
    return (papers: paperCounts, users: userCounts, days: days);
  }

  Widget _rangeChip(AppPalette p, String label, int days) {
    final selected = _statsRange == days;
    return GestureDetector(
      onTap: () => setState(() => _statsRange = days),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? p.accent.accent : Colors.transparent,
          border: Border.all(
            color: selected ? p.accent.accent : p.c.border,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: monoStyle(
            p,
            size: 11,
            color: selected ? p.accent.accentFg : p.c.muted,
          ),
        ),
      ),
    );
  }

  Widget _legendDot(AppPalette p, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(label, style: bodyStyle(p, size: 12, color: p.c.muted)),
      ],
    );
  }

  Widget _buildStatisticsPanel(AppPalette p, bool wide) {
    final series = _statsSeries(_statsRange);
    final totalPapers = series.papers.fold<int>(0, (a, b) => a + b);
    final totalUsers = series.users.fold<int>(0, (a, b) => a + b);
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Library Statistics',
          style: displayStyle(p, size: 17, weight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Papers and users over time',
          style: bodyStyle(p, size: 12, color: p.c.muted),
        ),
      ],
    );
    final chips = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _rangeChip(p, '7D', 7),
        const SizedBox(width: 8),
        _rangeChip(p, '30D', 30),
        const SizedBox(width: 8),
        _rangeChip(p, '90D', 90),
      ],
    );
    return _card(
      p,
      Padding(
        padding: EdgeInsets.all(_isPhone ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            wide
                ? Row(
                    children: [Expanded(child: header), chips],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [header, const SizedBox(height: 12), chips],
                  ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              width: double.infinity,
              child: CustomPaint(
                painter: _StatsChartPainter(
                  paperCounts: series.papers,
                  userCounts: series.users,
                  days: series.days,
                  paperColor: p.accent.accent,
                  // Warm orange for the Users line, matching the reference
                  // design (no palette color is orange).
                  userColor: const Color(0xFFE8913A),
                  gridColor: p.c.border,
                  labelColor: p.c.muted,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _legendDot(p, p.accent.accent, 'Papers'),
                const SizedBox(width: 16),
                _legendDot(p, const Color(0xFFE8913A), 'Users'),
              ],
            ),
            if (totalPapers == 0 && totalUsers == 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'No submissions in this range yet.',
                  style: bodyStyle(p, size: 12, color: p.c.muted),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardPanels(AppPalette p, bool wide) {
    final queue = _card(p, _buildReviewQueue(p));
    final activity = _card(p, _buildActivity(p));
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 2, child: queue),
          const SizedBox(width: 24),
          Expanded(child: activity),
        ],
      );
    }
    return Column(children: [queue, const SizedBox(height: 24), activity]);
  }

  /// The moderator's work queue: pending papers with one-tap approve.
  /// Rejections need a reason, so they open the full review dialog.
  Widget _buildReviewQueue(AppPalette p) {
    final queue = _pendingQueue.take(4).toList();
    return Padding(
      padding: EdgeInsets.all(_isPhone ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Needs review',
                      style: displayStyle(p, size: 17, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Submissions waiting for moderation',
                      style: bodyStyle(p, size: 12, color: p.c.muted),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _openPapers('pending'),
                child: const Text('View all →'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (queue.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 20,
                    color: p.success,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All caught up — nothing waiting for review.',
                      style: bodyStyle(p, size: 13, color: p.c.muted),
                    ),
                  ),
                ],
              ),
            )
          else
            ...queue.map(
              (paper) => Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: p.c.border)),
                ),
                child: Row(
                  children: [
                    NetImage(
                      url: paper.coverImage,
                      width: 36,
                      height: 48,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            paper.title,
                            style: displayStyle(
                              p,
                              size: 13,
                              weight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${paper.author} · ${timeAgo(paper.submittedAt)}',
                            style: monoStyle(p, size: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GhostButton(
                      palette: p,
                      label: 'Review',
                      onPressed: () => _openDetail(paper),
                    ),
                    const SizedBox(width: 8),
                    GoldButton(
                      palette: p,
                      label: 'Approve',
                      minHeight: 36,
                      onPressed: () =>
                          widget.appState.approvePaper(paper.id),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActivity(AppPalette p) {
    final rows = _recentlyUploaded.take(4).toList();
    return Padding(
      padding: EdgeInsets.all(_isPhone ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent submissions',
                      style: displayStyle(p, size: 17, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Latest papers uploaded to the archive',
                      style: bodyStyle(p, size: 12, color: p.c.muted),
                    ),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: p.accent.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.show_chart, size: 17, color: p.accent.accent),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (rows.isEmpty)
            Text(
              'No submissions yet.',
              style: bodyStyle(p, size: 13, color: p.c.muted),
            )
          else
            ...rows.map((paper) {
              final color = p.statusColor(paper.status);
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: p.c.border)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.12),
                        border: Border.all(color: color.withValues(alpha: 0.4)),
                      ),
                      child: Icon(Icons.description, size: 13, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: bodyStyle(p, size: 13),
                              children: [
                                TextSpan(
                                  text: paper.author,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const TextSpan(text: ' submitted '),
                                TextSpan(
                                  text: '“${paper.title}”',
                                  style: TextStyle(color: p.c.muted),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            timeAgo(paper.submittedAt),
                            style: monoStyle(p, size: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- papers list

  Widget _buildPapers(AppPalette p, bool wide) {
    final filtered = _filteredPapers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Research repository',
                    style: displayStyle(p, size: 22, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Review, organize, and manage all student submissions.',
                    style: bodyStyle(p, size: 13, color: p.c.muted),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatCount(filtered.length),
                  style: displayStyle(p, size: 18, weight: FontWeight.w700),
                ),
                const SizedBox(width: 6),
                Text('papers found', style: monoStyle(p, size: 11)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildFilters(p, wide),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          _card(
            p,
            EmptyState(
              palette: p,
              icon: '🔍',
              title: 'No papers found',
              sub: 'Try changing your search or filters.',
            ),
          )
        else
          ...filtered.map((paper) => _buildPaperRow(p, paper)),
      ],
    );
  }

  Widget _buildFilters(AppPalette p, bool wide) {
    final search = TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _search = v),
      decoration: const InputDecoration(
        hintText: 'Search title, author, or institution...',
        prefixIcon: Icon(Icons.search, size: 17),
      ),
    );
    final status = DropdownButtonFormField<String>(
      initialValue: _statusFilter,
      isExpanded: true,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.filter_list, size: 16),
      ),
      items: _statusOptions
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
    );
    final field = DropdownButtonFormField<String>(
      initialValue: _fieldFilter,
      isExpanded: true,
      decoration: const InputDecoration(),
      items: [
        const DropdownMenuItem(value: 'all', child: Text('All subjects')),
        ..._fields.map((f) => DropdownMenuItem(value: f, child: Text(f))),
      ],
      onChanged: (v) => setState(() => _fieldFilter = v ?? 'all'),
    );
    final year = DropdownButtonFormField<String>(
      initialValue: _yearFilter,
      isExpanded: true,
      decoration: const InputDecoration(),
      items: [
        const DropdownMenuItem(value: 'all', child: Text('All years')),
        ..._years.map((y) => DropdownMenuItem(value: y, child: Text(y))),
      ],
      onChanged: (v) => setState(() => _yearFilter = v ?? 'all'),
    );
    if (wide) {
      return Row(
        children: [
          Expanded(flex: 2, child: search),
          const SizedBox(width: 12),
          Expanded(child: status),
          const SizedBox(width: 12),
          Expanded(child: field),
          const SizedBox(width: 12),
          Expanded(child: year),
        ],
      );
    }
    return Column(
      children: [
        search,
        const SizedBox(height: 12),
        status,
        const SizedBox(height: 12),
        field,
        const SizedBox(height: 12),
        year,
      ],
    );
  }

  Widget _buildPaperRow(AppPalette p, Paper paper) {
    final cover = NetImage(
      url: paper.coverImage,
      width: 48,
      height: 64,
      borderRadius: BorderRadius.circular(6),
    );
    final titleCol = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            paper.title,
            style: displayStyle(p, size: 14, weight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${paper.author} · ${paper.institution}',
            style: monoStyle(p, size: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${paper.field} · Class of ${paper.year}',
            style: monoStyle(p, size: 10, color: p.c.faint),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
    final viewButton = IconButton(
      tooltip: 'View ${paper.title}',
      icon: Icon(Icons.visibility_outlined, size: 18, color: p.c.muted),
      onPressed: () => _openDetail(paper),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.c.surface,
        border: Border.all(color: p.c.border),
        borderRadius: BorderRadius.circular(10),
      ),
      // On narrow screens the date column + status badge + view button
      // don't fit beside the title — stack the meta row below instead.
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          if (constraints.maxWidth < 420) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    cover,
                    const SizedBox(width: 12),
                    titleCol,
                    viewButton,
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      _shortDate(paper.submittedAt),
                      style: monoStyle(p, size: 11, color: p.c.textSub),
                    ),
                    Text(
                      ' · ${paper.pages} pages',
                      style: monoStyle(p, size: 10),
                    ),
                    const Spacer(),
                    StatusBadge(palette: p, status: paper.status),
                  ],
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              cover,
              const SizedBox(width: 12),
              titleCol,
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _shortDate(paper.submittedAt),
                    style: monoStyle(p, size: 11, color: p.c.textSub),
                  ),
                  const SizedBox(height: 2),
                  Text('${paper.pages} pages',
                      style: monoStyle(p, size: 10)),
                ],
              ),
              const SizedBox(width: 12),
              StatusBadge(palette: p, status: paper.status),
              viewButton,
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------- users list

  /// User management, backed by the live `users` collection stream.
  /// Profiles are publicly readable per firestore.rules; deletion is
  /// admin-only. Admin grants happen in the Firebase console (the rules
  /// don't allow client-side isAdmin changes), hence the hint below.
  Widget _buildUsers(AppPalette p) {
    final users = _filteredUsers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Registered users',
                    style: displayStyle(p, size: 22, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Everyone with an account in the database.',
                    style: bodyStyle(p, size: 13, color: p.c.muted),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.appState.usersResolved
                      ? formatCount(widget.appState.users.length)
                      : '…',
                  style: displayStyle(p, size: 18, weight: FontWeight.w700),
                ),
                const SizedBox(width: 6),
                Text('users', style: monoStyle(p, size: 11)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _userSearchController,
          onChanged: (v) => setState(() => _userSearch = v),
          decoration: const InputDecoration(
            hintText: 'Search username or email...',
            prefixIcon: Icon(Icons.search, size: 17),
          ),
        ),
        const SizedBox(height: 16),
        if (!widget.appState.usersResolved)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (users.isEmpty)
          _card(
            p,
            EmptyState(
              palette: p,
              icon: '👥',
              title: _userSearch.trim().isEmpty
                  ? 'No users yet'
                  : 'No users found',
              sub: _userSearch.trim().isEmpty
                  ? 'Accounts appear here once people sign up.'
                  : 'Try a different search.',
            ),
          )
        else
          ...users.map((u) => _buildUserRow(p, u)),
        const SizedBox(height: 16),
        Text(
          'Admin access is granted in the Firebase console (admins collection) — '
          'it cannot be changed from inside the app.',
          style: monoStyle(p, size: 10, color: p.c.faint),
        ),
      ],
    );
  }

  Widget _buildUserRow(AppPalette p, AppUser u) {
    final c = p.c;
    final isSelf = widget.appState.user?.id == u.id;
    final papers = _papersBy(u);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AvatarImage(url: u.avatar, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        u.username,
                        style:
                            bodyStyle(p, size: 14, weight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (u.isAdmin) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: p.accent.accent.withValues(alpha: 0.15),
                          border: Border.all(
                            color: p.accent.accent.withValues(alpha: 0.4),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'ADMIN',
                          style: monoStyle(
                            p,
                            size: 9,
                            weight: FontWeight.w700,
                            color: p.accent.accent,
                          ),
                        ),
                      ),
                    ],
                    if (isSelf) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: c.surface2,
                          border: Border.all(color: c.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'YOU',
                          style: monoStyle(p, size: 9, color: c.muted),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  u.email,
                  style: monoStyle(p, size: 11, color: c.textSub),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if ((u.institution ?? '').isNotEmpty) u.institution!,
                    '$papers ${papers == 1 ? 'paper' : 'papers'}',
                    'joined ${u.joinedAt}',
                  ].join(' · '),
                  style: monoStyle(p, size: 10, color: c.faint),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isSelf)
            Tooltip(
              message: 'You cannot delete your own account here',
              child: Icon(Icons.lock_outline, size: 18, color: c.faint),
            )
          else
            IconButton(
              tooltip: 'Delete ${u.username}',
              icon: Icon(
                Icons.delete_outline,
                size: 18,
                color: p.danger,
              ),
              onPressed: () async {
                final ok = await _confirmAction(
                  title: 'Delete user?',
                  body:
                      '“${u.username}” will lose access immediately. Their papers stay in the archive.',
                );
                if (ok) await widget.appState.deleteUser(u.id);
              },
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ detail dialog

  void _openDetail(Paper paper) {
    showDialog(
      context: context,
      builder: (_) {
        String? reviewAction; // 'reject' | 'revision'
        var reason = '';
        String? formError;
        return StatefulBuilder(
          builder: (ctx, setD) {
            final p = widget.theme.palette;
            final c = p.c;
            final cur = widget.appState.paperById(paper.id) ?? paper;

            Future<void> submitReview() async {
              if (reviewAction == null) return;
              if (reason.trim().isEmpty) {
                setD(() {
                  formError = reviewAction == 'reject'
                      ? 'A rejection reason is required.'
                      : 'Please describe the requested revisions.';
                });
                return;
              }
              final ok = reviewAction == 'reject'
                  ? await widget.appState.rejectPaper(cur.id, reason.trim())
                  : await widget.appState.requestRevision(cur.id, reason.trim());
              // The write may fail (e.g. unpublished rules) — AppState already
              // toasted the error, so keep the dialog open for a retry.
              if (ok && ctx.mounted) Navigator.of(ctx).pop();
            }

            Future<void> deleteCurrent() async {
              final ok = await _confirmAction(
                title: 'Delete paper?',
                body:
                    '“${cur.title}” and all its comments and reactions will be permanently removed.',
              );
              if (!ok) return;
              final deleted = await widget.appState.deletePaper(cur.id);
              if (deleted && ctx.mounted) Navigator.of(ctx).pop();
            }

            /// Label/value row for the details card.
            Widget detailRow(String label, String value) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 108,
                      child: Text(
                        label.toUpperCase(),
                        style: monoStyle(
                          p,
                          size: 10,
                          color: c.faint,
                        ).copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.08,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        value,
                        style: bodyStyle(
                          p,
                          size: 13,
                          weight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.right,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }

            Widget detailDivider() =>
                Divider(height: 1, thickness: 1, color: c.border);

            return Dialog(
              insetPadding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                            child: cur.coverImage.isEmpty
                                ? Container(
                                    width: double.infinity,
                                    height: 120,
                                    color: c.surface2,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons
                                              .picture_as_pdf_outlined,
                                          size: 32,
                                          color: c.faint,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'No cover attached',
                                          style: monoStyle(
                                            p,
                                            size: 10,
                                            color: c.faint,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : NetImage(
                                    url: cur.coverImage,
                                    width: double.infinity,
                                    height: 160,
                                  ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              decoration: BoxDecoration(
                                color: c.overlay.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                tooltip: 'Close',
                                icon: const Icon(
                                  Icons.close,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                onPressed: () => Navigator.of(ctx).pop(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            StatusBadge(palette: p, status: cur.status),
                            const SizedBox(height: 12),
                            Text(
                              cur.title,
                              style: displayStyle(
                                p,
                                size: 22,
                                weight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            RichText(
                              text: TextSpan(
                                style: bodyStyle(p, size: 13, color: c.textSub),
                                children: [
                                  const TextSpan(text: 'Submitted by '),
                                  TextSpan(
                                    text: cur.author,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  TextSpan(text: ' from ${cur.institution}'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              decoration: BoxDecoration(
                                color: c.surface,
                                border: Border.all(color: c.border),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  detailRow('Subject', cur.field),
                                  detailDivider(),
                                  detailRow('Academic year', cur.year),
                                  detailDivider(),
                                  detailRow(
                                      'Length', '${cur.pages} pages'),
                                  detailDivider(),
                                  detailRow('Submitted',
                                      timeAgo(cur.submittedAt)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            SectionLabel(palette: p, text: 'Abstract'),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: c.surface,
                                border: Border.all(color: c.border),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                cur.abstract,
                                style: bodyStyle(p, size: 14, height: 1.6),
                              ),
                            ),
                            if (cur.tags.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: cur.tags
                                    .map((t) => TagChip(palette: p, tag: t))
                                    .toList(),
                              ),
                            ],
                            if ((cur.status == PaperStatus.rejected ||
                                    cur.status == PaperStatus.revision) &&
                                cur.rejectionReason != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: c.surface2,
                                  border: Border.all(color: c.border),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cur.status == PaperStatus.rejected
                                          ? 'Rejection reason'
                                          : 'Requested revisions',
                                      style: bodyStyle(
                                        p,
                                        size: 13,
                                        weight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      cur.rejectionReason!,
                                      style: bodyStyle(
                                        p,
                                        size: 13,
                                        color: c.textSub,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            if (reviewAction != null) ...[
                              SectionLabel(
                                palette: p,
                                text: reviewAction == 'reject'
                                    ? 'Reason for rejection'
                                    : 'Revision notes',
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                maxLines: 4,
                                onChanged: (v) => setD(() {
                                  reason = v;
                                  formError = null;
                                }),
                                decoration: InputDecoration(
                                  hintText: reviewAction == 'reject'
                                      ? 'Explain why this submission cannot be approved...'
                                      : 'Explain the changes the student needs to make...',
                                ),
                              ),
                              if (formError != null) ...[
                                const SizedBox(height: 8),
                                ErrorBanner(message: formError!),
                              ],
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: GhostButton(
                                      palette: p,
                                      label: 'Cancel',
                                      minHeight: 44,
                                      onPressed: () =>
                                          setD(() => reviewAction = null),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: reviewAction == 'reject'
                                        ? GhostButton(
                                            palette: p,
                                            label: 'Confirm rejection',
                                            color: p.danger,
                                            minHeight: 44,
                                            onPressed: submitReview,
                                          )
                                        : GoldButton(
                                            palette: p,
                                            label: 'Send revision request',
                                            minHeight: 44,
                                            onPressed: submitReview,
                                          ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              // Primary action: full-width approve.
                              if (cur.status == PaperStatus.pending) ...[
                                SizedBox(
                                  width: double.infinity,
                                  child: GoldButton(
                                    palette: p,
                                    label: 'Approve',
                                    minHeight: 48,
                                    onPressed: () async {
                                      final ok = await widget.appState
                                          .approvePaper(cur.id);
                                      if (ok && ctx.mounted) {
                                        Navigator.of(ctx).pop();
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: GhostButton(
                                        palette: p,
                                        label: 'Request revisions',
                                        minHeight: 44,
                                        onPressed: () => setD(() {
                                          reviewAction = 'revision';
                                          reason = '';
                                          formError = null;
                                        }),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: GhostButton(
                                        palette: p,
                                        label: 'Reject',
                                        color: p.danger,
                                        minHeight: 44,
                                        onPressed: () => setD(() {
                                          reviewAction = 'reject';
                                          reason = '';
                                          formError = null;
                                        }),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              // Tertiary actions row
                              const SizedBox(height: 16),
                              Divider(height: 1, thickness: 1, color: c.border),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  if (cur.pdfUrl != null) ...[
                                    Expanded(
                                      child: _tertiaryAction(
                                        p,
                                        icon: Icons.open_in_new_rounded,
                                        label: 'Read PDF',
                                        color: c.textSub,
                                        onPressed: () async {
                                          final url = Uri.parse(cur.pdfUrl!);
                                          if (!await launchUrl(url)) {
                                            widget.appState.showToast(
                                              'Could not open the PDF link',
                                              '⚠️',
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                  if (cur.status != PaperStatus.archived &&
                                      cur.status != PaperStatus.pending) ...[
                                    Expanded(
                                      child: _tertiaryAction(
                                        p,
                                        icon: Icons.archive_outlined,
                                        label: 'Archive',
                                        color: c.muted,
                                        onPressed: () async {
                                          final ok = await widget.appState
                                              .archivePaper(cur.id);
                                          if (ok && ctx.mounted) {
                                            Navigator.of(ctx).pop();
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                  Expanded(
                                    child: _tertiaryAction(
                                      p,
                                      icon: Icons.delete_outline_rounded,
                                      label: 'Delete',
                                      color: p.danger,
                                      onPressed: deleteCurrent,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Compact icon + label button for tertiary actions (Read PDF, Archive, Delete).
  Widget _tertiaryAction(
    AppPalette p, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: bodyStyle(p, size: 13, weight: FontWeight.w500, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Line chart for the Library Statistics panel: papers vs users per day.
/// No chart package is used on purpose — a new pub dependency would need a
/// network fetch on virgil's flaky connection, so this is plain CustomPaint.
class _StatsChartPainter extends CustomPainter {
  _StatsChartPainter({
    required this.paperCounts,
    required this.userCounts,
    required this.days,
    required this.paperColor,
    required this.userColor,
    required this.gridColor,
    required this.labelColor,
  });

  final List<int> paperCounts;
  final List<int> userCounts;
  final List<DateTime> days;
  final Color paperColor;
  final Color userColor;
  final Color gridColor;
  final Color labelColor;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void paint(Canvas canvas, Size size) {
    const left = 30.0;
    const bottom = 24.0;
    const top = 8.0;
    const right = 8.0;
    final plotW = size.width - left - right;
    final plotH = size.height - top - bottom;
    if (plotW <= 0 || plotH <= 0 || days.isEmpty) return;

    var maxV = 0;
    for (final v in paperCounts) {
      if (v > maxV) maxV = v;
    }
    for (final v in userCounts) {
      if (v > maxV) maxV = v;
    }
    // Headroom above the highest point, and always an even ceiling so the
    // mid gridline label stays a whole number.
    var yMax = maxV + 2;
    if (yMax.isOdd) yMax++;
    if (yMax < 4) yMax = 4;

    double x(int i) {
      if (days.length == 1) return left + plotW / 2;
      return left + plotW * i / (days.length - 1);
    }

    double y(int v) => top + plotH * (1 - v / yMax);

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final labelStyle = TextStyle(color: labelColor, fontSize: 10);
    void drawLabel(String text, double dx, double dy) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(dx, dy));
    }

    // Horizontal gridlines + y labels at 0, half, max.
    for (final f in [0.0, 0.5, 1.0]) {
      final gy = top + plotH * (1 - f);
      canvas.drawLine(Offset(left, gy), Offset(left + plotW, gy), gridPaint);
      drawLabel('${(yMax * f).round()}', 0, gy - 6);
    }

    void drawSeries(List<int> values, Color color) {
      if (values.isEmpty) return;
      final path = Path();
      for (var i = 0; i < values.length; i++) {
        final px = x(i);
        final py = y(values[i]);
        if (i == 0) {
          path.moveTo(px, py);
        } else {
          path.lineTo(px, py);
        }
      }
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, linePaint);
      // Dots on each point, only when sparse enough to read.
      if (values.length <= 31) {
        final dotPaint = Paint()..color = color;
        for (var i = 0; i < values.length; i++) {
          canvas.drawCircle(Offset(x(i), y(values[i])), 3, dotPaint);
        }
      }
    }

    drawSeries(paperCounts, paperColor);
    drawSeries(userCounts, userColor);

    // X labels: every day for a week, weekly ticks for longer ranges.
    final step = days.length <= 7 ? 1 : 7;
    for (var i = 0; i < days.length; i++) {
      if (i % step != 0 && i != days.length - 1) continue;
      final d = days[i];
      final text =
          days.length <= 7 ? _weekdays[d.weekday - 1] : '${d.month}/${d.day}';
      final tp = TextPainter(
        text: TextSpan(text: text, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x(i) - tp.width / 2, top + plotH + 8));
    }
  }

  @override
  bool shouldRepaint(covariant _StatsChartPainter old) {
    // New lists are built on every panel build, so identity comparison
    // already repaints exactly when the data or range changes.
    return old.paperCounts != paperCounts ||
        old.userCounts != userCounts ||
        old.days != days ||
        old.paperColor != paperColor ||
        old.userColor != userColor;
  }
}
