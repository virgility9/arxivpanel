/// Browse tab: the app's front door. Five inner tabs — Local Library
/// (the app's own submitted papers) plus E-books, Novels, Comics and
/// Manga. The catalog tabs are read-only: users browse and read there,
/// they never post. The active tab lives in [AppState.browseTab] (not
/// in this screen's local state) so the shell's Submit button and the
/// screen stay in sync, and the tab survives swipes.
library;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/shared.dart';
import 'library_screen.dart';

class BrowseScreen extends StatelessWidget {
  const BrowseScreen({
    super.key,
    required this.appState,
    required this.theme,
    required this.onAuthPrompt,
  });

  final AppState appState;
  final ThemeProvider theme;
  final VoidCallback onAuthPrompt;

  static const _tabs = <({BrowseTab tab, String label})>[
    (tab: BrowseTab.localLibrary, label: 'Local Library'),
    (tab: BrowseTab.ebooks, label: 'E-books'),
    (tab: BrowseTab.novels, label: 'Novels'),
    (tab: BrowseTab.comics, label: 'Comics'),
    (tab: BrowseTab.manga, label: 'Manga'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final tab = appState.browseTab;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _tabRow(p),
            Expanded(child: _tabBody(p, tab)),
          ],
        );
      },
    );
  }

  /// Horizontally scrollable tab strip, pinned above the tab content.
  /// Active tab gets the gold text + underline, like the desktop nav.
  Widget _tabRow(AppPalette p) {
    final c = p.c;
    final a = p.accent;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final t in _tabs)
              _browseTabButton(p, t, t.tab == appState.browseTab),
          ],
        ),
      ),
    );
  }

  Widget _browseTabButton(
      AppPalette p, ({BrowseTab tab, String label}) t, bool active) {
    final c = p.c;
    final a = p.accent;
    return InkWell(
      onTap: () => appState.setBrowseTab(t.tab),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? a.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          t.label,
          style: bodyStyle(
            p,
            size: 14,
            color: active ? a.accent : c.muted,
            weight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _tabBody(AppPalette p, BrowseTab tab) {
    switch (tab) {
      case BrowseTab.localLibrary:
        return LocalLibraryTab(
          appState: appState,
          theme: theme,
          onAuthPrompt: onAuthPrompt,
        );
      case BrowseTab.ebooks:
        return _comingSoon(
          p,
          icon: Icons.menu_book,
          title: 'E-books are on the way',
          sub: 'Free e-books from Project Gutenberg land here in the '
              'next update — browse the Local Library for now.',
        );
      case BrowseTab.novels:
        return _comingSoon(
          p,
          icon: Icons.auto_stories,
          title: 'Novels are on the way',
          sub: 'Free novels from Project Gutenberg land here in a later '
              'update — browse the Local Library for now.',
        );
      case BrowseTab.comics:
        return _comingSoon(
          p,
          icon: Icons.collections_bookmark,
          title: 'Comics are on the way',
          sub: 'Free comics from the Internet Archive land here in a '
              'later update — browse the Local Library for now.',
        );
      case BrowseTab.manga:
        return _comingSoon(
          p,
          icon: Icons.image,
          title: 'Manga is on the way',
          sub: 'Manga from MangaDex lands here in a later update — '
              'browse the Local Library for now.',
        );
    }
  }

  Widget _comingSoon(
    AppPalette p, {
    required IconData icon,
    required String title,
    required String sub,
  }) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
        child: EmptyState(
          palette: p,
          icon: icon,
          title: title,
          sub: sub,
        ),
      ),
    );
  }
}
