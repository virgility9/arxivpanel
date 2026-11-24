/// First-time help tour: a short paged helper that shows once, right
/// after a new user registers and signs in. Every step has Skip, the
/// last step has Got it — either one marks the tour seen on the
/// account, so it never shows again. Re-openable any time from
/// Settings > Help.
library;

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/theme_provider.dart';
import '../widgets/shared.dart';

class OnboardingTour {
  OnboardingTour._();

  static const _steps = <({IconData icon, String title, String body})>[
    (
      icon: Icons.library_books,
      title: 'Welcome to Arxiv',
      body:
          'A paper library for students. Browse research papers, read them in the app, and save the ones you want to come back to.',
    ),
    (
      icon: Icons.search,
      title: 'Browse',
      body:
          'Find papers in the Local Library, or read free e-books, novels, manga and comics. Tap a card to open it, tap the heart to like it, and tap the bookmark to save it.',
    ),
    (
      icon: Icons.bookmark,
      title: 'Library',
      body:
          'Everything you save lives here, grouped by type, so you never have to browse for it twice.',
    ),
    (
      icon: Icons.newspaper,
      title: 'Feed',
      body:
          'See the latest papers from arXiv and today\'s science news. Pull down to refresh, tap a card to open the article.',
    ),
    (
      icon: Icons.emoji_events,
      title: 'Contest',
      body:
          'See the most-liked papers and read announcements from the admins here. New announcements ping this tab.',
    ),
    (
      icon: Icons.upload,
      title: 'Submit a paper',
      body:
          'Tap the gold button at the bottom right to submit your own paper. Pick a PDF from your device — it is reviewed before it appears in the Local Library.',
    ),
  ];

  /// Shows the tour dialog. Marks it seen on Skip or Got it.
  static Future<void> show(
    BuildContext context, {
    required AppState appState,
    required ThemeProvider theme,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _TourDialog(appState: appState, theme: theme),
    );
  }
}

class _TourDialog extends StatefulWidget {
  const _TourDialog({required this.appState, required this.theme});

  final AppState appState;
  final ThemeProvider theme;

  @override
  State<_TourDialog> createState() => _TourDialogState();
}

class _TourDialogState extends State<_TourDialog> {
  int _index = 0;

  Future<void> _finish(BuildContext context) async {
    await widget.appState.markOnboardingSeen();
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.theme.palette;
    final c = p.c;
    final steps = OnboardingTour._steps;
    final step = steps[_index];
    final last = _index == steps.length - 1;
    return AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.border),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(step.icon, size: 28, color: c.text),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  step.title,
                  style: displayStyle(p, size: 18, weight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(step.body, style: bodyStyle(p, size: 14, color: c.textSub)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < steps.length; i++)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _index ? p.accent.accent : c.border,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Step ${_index + 1} of ${steps.length}',
              style: monoStyle(p, size: 10, color: c.muted),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _finish(context),
          child: Text('Skip', style: TextStyle(color: c.muted)),
        ),
        TextButton(
          onPressed: last
              ? () => _finish(context)
              : () => setState(() => _index++),
          child: Text(
            last ? 'Got it' : 'Next',
            style: TextStyle(
              color: p.accent.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
