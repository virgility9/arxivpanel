/// Profile screen: page header with sign-out, centered identity block,
/// Edit Profile action, unified stats panel, and pill-tabbed lists
/// (My Papers / History / Saved).
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/constants.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../utils/file_pick.dart';
import '../utils/images.dart';
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

  /// Edit-profile dialog: avatar, display name, institution, bio, website.
  Future<void> _openEditDialog(AppUser user) async {
    _resetEditFields(user);
    final p = widget.theme.palette;
    final c = p.c;
    final a = p.accent;
    var saving = false;
    // Avatar source: either a picked image (bytes, stored as a data URL on
    // save — no Blaze billing needed) or a URL (current avatar or a preset).
    var avatarUrl = user.avatar;
    Uint8List? avatarBytes;
    await showDialog(
      context: context,
      // Locked: the dialog must still be the top route when the async
      // write below completes, otherwise pop() would hit the wrong page.
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Runs the Firestore write, then closes the dialog. The navigator
          // is captured before the async gap so no BuildContext is used
          // after the await (use_build_context_synchronously).
          Future<void> save() async {
            final navigator = Navigator.of(ctx);
            setDialogState(() => saving = true);
            try {
              final username = _nameCtrl.text.trim();
              // A picked image is downscaled and stored inline in the user
              // document as a data URL — no upload service needed.
              var avatar = avatarUrl;
              if (avatarBytes != null) {
                try {
                  avatar = avatarToDataUrl(avatarBytes!);
                } catch (e) {
                  widget.appState.showToast(
                    'Could not process the image (${shortError(e)})',
                    '⚠️',
                  );
                  setDialogState(() => saving = false);
                  return;
                }
              }
              await widget.appState.updateUser(
                user.copyWith(
                  username: username.isEmpty ? user.username : username,
                  avatar: avatar,
                  institution: _instCtrl.text.trim(),
                  bio: _bioCtrl.text,
                  website: _webCtrl.text.trim(),
                ),
              );
            } catch (_) {
              // updateUser already toasts on success; surface failures too
              // and re-enable the actions instead of leaving the dialog
              // stuck in the saving state.
              widget.appState.showToast('Could not save profile', '⚠️');
              setDialogState(() => saving = false);
              return;
            }
            // Safe: the barrier is locked and both actions were disabled
            // while saving, so the dialog is still the top route.
            navigator.pop();
          }

          return AlertDialog(
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
                    // --------------------------- avatar picker (device)
                    // Pick an image from device storage; it is downscaled and
                    // stored in your profile on save (no Blaze billing needed).
                    LabeledField(
                      palette: p,
                      label: 'Profile Picture',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (avatarBytes != null)
                                ClipOval(
                                  child: Image.memory(
                                    avatarBytes!,
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              else
                                AvatarImage(
                                  url: avatarUrl,
                                  size: 52,
                                  borderColor: a.accent,
                                  borderWidth: 2,
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: saving
                                      ? null
                                      : () async {
                                          try {
                                            final picked =
                                                await pickSingleFile(
                                              PickKind.image,
                                            );
                                            // Null = the user cancelled.
                                            if (picked == null) return;
                                            setDialogState(() {
                                              avatarBytes = picked.bytes;
                                            });
                                          } catch (e) {
                                            widget.appState.showToast(
                                              'Could not read the image '
                                              '(${shortError(e)})',
                                              '⚠️',
                                            );
                                          }
                                        },
                                  icon: const Icon(
                                    Icons.upload_outlined,
                                    size: 18,
                                  ),
                                  label: Text(
                                    'Choose from device',
                                    style:
                                        bodyStyle(p, size: 13, color: c.text),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: c.border),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    minimumSize:
                                        const Size.fromHeight(40),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '…or pick a preset:',
                            style: bodyStyle(p, size: 12, color: c.muted),
                          ),
                          const SizedBox(height: 8),
                          // Wrap instead of Row: 6 presets no longer fit on
                          // one line at narrow dialog widths.
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final url in AppConstants.randomAvatars)
                                InkWell(
                                  borderRadius:
                                      BorderRadius.circular(22),
                                  onTap: saving
                                      ? null
                                      : () => setDialogState(() {
                                            avatarUrl = url;
                                            avatarBytes = null;
                                          }),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: avatarBytes == null &&
                                                avatarUrl == url
                                            ? a.accent
                                            : Colors.transparent,
                                        width: 2.5,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: Image.network(
                                        url,
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            Container(
                                          width: 40,
                                          height: 40,
                                          color: c.surface2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
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
                onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                child: Text('Cancel', style: TextStyle(color: c.muted)),
              ),
              GoldButton(
                palette: p,
                label: 'Save Changes',
                minHeight: 40,
                loading: saving,
                onPressed: saving ? null : save,
              ),
            ],
          );
        },
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
              foregroundColor: p.danger,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (ok == true) await widget.appState.logout();
  }

  Future<void> _confirmDelete(Paper paper) async {
    final p = widget.theme.palette;
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
              foregroundColor: p.danger,
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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    hPad, 20, hPad, isNarrow ? 100 : 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ---------------------------------- page header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Profile',
                          style: displayStyle(
                            p,
                            size: 17,
                            weight: FontWeight.w600,
                          ),
                        ),
                        InkWell(
                          onTap: _confirmSignOut,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 4,
                            ),
                            child: Text(
                              'Sign Out',
                              style: TextStyle(
                                color: p.danger,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    _header(p, c, a, user),
                    const SizedBox(height: 24),
                    _bioBlock(p, c, user),
                    _statsPanel(
                      p,
                      myPapers.length,
                      formatCount(totalViews),
                      totalReactions,
                      '${(totalReadSeconds / 60).round()}m',
                    ),
                    const SizedBox(height: 20),
                    _tabsRow(p, c, a, tabs),
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
                                  icon: Icons.description_outlined,
                                  title: 'No papers yet',
                                  sub:
                                      'Papers you publish will show up here.',
                                  // Admins do admin tasks only — no submit
                                  // action for them.
                                  actionLabel: widget.appState.user?.isAdmin ==
                                          true
                                      ? null
                                      : 'Submit a paper',
                                  onAction: widget.appState.user?.isAdmin ==
                                          true
                                      ? null
                                      : () => widget.appState
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
                                  icon: Icons.menu_book_outlined,
                                  title: 'No reading history',
                                  sub: 'Papers you open will appear here.',
                                )
                              : _historyList(p, c, historyPapers)
                        else
                          savedPapers.isEmpty
                              ? _emptyTab(
                                  p,
                                  icon: Icons.bookmark_border,
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
          );
      },
    );
  }

  // ------------------------------------------------------------ sections

  /// Centered identity block: avatar with gold ring, name, joined date,
  /// and the Edit Profile action.
  Widget _header(
    AppPalette p,
    AppColors c,
    AccentPalette a,
    AppUser user,
  ) {
    final narrow = MediaQuery.of(context).size.width < 700;
    return Column(
      children: [
        SizedBox(height: narrow ? 12 : 16),
        _profileAvatar(p, a, user, narrow ? 72 : 88),
        SizedBox(height: narrow ? 10 : 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            user.username,
            style: displayStyle(
              p,
              size: narrow ? 20 : 22,
              weight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Joined ${formatMonthYear(user.joinedAt)}',
          style: monoStyle(p, size: 11, color: c.muted),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: narrow ? 12 : 16),
        GhostButton(
          palette: p,
          label: 'Edit Profile',
          color: a.accent,
          minHeight: 40,
          onPressed: () => _openEditDialog(user),
        ),
      ],
    );
  }

  /// Avatar with gold ring; falls back to the user's initials when the
  /// image can't be loaded.
  Widget _profileAvatar(
    AppPalette p,
    AccentPalette a,
    AppUser user,
    double size,
  ) {
    final initials = _initials(user.username);
    final fallback = Container(
      color: p.c.surface2,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: a.accent,
          fontSize: size * 0.32,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: a.accent, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipOval(
        // Custom avatars are inline data URLs; presets are network URLs.
        child: isDataUrl(user.avatar)
            ? Image.memory(
                dataUrlToBytes(user.avatar),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              )
            : Image.network(
                user.avatar,
                fit: BoxFit.cover,
                loadingBuilder: (ctx, child, progress) =>
                    progress == null ? child : fallback,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }

  /// "Joe Black" -> "JB".
  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final w = parts[0];
      return w.substring(0, w.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
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
    final narrow = MediaQuery.of(context).size.width < 700;
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: narrow ? 64 : 96,
        horizontal: 24,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('👤', style: TextStyle(fontSize: narrow ? 44 : 56)),
          SizedBox(height: narrow ? 16 : 20),
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
          SizedBox(height: narrow ? 20 : 24),
          SizedBox(
            width: double.infinity,
            child: GoldButton(
              palette: p,
              label: 'Sign In to Continue',
              onPressed: widget.onAuthPrompt,
              minHeight: narrow ? 48 : 52,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- stats

  /// One unified stats panel: 2×2 cells separated by thin dividers,
  /// colored values, uppercase labels.
  Widget _statsPanel(
    AppPalette p,
    int papers,
    String views,
    int reactions,
    String readTime,
  ) {
    final c = p.c;
    Widget row(List<Widget> cells) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: cells[0]),
            Container(width: 1, color: c.border),
            Expanded(child: cells[1]),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          row([
            _statCell(
              p,
              value: '$papers',
              label: 'Papers',
              color: p.accent.accent,
            ),
            _statCell(
              p,
              value: views,
              label: 'Total Views',
              color: p.info,
            ),
          ]),
          Container(height: 1, color: c.border),
          row([
            _statCell(
              p,
              value: '$reactions',
              label: 'Reactions Received',
              color: p.danger,
            ),
            _statCell(
              p,
              value: readTime,
              label: 'Read Time',
              color: p.success,
            ),
          ]),
        ],
      ),
    );
  }

  /// One stats cell: colored value over an uppercase label.
  Widget _statCell(
    AppPalette p, {
    required String value,
    required String label,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            style: monoStyle(p, size: 9, color: p.c.muted, letterSpacing: 0.05),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- tabs

  /// Segmented pill tabs: the active tab gets a highlighted background
  /// and gold label, in "Label · count" form.
  Widget _tabsRow(
    AppPalette p,
    AppColors c,
    AccentPalette a,
    List<({String label, int count})> tabs,
  ) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(7),
                onTap: () => setState(() => _tab = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _tab == i ? c.surface2 : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    '${tabs[i].label} · ${tabs[i].count}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          _tab == i ? FontWeight.w600 : FontWeight.w400,
                      color: _tab == i ? a.accent : c.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Empty tab state: muted icon, title, subtitle, optional action.
  Widget _emptyTab(
    AppPalette p, {
    required IconData icon,
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
          Icon(icon, size: 36, color: c.faint),
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
