/// Clean rendering of GitHub release notes (Settings > What's New and the
/// in-app update prompt).
///
/// `scripts/release.ps1` creates releases with `--generate-notes`, so the
/// body arrives as raw markdown:
///
///   ## What's Changed
///   * Refresh UI: ... by @virgility9 in https://github.com/.../pull/1
///
///   ## New Contributors
///   * @virgility9 made their first contribution in https://.../pull/1
///
///   **Full Changelog**: https://github.com/virgility9/arxivpanel/commits/v1.0.2
///
/// Showing that text verbatim means `##`, `*` and long raw URLs on screen.
/// [parseReleaseNotes] pulls it apart into sections, and [ReleaseNotesView]
/// renders each section as a clean list: `##` becomes a small gold caps
/// label, bullets get a gold dot, `.../pull/1` links become a tappable
/// "PR #1", `@user` gets the accent color, and the Full Changelog line
/// becomes one neat "View full changelog on GitHub" row instead of a
/// wrapped URL. No new dependency — links open with `url_launcher`,
/// supplied by the caller through [ReleaseNotesView.onOpenUrl].
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'shared.dart';

/// One `##` section of a release body: title + its bullet lines.
class ReleaseNoteSection {
  const ReleaseNoteSection({required this.title, required this.items});

  final String title;
  final List<String> items;
}

/// A parsed release body: sections in order, plus the Full Changelog URL
/// when the body carries one.
class ReleaseNotes {
  const ReleaseNotes({required this.sections, this.changelogUrl});

  final List<ReleaseNoteSection> sections;
  final String? changelogUrl;

  bool get isEmpty => sections.isEmpty && changelogUrl == null;
}

/// Pulls a GitHub-generated release body apart.
///
/// Lines starting with `##` open a new section; `* ` / `- ` lines are
/// items of the current section; any other non-empty line is kept as its
/// own item so hand-written notes still render instead of vanishing. The
/// `**Full Changelog**: <url>` footer is lifted out into [changelogUrl]
/// and dropped from the sections. Never throws — an unparseable body
/// simply yields no sections.
ReleaseNotes parseReleaseNotes(String raw) {
  final sections = <ReleaseNoteSection>[];
  String? changelogUrl;
  String? title;
  var items = <String>[];

  void flush() {
    if (items.isNotEmpty) {
      sections.add(ReleaseNoteSection(title: title ?? '', items: items));
      items = <String>[];
    }
    title = null;
  }

  for (final line in raw.split('\n')) {
    final text = line.trim();
    if (text.isEmpty) continue;
    // GitHub's auto-generated footer — lift the URL out, drop the line.
    if (text.startsWith('**Full Changelog**') ||
        text.startsWith('Full Changelog')) {
      changelogUrl ??= _firstUrl(text);
      continue;
    }
    if (text.startsWith('## ')) {
      flush();
      title = text.substring(3).trim();
      continue;
    }
    if (text.startsWith('# ')) {
      flush();
      title = text.substring(2).trim();
      continue;
    }
    if (text.startsWith('* ') || text.startsWith('- ')) {
      items.add(_cleanReleaseLine(text.substring(2)));
      continue;
    }
    items.add(_cleanReleaseLine(text));
  }
  flush();
  return ReleaseNotes(sections: sections, changelogUrl: changelogUrl);
}

String? _firstUrl(String text) {
  final match = RegExp(r'https?://[^\s)]+').firstMatch(text);
  return match?.group(0);
}

/// Trims a note line and collapses runs of whitespace. `**` markers and
/// URLs are left in place — the span builder below renders them.
String _cleanReleaseLine(String text) {
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Clean release-notes list, plus an optional Full Changelog row.
///
/// [onOpenUrl] opens a link externally (the caller owns `url_launcher`
/// and the failure toast). [showChangelog] hides the changelog row — the
/// update dialog passes false to keep the popup small.
class ReleaseNotesView extends StatelessWidget {
  const ReleaseNotesView({
    super.key,
    required this.palette,
    required this.notes,
    required this.version,
    required this.onOpenUrl,
    this.showChangelog = true,
    this.compact = false,
  });

  final AppPalette palette;
  final String notes;
  final String version;
  final Future<void> Function(String url) onOpenUrl;
  final bool showChangelog;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final c = p.c;
    final parsed = parseReleaseNotes(notes);
    if (parsed.isEmpty) {
      return Text(
        'No notes for this release.',
        style: bodyStyle(p, size: 14, color: c.muted),
      );
    }
    final sectionGap = compact ? 12.0 : 16.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < parsed.sections.length; i++) ...[
          if (i > 0) SizedBox(height: sectionGap),
          _section(p, parsed.sections[i]),
        ],
        if (showChangelog && parsed.changelogUrl != null) ...[
          SizedBox(height: compact ? 12 : 16),
          _changelogRow(p, parsed.changelogUrl!),
        ],
      ],
    );
  }

  Widget _section(AppPalette p, ReleaseNoteSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (section.title.isNotEmpty) ...[
          Text(
            section.title.toUpperCase(),
            style: monoStyle(
              p,
              size: 10,
              weight: FontWeight.w600,
              letterSpacing: 0.12,
              color: p.accent.accent,
            ),
          ),
          const SizedBox(height: 10),
        ],
        for (final item in section.items) _itemRow(p, item),
      ],
    );
  }

  Widget _itemRow(AppPalette p, String item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 7, right: 10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.accent.accent,
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: _itemSpans(p, item),
                style: bodyStyle(p, size: 14, color: p.c.textSub, height: 1.45),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Turns one note line into spans: `.../pull/1` becomes a tappable
  /// "PR #1", `**bold**` becomes bold, `@user` takes the accent color,
  /// and any other bare URL becomes a tappable "link".
  List<InlineSpan> _itemSpans(AppPalette p, String text) {
    final base = bodyStyle(p, size: 14, color: p.c.textSub, height: 1.45);
    final linkStyle = base.copyWith(
      color: p.accent.accent,
      fontWeight: FontWeight.w600,
    );
    final pattern = RegExp(
      r'(https://github\.com/[^\s]+/(?:pull|issues)/(\d+))'
      r'|(\*\*([^*]+)\*\*)'
      r'|(@[A-Za-z0-9][A-Za-z0-9_-]*)'
      r'|(https?://[^\s)]+)',
    );
    final spans = <InlineSpan>[];
    var pos = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > pos) {
        spans.add(TextSpan(text: text.substring(pos, match.start)));
      }
      final prUrl = match.group(1);
      final bold = match.group(4);
      final mention = match.group(5);
      final otherUrl = match.group(6);
      if (prUrl != null) {
        final number = match.group(2) ?? '';
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: () => onOpenUrl(prUrl),
              child: Text('PR #$number', style: linkStyle),
            ),
          ),
        );
      } else if (bold != null) {
        spans.add(
          TextSpan(
            text: bold,
            style: base.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      } else if (mention != null) {
        spans.add(TextSpan(text: mention, style: linkStyle));
      } else if (otherUrl != null) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: () => onOpenUrl(otherUrl),
              child: Text('link', style: linkStyle),
            ),
          ),
        );
      }
      pos = match.end;
    }
    if (pos < text.length) {
      spans.add(TextSpan(text: text.substring(pos)));
    }
    return spans;
  }

  /// One neat row for the Full Changelog link — no raw URL on screen.
  Widget _changelogRow(AppPalette p, String url) {
    final c = p.c;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onOpenUrl(url),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View full changelog on GitHub',
                        style: bodyStyle(p, size: 14, weight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'All commits in v$version',
                        style: bodyStyle(p, size: 12, color: c.muted),
                      ),
                    ],
                  ),
                ),
                Text('›', style: TextStyle(color: c.muted, fontSize: 20)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
