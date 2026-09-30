/// Admin console ported from `src/components/AdminPanel.tsx`.
///
/// Desktop-style moderation console: side rail (or a segmented control on
/// narrow screens), a dashboard with platform stats + recent activity, a
/// filterable papers list, and a paper detail dialog with approve / reject /
/// revision / archive actions.
library;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
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

Color _statusColor(PaperStatus status) {
  switch (status) {
    case PaperStatus.approved:
      return const Color(0xFF4ADE80);
    case PaperStatus.rejected:
      return const Color(0xFFE06B6B);
    case PaperStatus.revision:
      return const Color(0xFFE8B04B);
    case PaperStatus.pending:
      return const Color(0xFF7C6AF7);
    case PaperStatus.archived:
      return const Color(0xFF7A7690);
  }
}

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.appState, required this.theme});

  final AppState appState;
  final ThemeProvider theme;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _section = 0; // 0 = dashboard, 1 = papers
  final _searchController = TextEditingController();
  String _search = '';
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

  // ------------------------------------------------------------ derived data

  List<Paper> get _allPapers => widget.appState.papers;

  int get _uniqueStudents => _allPapers.map((p) => p.authorId).toSet().length;

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
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF4ADE80),
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
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- content

  Widget _buildContent(AppPalette p, bool wide) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopbar(p),
          const SizedBox(height: 24),
          if (_section == 0)
            _buildDashboard(p, wide)
          else
            _buildPapers(p, wide),
        ],
      ),
    );
  }

  Widget _buildTopbar(AppPalette p) {
    final c = p.c;
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
                _section == 0 ? 'Dashboard' : 'Paper & Thesis Management',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWelcome(p, wide),
        const SizedBox(height: 20),
        _buildStatsGrid(p, wide),
        const SizedBox(height: 20),
        _buildDashboardPanels(p, wide),
      ],
    );
  }

  Widget _card(AppPalette p, Widget child, {double radius = 14}) {
    return Container(
      decoration: BoxDecoration(
        color: p.c.surface,
        border: Border.all(color: p.c.border),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }

  Widget _buildWelcome(AppPalette p, bool wide) {
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
        Text(
          'Welcome back, Administrator.',
          style: displayStyle(p, size: 24, weight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Here is what is happening with the research community today.',
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
        padding: const EdgeInsets.all(24),
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
    final cards = [
      _statCard(
        p,
        icon: Icons.people,
        iconColor: const Color(0xFF7C6AF7),
        label: 'Registered users',
        value: _uniqueStudents + 1,
        detail: 'Including 1 administrator',
      ),
      _statCard(
        p,
        icon: Icons.school,
        iconColor: const Color(0xFF60A5FA),
        label: 'Total students',
        value: _uniqueStudents,
        detail: '$_uniqueStudents active contributors',
      ),
      _statCard(
        p,
        icon: Icons.description,
        iconColor: p.c.muted,
        label: 'Uploaded papers',
        value: _allPapers.length,
        detail: 'Across all categories',
      ),
      _statCard(
        p,
        icon: Icons.schedule,
        iconColor: p.accent.accent,
        label: 'Pending validation',
        value: pending,
        detail: 'Requires your attention',
        onTap: () => _openPapers('pending'),
      ),
      _statCard(
        p,
        icon: Icons.check,
        iconColor: p.success,
        label: 'Approved papers',
        value: approved,
        detail: 'Published in the library',
        onTap: () => _openPapers('approved'),
      ),
      _statCard(
        p,
        icon: Icons.close,
        iconColor: p.danger,
        label: 'Rejected papers',
        value: rejected,
        detail: 'Did not meet guidelines',
        onTap: () => _openPapers('rejected'),
      ),
    ];
    return GridView.count(
      crossAxisCount: wide ? 3 : 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.55,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cards,
    );
  }

  Widget _statCard(
    AppPalette p, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required int value,
    required String detail,
    VoidCallback? onTap,
  }) {
    final body = Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: monoStyle(p, size: 9, letterSpacing: 0.1),
                ),
                const SizedBox(height: 4),
                Text(
                  formatCount(value),
                  style: displayStyle(p, size: 24, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(detail, style: bodyStyle(p, size: 11, color: p.c.muted)),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right, size: 16, color: p.c.muted),
        ],
      ),
    );
    final card = _card(p, body, radius: 12);
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: card,
      ),
    );
  }

  Widget _buildDashboardPanels(AppPalette p, bool wide) {
    final recent = _card(p, _buildRecentPapers(p));
    final activity = _card(p, _buildActivity(p));
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: recent),
          const SizedBox(width: 20),
          Expanded(child: activity),
        ],
      );
    }
    return Column(children: [recent, const SizedBox(height: 20), activity]);
  }

  Widget _buildRecentPapers(AppPalette p) {
    return Padding(
      padding: const EdgeInsets.all(20),
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
                      'Recently uploaded papers',
                      style: displayStyle(p, size: 17, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Latest submissions from students',
                      style: bodyStyle(p, size: 12, color: p.c.muted),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _openPapers(),
                child: const Text('View all →'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._recentlyUploaded.map((paper) {
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _openDetail(paper),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      NetImage(
                        url: paper.coverImage,
                        width: 44,
                        height: 60,
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
                                size: 14,
                                weight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${paper.author} · ${paper.field}',
                              style: monoStyle(p, size: 11),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      StatusBadge(palette: p, status: paper.status),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 88,
                        child: Text(
                          timeAgo(paper.submittedAt),
                          style: monoStyle(p, size: 11),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 16, color: p.c.muted),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActivity(AppPalette p) {
    final rows = _recentlyUploaded.take(4).toList();
    return Padding(
      padding: const EdgeInsets.all(20),
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
                      'Recent activity',
                      style: displayStyle(p, size: 17, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Latest platform updates',
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
          const SizedBox(height: 12),
          ...rows.map((paper) {
            final color = _statusColor(paper.status);
            final icon = paper.status == PaperStatus.approved
                ? Icons.check
                : paper.status == PaperStatus.rejected
                ? Icons.close
                : Icons.description;
            final action = paper.status == PaperStatus.approved
                ? 'had a paper approved'
                : paper.status == PaperStatus.rejected
                ? 'received a decision'
                : 'uploaded a new paper';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
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
                    child: Icon(icon, size: 13, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: bodyStyle(p, size: 13),
                            children: [
                              TextSpan(
                                text: paper.author,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(text: ' $action'),
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
      decoration: const InputDecoration(),
      items: [
        const DropdownMenuItem(value: 'all', child: Text('All subjects')),
        ..._fields.map((f) => DropdownMenuItem(value: f, child: Text(f))),
      ],
      onChanged: (v) => setState(() => _fieldFilter = v ?? 'all'),
    );
    final year = DropdownButtonFormField<String>(
      initialValue: _yearFilter,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.c.surface,
        border: Border.all(color: p.c.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          NetImage(
            url: paper.coverImage,
            width: 48,
            height: 64,
            borderRadius: BorderRadius.circular(6),
          ),
          const SizedBox(width: 12),
          Expanded(
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
          ),
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
              Text('${paper.pages} pages', style: monoStyle(p, size: 10)),
            ],
          ),
          const SizedBox(width: 12),
          StatusBadge(palette: p, status: paper.status),
          IconButton(
            tooltip: 'View ${paper.title}',
            icon: Icon(Icons.visibility_outlined, size: 18, color: p.c.muted),
            onPressed: () => _openDetail(paper),
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

            void submitReview() {
              if (reviewAction == null) return;
              if (reason.trim().isEmpty) {
                setD(() {
                  formError = reviewAction == 'reject'
                      ? 'A rejection reason is required.'
                      : 'Please describe the requested revisions.';
                });
                return;
              }
              if (reviewAction == 'reject') {
                widget.appState.rejectPaper(cur.id, reason.trim());
              } else {
                widget.appState.requestRevision(cur.id, reason.trim());
              }
              Navigator.of(ctx).pop();
            }

            Widget metaCell(String label, String value) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionLabel(palette: p, text: label),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: bodyStyle(p, size: 13, weight: FontWeight.w600),
                  ),
                ],
              );
            }

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
                            child: NetImage(
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
                            GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              childAspectRatio: 3.4,
                              children: [
                                metaCell('Subject', cur.field),
                                metaCell('Academic year', cur.year),
                                metaCell('Length', '${cur.pages} pages'),
                                metaCell('Submitted', timeAgo(cur.submittedAt)),
                              ],
                            ),
                            const SizedBox(height: 20),
                            SectionLabel(palette: p, text: 'Abstract'),
                            const SizedBox(height: 8),
                            Text(
                              cur.abstract,
                              style: bodyStyle(p, size: 14, height: 1.6),
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
                            const SizedBox(height: 20),
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
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  GhostButton(
                                    palette: p,
                                    label: 'Cancel',
                                    onPressed: () =>
                                        setD(() => reviewAction = null),
                                  ),
                                  const SizedBox(width: 8),
                                  if (reviewAction == 'reject')
                                    GhostButton(
                                      palette: p,
                                      label: 'Confirm rejection',
                                      color: p.danger,
                                      onPressed: submitReview,
                                    )
                                  else
                                    GoldButton(
                                      palette: p,
                                      label: 'Send revision request',
                                      minHeight: 40,
                                      onPressed: submitReview,
                                    ),
                                ],
                              ),
                            ] else ...[
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (cur.pdfUrl != null)
                                    TextButton.icon(
                                      icon: const Icon(
                                        Icons.download,
                                        size: 17,
                                      ),
                                      label: const Text('Read PDF'),
                                      onPressed: () => widget.appState.showToast(
                                        'PDF links open in a browser in the full app',
                                      ),
                                    ),
                                  if (cur.status == PaperStatus.pending) ...[
                                    GhostButton(
                                      palette: p,
                                      label: 'Request revisions',
                                      onPressed: () => setD(() {
                                        reviewAction = 'revision';
                                        reason = '';
                                        formError = null;
                                      }),
                                    ),
                                    GhostButton(
                                      palette: p,
                                      label: 'Reject',
                                      color: p.danger,
                                      onPressed: () => setD(() {
                                        reviewAction = 'reject';
                                        reason = '';
                                        formError = null;
                                      }),
                                    ),
                                    GoldButton(
                                      palette: p,
                                      label: 'Approve',
                                      minHeight: 40,
                                      onPressed: () {
                                        widget.appState.approvePaper(cur.id);
                                        Navigator.of(ctx).pop();
                                      },
                                    ),
                                  ],
                                  if (cur.status != PaperStatus.archived &&
                                      cur.status != PaperStatus.pending)
                                    GhostButton(
                                      palette: p,
                                      label: 'Archive',
                                      onPressed: () {
                                        widget.appState.archivePaper(cur.id);
                                        Navigator.of(ctx).pop();
                                      },
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
}
