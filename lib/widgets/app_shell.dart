/// Application shell ported from `src/App.tsx` + `Navbar.tsx` + `BottomNav.tsx`.
///
/// Renders the top navbar (logo, nav links, user menu / auth buttons), swaps
/// the active view, shows the mobile bottom navigation bar, and overlays the
/// toast stack. Screens receive [AppState], [ThemeProvider] and an
/// `onAuthPrompt` callback that opens the [AuthDialog].
library;

import 'package:flutter/material.dart';

import '../data/constants.dart';
import '../models/models.dart';
import '../screens/admin_screen.dart';
import '../screens/feed_screen.dart';
import '../screens/library_screen.dart';
import '../screens/polls_screen.dart';
import '../screens/post_paper_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/reader_screen.dart';
import '../screens/settings_screen.dart';
import '../state/app_state.dart';
import '../theme/theme_provider.dart';
import 'app_icons.dart';
import 'auth_dialog.dart';
import 'feed_icon.dart';
import 'motion.dart';
import 'shared.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.appState, required this.theme});

  final AppState appState;
  final ThemeProvider theme;

  void _promptAuth(BuildContext context, [AuthMode mode = AuthMode.login]) {
    AuthDialog.show(context, mode: mode, appState: appState, theme: theme);
  }

  void _navigate(BuildContext context, AppView view) =>
      appState.navigate(view, onAuthPrompt: () => _promptAuth(context));

  @override
  Widget build(BuildContext context) {
    final palette = theme.palette;
    final c = palette.c;
    final isNarrow = MediaQuery.of(context).size.width < 700;

    return PopScope(
      // No router in this app, so intercept the system back button: on any
      // non-library view, go back to the library instead of exiting.
      // (Browser back-button history is not wired; this covers Android
      // system back and programmatic pops.)
      canPop: appState.view == AppView.library,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _navigate(context, AppView.library);
      },
      child: Scaffold(
        backgroundColor: c.bg,
        body: Stack(
          children: [
            Column(
              children: [
                _Navbar(
                  appState: appState,
                  theme: theme,
                  isNarrow: isNarrow,
                  onNavigate: (v) => _navigate(context, v),
                  onAuthPrompt: (m) => _promptAuth(context, m),
                ),
                Expanded(
                  child: MotionSwitcher(
                    expand: true,
                    child: KeyedSubtree(
                      // One key for all tabs: tab-to-tab motion is owned by
                      // the PageView, so the switcher must not animate it.
                      // The reader and the submit form keep their own keys
                      // so the switcher still fades/slides those in.
                      key: ValueKey(_contentKey),
                      child: _buildContent(context),
                    ),
                  ),
                ),
              ],
            ),
            // Faint paper grain over the whole page (ignores touches).
            Positioned.fill(child: GrainTexture(palette: palette)),
            // Toast stack
            Positioned(
              left: 16,
              right: 16,
              bottom: isNarrow ? 74 : 24,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: appState.toasts
                        .map(
                          (t) => _ToastCard(
                            palette: palette,
                            toast: t,
                            onDismiss: () => appState.dismissToast(t.id),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: isNarrow
            ? _BottomNav(
                appState: appState,
                theme: theme,
                onNavigate: (v) => _navigate(context, v),
                onAuthPrompt: () => _promptAuth(context),
              )
            : null,
      ),
    );
  }

  Widget _buildView(BuildContext context, AppView view) {
    void onAuthPrompt() => _promptAuth(context);
    switch (view) {
      case AppView.library:
        return LibraryScreen(
          appState: appState,
          theme: theme,
          onAuthPrompt: onAuthPrompt,
        );
      case AppView.feed:
        return FeedScreen(appState: appState, theme: theme);
      case AppView.reader:
        if (appState.selectedPaper == null) {
          return LibraryScreen(
            appState: appState,
            theme: theme,
            onAuthPrompt: onAuthPrompt,
          );
        }
        return ReaderScreen(
          appState: appState,
          theme: theme,
          onAuthPrompt: onAuthPrompt,
        );
      case AppView.post:
        return PostPaperScreen(
          appState: appState,
          theme: theme,
          onAuthPrompt: onAuthPrompt,
        );
      case AppView.polls:
        return PollsScreen(appState: appState, theme: theme);
      case AppView.profile:
        if (appState.user == null) {
          return LibraryScreen(
            appState: appState,
            theme: theme,
            onAuthPrompt: onAuthPrompt,
          );
        }
        return ProfileScreen(
            appState: appState, theme: theme, onAuthPrompt: onAuthPrompt);
      case AppView.settings:
        return SettingsScreen(theme: theme);
      case AppView.admin:
        if (appState.user?.isAdmin != true) {
          return LibraryScreen(
            appState: appState,
            theme: theme,
            onAuthPrompt: onAuthPrompt,
          );
        }
        return AdminScreen(appState: appState, theme: theme);
    }
  }

  /// MotionSwitcher key: one key for all tabs, so tab-to-tab motion is
  /// owned by the PageView and the switcher does not animate it; the
  /// reader and the submit form keep their own keys so the switcher
  /// still fades/slides those in.
  String get _contentKey {
    final view = appState.view;
    if (view == AppView.reader) return 'reader:${appState.selectedPaper?.id}';
    if (view == AppView.post) return 'post';
    return 'tabs';
  }

  Widget _buildContent(BuildContext context) {
    final view = appState.view;
    if (view == AppView.reader || view == AppView.post) {
      return _buildView(context, view);
    }
    return _TabPages(
      appState: appState,
      pageBuilder: (v) => _buildView(context, v),
      onPageChanged: (v) => _navigate(context, v),
    );
  }
}

// ---------------------------------------------------------------------------
// Swipe between tabs
// ---------------------------------------------------------------------------

/// The swipeable tab strip: a [PageView] over the bottom-nav tabs, so a
/// swipe drags the next tab in under the finger (like Facebook) and the
/// release snaps to the nearest tab — the tab is visible mid-swipe
/// instead of only appearing after the drag ends. Pages stay alive while
/// the user moves between tabs (scroll position, search text, Feed tab,
/// local likes), and bottom-nav taps animate the PageView to the tapped
/// tab. Only the browsable tabs participate: the reader is excluded
/// (its PDF view uses horizontal swipes to turn pages) and the submit
/// form is excluded (a swipe must never discard a draft). A swipe over
/// a horizontally scrolling list scrolls that list instead — the inner
/// scroller wins the gesture arena — and vertical scrolling is
/// untouched.
class _TabPages extends StatefulWidget {
  const _TabPages({
    required this.appState,
    required this.pageBuilder,
    required this.onPageChanged,
  });

  final AppState appState;
  final Widget Function(AppView view) pageBuilder;
  final void Function(AppView view) onPageChanged;

  @override
  State<_TabPages> createState() => _TabPagesState();
}

class _TabPagesState extends State<_TabPages> {
  late final PageController _controller;

  /// The page the view wants but the PageView has not reached yet (a
  /// bottom-nav tap whose animation is still in flight). Cleared when
  /// the PageView lands on it; a drag that lands elsewhere overrides
  /// it (see [_onPageChanged]).
  int? _tapTarget;

  /// The view the last sync ran for. Only a view change (a tap, a
  /// swipe landing, back-to-library) needs the PageView to move — a
  /// data update must never retarget a drag or fling in progress.
  late AppView _lastView;

  /// Tabs a swipe can move between, in bottom-nav order. Mirrors the
  /// items built by [_BottomNav] (submit excluded, admin last).
  List<AppView> get _tabs {
    final isAdmin = widget.appState.user?.isAdmin == true;
    return [
      AppView.library,
      AppView.feed,
      AppView.polls,
      AppView.profile,
      AppView.settings,
      if (isAdmin) AppView.admin,
    ];
  }

  int _indexOf(AppView view) {
    final index = _tabs.indexOf(view);
    return index < 0 ? 0 : index;
  }

  @override
  void initState() {
    super.initState();
    _lastView = widget.appState.view;
    _controller = PageController(initialPage: _indexOf(widget.appState.view));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Moves the PageView to [page]: instantly when the OS asks to reduce
  /// motion, animated (240ms easeOutCubic) otherwise. The drag itself
  /// is user-driven, so it is never suppressed.
  void _goToPage(int page) {
    if (motionReduced(context)) {
      _controller.jumpToPage(page);
    } else {
      _controller.animateToPage(
        page,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// Bottom-nav taps change [AppState.view] outside the PageView; animate
  /// the PageView to match. Runs after the frame so the controller is
  /// laid out, and only when the view actually changed — never on a
  /// data-only rebuild, and never while the user's finger is down (a
  /// drag in progress settles first; [_onPageChanged] syncs the view).
  /// A tap that lands while a previous tap (or a fling) is still
  /// settling retargets the animation instead of fighting it.
  @override
  void didUpdateWidget(covariant _TabPages oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.appState.view == _lastView) return;
    _lastView = widget.appState.view;
    if (!_controller.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final target = _indexOf(widget.appState.view);
      final current = _controller.page?.round() ?? _controller.initialPage;
      if (current == target) {
        _tapTarget = null;
        return;
      }
      // Finger down: the user owns the PageView until the drag settles.
      if (_controller.position.activity is DragScrollActivity) return;
      _goToPage(target);
      _tapTarget = target;
    });
  }

  void _onPageChanged(int index) {
    if (_tapTarget != null) {
      if (index == _tapTarget) {
        // A tap animation landed on its target; the view is already right.
        _tapTarget = null;
        return;
      }
      // A tap was pending but the page settled elsewhere: the user
      // dragged and overrode it, so the swipe wins.
      _tapTarget = null;
    }
    final view = _tabs[index];
    if (widget.appState.view == view) return;
    final before = widget.appState.view;
    widget.onPageChanged(view);
    // A refused navigation (e.g. Profile while signed out) leaves the
    // view on the old tab: slide the PageView back to it.
    if (widget.appState.view == before && before != view) {
      _goToPage(_indexOf(before));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    return PageView.builder(
      controller: _controller,
      itemCount: tabs.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        final view = tabs[index];
        return _KeepAlive(
          child: KeyedSubtree(
            key: ValueKey(view.name),
            child: widget.pageBuilder(view),
          ),
        );
      },
    );
  }
}

/// Keeps a PageView page's state alive while the user swipes to another
/// tab (scroll position, text, local toggles), so coming back feels like
/// returning, not reopening.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

// ---------------------------------------------------------------------------
// Top navbar
// ---------------------------------------------------------------------------

class _Navbar extends StatelessWidget {
  const _Navbar({
    required this.appState,
    required this.theme,
    required this.isNarrow,
    required this.onNavigate,
    required this.onAuthPrompt,
  });

  final AppState appState;
  final ThemeProvider theme;
  final bool isNarrow;
  final void Function(AppView) onNavigate;
  final void Function(AuthMode) onAuthPrompt;

  @override
  Widget build(BuildContext context) {
    final palette = theme.palette;
    final c = palette.c;
    final a = palette.accent;
    final user = appState.user;
    final view = appState.view;
    final pendingCount = appState.pendingPapers.length;

    Widget navLink(String label, AppView v,
        {AppIcon? icon, bool feedIcon = false, int? badge}) {
      final active =
          view == v || (v == AppView.library && view == AppView.reader);
      return InkWell(
        onTap: () => onNavigate(v),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? a.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (feedIcon) ...[
                FeedIconImage(
                  size: 16,
                  color: active ? a.accent : c.muted,
                ),
                const SizedBox(width: 6),
              ] else if (icon != null) ...[
                AppIconImage(
                  icon,
                  size: 16,
                  color: active ? a.accent : c.muted,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: active ? a.accent : c.muted,
                ),
              ),
              if (badge != null && badge > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: a.accent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '$badge',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: a.accentFg,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: c.navBg,
        border: Border(bottom: BorderSide(color: c.border)),
        boxShadow: [
          BoxShadow(
            color: c.shadow.withValues(alpha: c.shadow.a * 0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => onNavigate(AppView.library),
                child: AppLogo(palette: palette, fontSize: isNarrow ? 17 : 20),
              ),
              if (!isNarrow) ...[
                const SizedBox(width: 12),
                navLink('Library', AppView.library, icon: AppIcon.library),
                navLink('Feed', AppView.feed, feedIcon: true),
                navLink('Contest', AppView.polls, icon: AppIcon.contest),
                navLink('Submit', AppView.post, icon: AppIcon.submit),
                if (user?.isAdmin == true)
                  navLink(
                    'Admin',
                    AppView.admin,
                    icon: AppIcon.admin,
                    badge: pendingCount,
                  ),
                const Spacer(),
                if (user != null)
                  _UserMenu(
                    appState: appState,
                    theme: theme,
                    onNavigate: onNavigate,
                    pendingCount: pendingCount,
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GhostButton(
                        palette: palette,
                        label: AppConstants.signInLabel,
                        minHeight: 36,
                        onPressed: () => onAuthPrompt(AuthMode.login),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 36,
                        child: GoldButton(
                          palette: palette,
                          label: 'Register',
                          minHeight: 36,
                          onPressed: () => onAuthPrompt(AuthMode.register),
                        ),
                      ),
                    ],
                  ),
              ] else ...[
                const Spacer(),
                if (user != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AvatarImage(
                        url: user.avatar,
                        size: 30,
                        borderColor: a.accent,
                        borderWidth: 2,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        user.username,
                        style: bodyStyle(palette, size: 12, color: c.textSub),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GhostButton(
                        palette: palette,
                        label: AppConstants.signInLabel,
                        minHeight: 32,
                        onPressed: () => onAuthPrompt(AuthMode.login),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        height: 32,
                        child: GoldButton(
                          palette: palette,
                          label: 'Register',
                          minHeight: 32,
                          onPressed: () => onAuthPrompt(AuthMode.register),
                        ),
                      ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UserMenu extends StatelessWidget {
  const _UserMenu({
    required this.appState,
    required this.theme,
    required this.onNavigate,
    required this.pendingCount,
  });

  final AppState appState;
  final ThemeProvider theme;
  final void Function(AppView) onNavigate;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final palette = theme.palette;
    final c = palette.c;
    final user = appState.user!;

    return PopupMenuButton<String>(
      offset: const Offset(0, 44),
      color: c.surface,
      elevation: 6,
      shadowColor: c.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.border),
      ),
      onSelected: (value) {
        switch (value) {
          case 'profile':
            onNavigate(AppView.profile);
            break;
          case 'settings':
            onNavigate(AppView.settings);
            break;
          case 'post':
            onNavigate(AppView.post);
            break;
          case 'admin':
            onNavigate(AppView.admin);
            break;
          case 'logout':
            appState.logout();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'profile',
          child: Text(
            'My Profile',
            style: TextStyle(color: c.text, fontSize: 13),
          ),
        ),
        PopupMenuItem(
          value: 'settings',
          child: Text(
            'Settings',
            style: TextStyle(color: c.text, fontSize: 13),
          ),
        ),
        PopupMenuItem(
          value: 'post',
          child: Text(
            'Submit Paper',
            style: TextStyle(color: c.text, fontSize: 13),
          ),
        ),
        if (user.isAdmin)
          PopupMenuItem(
            value: 'admin',
            child: Row(
              children: [
                Text(
                  '🛡️ Admin Panel',
                  style: TextStyle(color: palette.accent.accent, fontSize: 13),
                ),
                if (pendingCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: palette.accent.accent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '$pendingCount',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: palette.accent.accentFg,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'logout',
          child: const Text(
            'Sign Out',
            style: TextStyle(color: Color(0xFFC75B52), fontSize: 13),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.only(left: 4, right: 12, top: 4, bottom: 4),
        decoration: BoxDecoration(
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AvatarImage(url: user.avatar, size: 26),
            const SizedBox(width: 8),
            Text(
              user.username,
              style: TextStyle(
                color: c.text,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Text('▾', style: TextStyle(color: c.muted, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mobile bottom nav
// ---------------------------------------------------------------------------

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.appState,
    required this.theme,
    required this.onNavigate,
    required this.onAuthPrompt,
  });

  final AppState appState;
  final ThemeProvider theme;
  final void Function(AppView) onNavigate;
  final VoidCallback onAuthPrompt;

  @override
  Widget build(BuildContext context) {
    final palette = theme.palette;
    final c = palette.c;
    final a = palette.accent;
    final view = appState.view;
    final hasUser = appState.user != null;
    final isAdmin = appState.user?.isAdmin == true;

    final items =
        <
          ({
            AppView view,
            AppIcon? icon,
            String label,
            bool requiresAuth,
            int? badge,
          })
        >[
          (
            view: AppView.library,
            icon: AppIcon.library,
            label: 'Library',
            requiresAuth: false,
            badge: null,
          ),
          (
            view: AppView.feed,
            // Null icon means the custom newspaper icon below.
            icon: null,
            label: 'Feed',
            requiresAuth: false,
            badge: null,
          ),
          (
            view: AppView.polls,
            icon: AppIcon.contest,
            label: 'Contest',
            requiresAuth: false,
            badge: null,
          ),
          // Admins do admin tasks only — paper submission is hidden for them.
          if (!isAdmin)
            (
              view: AppView.post,
              icon: AppIcon.submit,
              label: 'Submit',
              requiresAuth: false,
              badge: null,
            ),
          (
            view: AppView.profile,
            icon: AppIcon.profile,
            label: 'Profile',
            requiresAuth: true,
            badge: null,
          ),
          (
            view: AppView.settings,
            icon: AppIcon.settings,
            label: 'Settings',
            requiresAuth: false,
            badge: null,
          ),
          if (isAdmin)
            (
              view: AppView.admin,
              icon: AppIcon.admin,
              label: 'Admin',
              requiresAuth: false,
              badge: appState.pendingPapers.isEmpty
                  ? null
                  : appState.pendingPapers.length,
            ),
        ];

    bool isActive(AppView v) {
      if (v == AppView.library && view == AppView.reader) return true;
      return view == v;
    }

    return Container(
      decoration: BoxDecoration(
        color: c.navBg,
        border: Border(top: BorderSide(color: c.border)),
        boxShadow: [
          BoxShadow(
            color: c.shadow.withValues(alpha: c.shadow.a * 0.35),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: items.map((item) {
            final active = isActive(item.view);
            final disabled = item.requiresAuth && !hasUser;
            return Expanded(
              child: InkWell(
                onTap: disabled ? onAuthPrompt : () => onNavigate(item.view),
                child: Opacity(
                  opacity: disabled ? 0.35 : 1,
                  child: Container(
                    padding: const EdgeInsets.only(top: 10, bottom: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            item.icon != null
                                ? AppIconImage(
                                    item.icon!,
                                    size: 20,
                                    color: active
                                        ? a.accent
                                        : c.muted.withValues(alpha: 0.7),
                                  )
                                : FeedIconImage(
                                    size: 20,
                                    color: active
                                        ? a.accent
                                        : c.muted.withValues(alpha: 0.7),
                                  ),
                            if (item.badge != null)
                              Positioned(
                                top: -6,
                                right: -10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: a.accent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${item.badge}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: a.accentFg,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label.toUpperCase(),
                          style: monoStyle(
                            palette,
                            size: 9,
                            letterSpacing: 0.04,
                            color: active ? a.accent : c.muted,
                            weight: active
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        if (active)
                          Container(
                            margin: const EdgeInsets.only(top: 3),
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: a.accent,
                            ),
                          )
                        else
                          const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Toast
// ---------------------------------------------------------------------------

class _ToastCard extends StatelessWidget {
  const _ToastCard({
    required this.palette,
    required this.toast,
    required this.onDismiss,
  });

  final dynamic palette;
  final AppToast toast;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = palette.c;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(12),
        boxShadow: c.raisedShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (toast.icon != null) ...[
            Text(toast.icon!, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              toast.message,
              style: TextStyle(
                color: c.text,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Manual dismiss — previously toasts could only vanish on the
          // 3-second timer.
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onDismiss,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Text('✕', style: TextStyle(fontSize: 12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
