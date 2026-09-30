/// Application shell ported from `src/App.tsx` + `Navbar.tsx` + `BottomNav.tsx`.
///
/// Renders the top navbar (logo, nav links, user menu / auth buttons), swaps
/// the active view, shows the mobile bottom navigation bar, and overlays the
/// toast stack. Screens receive [AppState], [ThemeProvider] and an
/// `onAuthPrompt` callback that opens the [AuthDialog].
library;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../screens/admin_screen.dart';
import '../screens/library_screen.dart';
import '../screens/polls_screen.dart';
import '../screens/post_paper_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/reader_screen.dart';
import '../screens/settings_screen.dart';
import '../state/app_state.dart';
import '../theme/theme_provider.dart';
import 'auth_dialog.dart';
import 'shared.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.appState, required this.theme});

  final AppState appState;
  final ThemeProvider theme;

  void _promptAuth(BuildContext context, [AuthMode mode = AuthMode.login]) {
    AuthDialog.show(context, mode: mode, appState: appState, theme: theme);
  }

  void _navigate(BuildContext context, AppView view) {
    appState.navigate(view, onAuthPrompt: () => _promptAuth(context));
  }

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
                Expanded(child: _buildView(context)),
              ],
            ),
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

  Widget _buildView(BuildContext context) {
    void onAuthPrompt() => _promptAuth(context);
    switch (appState.view) {
      case AppView.library:
        return LibraryScreen(
          appState: appState,
          theme: theme,
          onAuthPrompt: onAuthPrompt,
        );
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

    Widget navLink(String label, AppView v, {int? badge}) {
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
                navLink('Library', AppView.library),
                navLink('Contest', AppView.polls),
                navLink('Submit', AppView.post),
                if (user?.isAdmin == true)
                  navLink('Admin', AppView.admin, badge: pendingCount),
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
                        label: 'Sign In',
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
                        label: 'Sign In',
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
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
            style: TextStyle(color: Color(0xFFE06B6B), fontSize: 13),
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
            String icon,
            String label,
            bool requiresAuth,
            int? badge,
          })
        >[
          (
            view: AppView.library,
            icon: '📚',
            label: 'Library',
            requiresAuth: false,
            badge: null,
          ),
          (
            view: AppView.polls,
            icon: '🏆',
            label: 'Contest',
            requiresAuth: false,
            badge: null,
          ),
          (
            view: AppView.post,
            icon: '✏️',
            label: 'Submit',
            requiresAuth: false,
            badge: null,
          ),
          (
            view: AppView.profile,
            icon: '👤',
            label: 'Profile',
            requiresAuth: true,
            badge: null,
          ),
          (
            view: AppView.settings,
            icon: '⚙️',
            label: 'Settings',
            requiresAuth: false,
            badge: null,
          ),
          if (isAdmin)
            (
              view: AppView.admin,
              icon: '🛡️',
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
                            Text(
                              item.icon,
                              style: TextStyle(
                                fontSize: 20,
                                color: active
                                    ? null
                                    : c.muted.withValues(alpha: 0.7),
                              ),
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
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 9,
                            letterSpacing: 0.04,
                            color: active ? a.accent : c.muted,
                            fontWeight: active
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
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
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
