/// Settings screen ported from `src/components/SettingsView.tsx`.
///
/// Theme controls (color mode, accent color) write through
/// [ThemeProvider.update]; the provider notifies and the root MaterialApp
/// rebuilds with the new [ThemeData], so changes apply live. Text size is
/// fixed at the Normal scale — there is no text-size control.
///
/// Account / app rows open detail pages in place (this app swaps views
/// instead of pushing routes, so Settings keeps its own page state):
/// Profile (navigates to the profile view), What's New (latest GitHub
/// release notes), Help (re-opens the first-time tour), About, and
/// Privacy Policy. No License page — virgil dropped the licence.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/constants.dart';
import '../data/privacy_policy.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/release_notes.dart';
import '../widgets/shared.dart';
import 'onboarding_tour.dart';

enum _SettingsPage { whatsNew, privacy, about }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.theme, required this.appState});

  final ThemeProvider theme;
  final AppState appState;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  _SettingsPage? _page;
  bool _checkingUpdate = false;

  /// Email field for the Forgot Password dialog, prefilled with the
  /// signed-in account's email when there is one.
  final _resetEmailController = TextEditingController();

  @override
  void dispose() {
    _resetEmailController.dispose();
    super.dispose();
  }

  ThemeProvider get theme => widget.theme;
  AppState get appState => widget.appState;

  // -- Section label ---------------------------------------------------------
  // Mirrors the `Section` component: mono 9px, letterspaced, muted, faint
  // bottom border.
  Widget _section(AppPalette p, String title) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 14),
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.c.borderFaint)),
      ),
      child: Text(
        title.toUpperCase(),
        style: monoStyle(
          p,
          size: 9,
          weight: FontWeight.w600,
          letterSpacing: 0.15,
        ),
      ),
    );
  }

  // -- Group title ("Color Mode" / "Accent Color") -------------------------------
  Widget _groupTitle(AppPalette p, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        title,
        style: bodyStyle(
          p,
          size: 14,
          weight: FontWeight.w500,
          color: p.c.textSub,
        ),
      ),
    );
  }

  // -- Color mode card (dark / light) -----------------------------------------
  Widget _modeCard(AppPalette p, AppMode mode, bool narrow) {
    final c = p.c;
    final a = p.accent;
    final active = theme.mode == mode;
    final dark = mode == AppMode.dark;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => theme.update(mode: mode),
          child: Container(
            constraints: BoxConstraints(minHeight: narrow ? 52 : 60),
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: narrow ? 12 : 14,
            ),
            decoration: BoxDecoration(
              color: active ? c.surface : Colors.transparent,
              border: Border.all(
                color: active ? a.accent : c.border,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                // Fixed-size slot keeps the mode icon centred in its card.
                SizedBox(
                  width: 28,
                  height: 28,
                  child: Icon(
                    dark ? Icons.dark_mode : Icons.light_mode,
                    size: 24,
                    color: active ? a.accent : c.text,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Never wrap: on narrow screens "Light Mode" is a few
                      // px wider than its slot and would drop to two lines
                      // while "Dark Mode" stays on one.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          dark ? 'Dark Mode' : 'Light Mode',
                          maxLines: 1,
                          style: bodyStyle(
                            p,
                            size: 14,
                            weight: FontWeight.w600,
                            color: active ? a.accent : c.text,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                  ),
                ),
                // Check badge slot is always laid out (transparent when
                // inactive) so selecting a mode never re-wraps the text or
                // resizes the cards.
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? a.accent : Colors.transparent,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.check,
                    size: 10,
                    color: active ? a.accentFg : Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -- Accent color option -----------------------------------------------------
  Widget _accentOption(
    AppPalette p,
    AppAccent option,
    double width,
    bool narrow,
  ) {
    final c = p.c;
    final pal = AccentPalette.of(option);
    final active = theme.accent == option;
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => theme.update(accent: option),
          child: Container(
            constraints: BoxConstraints(minHeight: narrow ? 60 : 72),
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: narrow ? 12 : 14,
            ),
            decoration: BoxDecoration(
              color: active ? pal.swatch.withValues(alpha: 0.09) : c.surface,
              border: Border.all(
                color: active ? pal.swatch : c.border,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: pal.swatch,
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: pal.swatch.withValues(alpha: 0.33),
                              blurRadius: 16,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  pal.label,
                  style: monoStyle(
                    p,
                    size: 10,
                    letterSpacing: 0.04,
                    color: active ? pal.swatch : c.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -- Settings row (Profile / What's New / Help / About / Privacy) --------
  Widget _row(
    AppPalette p, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    final c = p.c;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: Icon(icon, size: 22, color: c.text),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: bodyStyle(p, size: 14, weight: FontWeight.w600),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: bodyStyle(p, size: 12, color: c.muted),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: c.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Forgot Password: asks for the account email (prefilled when signed
  /// in) and sends Firebase's password-reset email. The email's wording
  /// and logo live in the Firebase console template, not in code.
  Future<void> _openForgotPassword() async {
    _resetEmailController.text = appState.user?.email ?? '';
    var error = '';
    final email = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Forgot Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your account email and we will send you a link to reset your password.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _resetEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Email address',
                  errorText: error.isEmpty ? null : error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final value = _resetEmailController.text.trim();
                if (value.isEmpty || !value.contains('@')) {
                  setDialogState(
                    () => error = 'Enter a valid email address.',
                  );
                  return;
                }
                Navigator.of(ctx).pop(value);
              },
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
    if (email == null || email.isEmpty || !mounted) return;
    final err = await appState.sendPasswordReset(email: email);
    if (!mounted) return;
    if (err != null) {
      appState.showToast(err, Icons.warning);
    } else {
      appState.showToast('Reset link sent to $email.', Icons.mail);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      appState.showToast('Could not open the link.', Icons.warning);
    }
  }

  Future<void> _checkForUpdates() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    await appState.checkForUpdate(forceRefresh: true);
    if (!mounted) return;
    setState(() => _checkingUpdate = false);
    if (!appState.updateAvailable) {
      appState.showToast(
        'You\'re up to date (v${AppConstants.currentVersion}).',
        Icons.check_circle,
      );
    }
    // When an update IS available, the update prompt dialog shows
    // itself — nothing else to do here.
  }

  // -- Detail pages (in place, with a back row) -------------------------------
  /// Opens a detail page and registers the system-back handler so the
  /// phone's back button returns to the settings list first.
  void _openPage(_SettingsPage page) {
    setState(() => _page = page);
    widget.appState.setInnerBackHandler(_closePage);
  }

  void _closePage() {
    setState(() => _page = null);
    widget.appState.setInnerBackHandler(null);
  }

  Widget _detailHeader(AppPalette p, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton(
          onPressed: _closePage,
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chevron_left, size: 14, color: p.accent.accent),
              const SizedBox(width: 2),
              Text(
                'Back to Settings',
                style: TextStyle(color: p.accent.accent, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: displayStyle(p, size: 22, weight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _whatsNewPage(AppPalette p) {
    final c = p.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _detailHeader(p, 'What\'s New'),
        FutureBuilder<AppUpdateInfo?>(
          future: appState.fetchLatestRelease(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final info = snapshot.data;
            if (info == null) {
              return Text(
                'No release notes yet. Check back after the next release — or pull down the Feed to refresh.',
                style: bodyStyle(p, size: 14, color: c.muted),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Version ${info.latestVersion} · ${timeAgo(info.updatedAt)}',
                  style: monoStyle(p, size: 10, color: p.accent.accent),
                ),
                const SizedBox(height: 12),
                ReleaseNotesView(
                  palette: p,
                  notes: info.notes,
                  version: info.latestVersion,
                  onOpenUrl: _openUrl,
                ),
                if (info.isNewerThan(AppConstants.currentVersion)) ...[
                  const SizedBox(height: 20),
                  GoldButton(
                    palette: p,
                    label: 'Update to ${info.latestVersion}',
                    onPressed: () async {
                      await appState.startUpdateDownload();
                    },
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _privacyPage(AppPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _detailHeader(p, 'Privacy Policy'),
        Text(
          kPrivacyPolicyText,
          style: bodyStyle(p, size: 14, color: p.c.textSub),
        ),
      ],
    );
  }

  Widget _aboutPage(AppPalette p) {
    final c = p.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _detailHeader(p, 'About'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              AppLogo(palette: p, fontSize: 17),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Arxiv · v${AppConstants.currentVersion}',
                      style: bodyStyle(p, size: 14, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'A paper library for students.',
                      style: bodyStyle(p, size: 12, color: c.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Browse research papers, read them in the app, submit your own, and follow the latest papers from arXiv. Built with Flutter and Firebase.',
          style: bodyStyle(p, size: 14, color: c.textSub),
        ),
        const SizedBox(height: 12),
        Text(
          'Project page: github.com/virgility9/arxivpanel',
          style: bodyStyle(p, size: 13, color: c.muted),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;
    final c = p.c;
    final narrow = MediaQuery.of(context).size.width < 700;
    final user = appState.user;

    return Scaffold(
      backgroundColor: c.bg,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: EdgeInsets.fromLTRB(
                narrow ? 16 : 20,
                narrow ? 20 : 28,
                narrow ? 16 : 20,
                narrow ? 20 : 24,
              ),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'PREFERENCES',
                      style: monoStyle(
                        p,
                        size: 9,
                        letterSpacing: 0.15,
                        color: p.accent.accent,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Settings',
                      style: displayStyle(p, size: 28, weight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    'Customize your reading experience',
                    style: bodyStyle(p, size: 14, color: c.muted),
                  ),
                ],
              ),
            ),

            // Content (maxWidth 640, centered)
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    narrow ? 16 : 20,
                    narrow ? 20 : 28,
                    narrow ? 16 : 20,
                    120,
                  ),
                  child: _page == _SettingsPage.whatsNew
                      ? _whatsNewPage(p)
                      : _page == _SettingsPage.privacy
                          ? _privacyPage(p)
                          : _page == _SettingsPage.about
                              ? _aboutPage(p)
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Appearance
                                    _section(p, 'Appearance'),

                                    // Color Mode
                                    _groupTitle(p, 'Color Mode'),
                                    // Color Mode — both cards keep an identical layout in
                                    // either mode (the check-badge slot is always laid
                                    // out), so switching modes never resizes them.
                                    Row(
                                      children: [
                                        _modeCard(p, AppMode.dark, narrow),
                                        const SizedBox(width: 10),
                                        _modeCard(p, AppMode.light, narrow),
                                      ],
                                    ),
                                    const SizedBox(height: 32),

                                    // Accent Color
                                    _groupTitle(p, 'Accent Color'),
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        // Clamp: on web, a hot restart can build one frame
                                        // before the browser reports a size, so maxWidth
                                        // arrives as 0 and (0 - 20) / 3 = -6.7, which makes
                                        // SizedBox throw "negative minimum width". At 0 the
                                        // chips are invisible for that one frame, then the
                                        // real-width frame lays them out normally.
                                        final w =
                                            ((constraints.maxWidth - 20) / 3)
                                                .clamp(0.0, double.infinity)
                                                .toDouble();
                                        return Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: AppAccent.values
                                              .map((option) =>
                                                  _accentOption(p, option, w, narrow))
                                              .toList(),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Saved to your account — your theme comes back after you sign out and sign in again.',
                                      style: bodyStyle(p, size: 12, color: c.muted),
                                    ),
                                    const SizedBox(height: 40),

                                    // Account
                                    _section(p, 'Account'),
                                    _row(
                                      p,
                                      icon: Icons.person,
                                      title: 'Profile',
                                      subtitle: user == null
                                          ? 'Sign in to view your profile'
                                          : user.username,
                                      onTap: () {
                                        if (user != null) {
                                          appState.navigate(AppView.profile);
                                        }
                                      },
                                    ),
                                    _row(
                                      p,
                                      icon: Icons.key,
                                      title: 'Forgot Password',
                                      subtitle:
                                          'Email a link to reset your password',
                                      onTap: _openForgotPassword,
                                    ),
                                    const SizedBox(height: 32),

                                    // App
                                    _section(p, 'App'),
                                    _row(
                                      p,
                                      icon: Icons.auto_awesome,
                                      title: 'What\'s New',
                                      subtitle:
                                          'Version ${AppConstants.currentVersion} — see the latest release notes',
                                      onTap: () => _openPage(
                                        _SettingsPage.whatsNew,
                                      ),
                                    ),
                                    _row(
                                      p,
                                      icon: Icons.download,
                                      title: 'Check for updates',
                                      subtitle: _checkingUpdate
                                          ? 'Checking…'
                                          : 'See if a newer version is out',
                                      onTap: _checkForUpdates,
                                    ),
                                    _row(
                                      p,
                                      icon: Icons.help,
                                      title: 'Help',
                                      subtitle:
                                          'Take the tour again — Library, Feed, Contest, Submit',
                                      onTap: () => OnboardingTour.show(
                                        context,
                                        appState: appState,
                                        theme: theme,
                                      ),
                                    ),
                                    const SizedBox(height: 32),

                                    // Info
                                    _section(p, 'Info'),
                                    _row(
                                      p,
                                      icon: Icons.info,
                                      title: 'About',
                                      subtitle:
                                          'Arxiv v${AppConstants.currentVersion}',
                                      onTap: () => _openPage(
                                        _SettingsPage.about,
                                      ),
                                    ),
                                    _row(
                                      p,
                                      icon: Icons.lock,
                                      title: 'Privacy Policy',
                                      subtitle:
                                          'What the app collects and where it lives',
                                      onTap: () => _openPage(
                                        _SettingsPage.privacy,
                                      ),
                                    ),
                                  ],
                                ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
