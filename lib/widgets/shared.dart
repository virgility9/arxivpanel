/// Shared building blocks used across screens, ported from the recurring
/// style fragments in the React components (buttons, chips, badges, fields,
/// avatars, formatters).
///
/// Typography note: the web app uses Fraunces (display serif), Outfit (body)
/// and DM Mono via Google Fonts. Flutter can't fetch those at runtime, so we
/// approximate with the platform generic families `'serif'` (display) and
/// `'monospace'` (mono labels), falling back to the default sans for body.
library;


import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/images.dart';
import 'app_logo_image.dart';
import 'motion.dart';

// ---------------------------------------------------------------------------
// Typography helpers
// ---------------------------------------------------------------------------

/// Font fallbacks. Flutter can't fetch web fonts at runtime, so each family
/// lists the best serif / mono available on every platform in priority order.
const List<String> kSerifFallback = [
  'Georgia',
  'Iowan Old Style',
  'Cambria',
  'Times New Roman',
  'Noto Serif',
];
const List<String> kMonoFallback = [
  'SF Mono',
  'Menlo',
  'Consolas',
  'Roboto Mono',
  'Courier New',
];

/// Approximates the Fraunces display serif.
TextStyle displayStyle(
  AppPalette p, {
  double size = 20,
  FontWeight weight = FontWeight.w600,
  Color? color,
  double? height,
  double letterSpacing = -0.02,
}) {
  final s = size * p.textScale;
  return TextStyle(
    fontFamily: 'serif',
    fontFamilyFallback: kSerifFallback,
    fontSize: s,
    fontWeight: weight,
    color: color ?? p.c.text,
    height: height,
    letterSpacing: s * letterSpacing,
  );
}

/// Approximates DM Mono for labels / metadata.
TextStyle monoStyle(
  AppPalette p, {
  double size = 10,
  FontWeight weight = FontWeight.w400,
  Color? color,
  double letterSpacing = 0.06,
  bool uppercase = false,
}) {
  return TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: kMonoFallback,
    fontSize: size * p.textScale,
    fontWeight: weight,
    color: color ?? p.c.muted,
    letterSpacing: letterSpacing,
  );
}

TextStyle bodyStyle(
  AppPalette p, {
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color? color,
  double? height,
}) {
  return TextStyle(
    fontSize: size * p.textScale,
    fontWeight: weight,
    color: color ?? p.c.text,
    height: height,
  );
}

// ---------------------------------------------------------------------------
// Formatters (mirroring the React helpers)
// ---------------------------------------------------------------------------

/// Like `Number.toLocaleString("en-US")`: 18420 -> "18,420".
String formatCount(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// Mirrors `timeAgo` in AdminPanel.tsx.
String timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  final mins = diff.inMinutes;
  if (mins < 1) return 'Just now';
  if (mins < 60) return '$mins min ago';
  final hours = diff.inHours;
  if (hours < 24) return '$hours hr ago';
  final days = diff.inDays;
  if (days < 30) return '$days day${days == 1 ? '' : 's'} ago';
  return formatShortDate(dt.toIso8601String().substring(0, 10));
}

/// "2024-11-12" -> "November 2024" (reader info box).
String formatMonthYear(String publishedAt) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  try {
    final dt = DateTime.parse(publishedAt);
    return '${months[dt.month - 1]} ${dt.year}';
  } catch (_) {
    return publishedAt;
  }
}

/// "2024-11-12" -> "Nov 12, 2024".
String formatShortDate(String publishedAt) {
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
  try {
    final dt = DateTime.parse(publishedAt);
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  } catch (_) {
    return publishedAt;
  }
}

// ---------------------------------------------------------------------------
// Images
// ---------------------------------------------------------------------------

/// Network image with a themed placeholder on error (covers & avatars).
class NetImage extends StatelessWidget {
  const NetImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.onError,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  /// Called when the image fails to load, so a caller can hide the
  /// image block instead of showing the broken-image placeholder box. Callers
  /// that ignore it keep the old placeholder behavior.
  final VoidCallback? onError;

  @override
  Widget build(BuildContext context) {
    // Decode at (about) display size, not full resolution: covers are
    // often 1200px+ but display at 130-360px, and decoding the full
    // bitmap on a phone wastes CPU and memory on every scroll. The
    // layout width is the real display width (cell width for cards,
    // full width for feed images). 2x headroom keeps the image sharp
    // on high-density screens. Thumbnails use BoxFit.contain: the
    // whole image shows, never stretched and never cut off — a
    // portrait book page in a wide frame letterboxes instead of
    // losing its top and bottom. (Avatars keep BoxFit.cover in their
    // own widget: a square crop of a face is what a circle wants.)
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final displayWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final cacheWidth = (displayWidth * dpr * 2).round();
        final cacheHeight = (height != null && height!.isFinite)
            ? (height! * dpr * 2).round()
            : null;
        final img = Image.network(
          url,
          width: width,
          height: height,
          fit: fit,
          filterQuality: FilterQuality.high,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
          // Loading placeholder so images don't pop in from blank.
          // Skeleton-style loading: a plain grey block while the image
          // loads, no spinner.
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            final surfaceColor =
                Theme.of(context).colorScheme.surfaceContainerHighest;
            return Container(
              width: width,
              height: height,
              color: surfaceColor,
            );
          },
          errorBuilder: (context, _, _) {
            // Tell the caller the image failed (post-frame: errorBuilder
            // can run during build, so a setState inside the callback
            // would throw). The placeholder is still returned, so callers
            // that ignore onError keep the old behavior.
            if (onError != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) => onError!());
            }
            final surfaceColor =
                Theme.of(context).colorScheme.surfaceContainerHighest;
            return Container(
              width: width,
              height: height,
              color: surfaceColor,
              child: const Center(
                  child: Icon(Icons.broken_image, size: 24)),
            );
          },
        );
        if (borderRadius != null) {
          return ClipRRect(borderRadius: borderRadius!, child: img);
        }
        return img;
      },
    );
  }
}

class AvatarImage extends StatefulWidget {
  const AvatarImage({
    super.key,
    required this.url,
    required this.size,
    this.borderColor,
    this.borderWidth = 0,
  });

  final String url;
  final double size;
  final Color? borderColor;
  final double borderWidth;

  @override
  State<AvatarImage> createState() => _AvatarImageState();
}

class _AvatarImageState extends State<AvatarImage> {
  // One image object per avatar URL, kept across rebuilds. The app
  // rebuilds on every AppState notify (tab change, like, bookmark...),
  // and the old code decoded the base64 data URL into a fresh
  // MemoryImage on every build — a new provider object is a cache miss
  // and a fresh decode, and Image drops the old picture while decoding
  // (gaplessPlayback defaults to false), so the avatar flashed blank
  // for a frame on every action. Holding the provider here means
  // rebuilds reuse the decoded image; gaplessPlayback covers the
  // actual photo-change case.
  late ImageProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = _providerFor(widget.url);
  }

  @override
  void didUpdateWidget(AvatarImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url) {
      _provider = _providerFor(widget.url);
    }
  }

  ImageProvider _providerFor(String url) {
    return isDataUrl(url)
        ? MemoryImage(dataUrlToBytes(url))
        : NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    final fallback = Container(
      color: surfaceColor,
      child: Center(
        child: Icon(
          Icons.person_outline,
          size: 20,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
    // Custom avatars are stored as inline data URLs (no Storage needed);
    // presets and legacy avatars are network URLs.
    // NOTE: the fallback is a Material icon, not an emoji — emoji glyphs
    // like 👤 are missing from Windows fonts and trigger Flutter's
    // "could not find a set of Noto fonts" warning.
    final Widget image = Image(
      image: _provider,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (context, _, _) => fallback,
    );
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: widget.borderWidth > 0
            ? Border.all(
                color: widget.borderColor ?? Colors.transparent,
                width: widget.borderWidth,
              )
            : null,
      ),
      child: ClipOval(child: image),
    );
  }
}

// ---------------------------------------------------------------------------
// Brand
// ---------------------------------------------------------------------------

/// The gold-book logo + "Arxiv" wordmark.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, required this.palette, this.fontSize = 20});

  final AppPalette palette;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppLogoImage(size: 28),
        const SizedBox(width: 8),
        Text(
          'Arxiv',
          style: displayStyle(
            palette,
            size: fontSize,
            weight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Buttons
// ---------------------------------------------------------------------------

/// Gold gradient primary button (mirrors `goldBtn` / `goldBtnStyle`).
class GoldButton extends StatelessWidget {
  const GoldButton({
    super.key,
    required this.palette,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.minHeight = 48,
  });

  final AppPalette palette;
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final a = palette.accent;
    final enabled = onPressed != null && !loading;
    // Compact buttons (e.g. the 32px header buttons) need tighter padding
    // and smaller text, otherwise the label gets vertically clipped.
    final compact = minHeight <= 36;
    final vPad = compact ? 6.0 : 12.0;
    final labelSize = compact ? 13.0 : 15.0;
    return PressScale(
      enabled: enabled,
      child: Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight),
        decoration: BoxDecoration(
          // Gentle vertical shading (not a glow) gives the button a pressed-
          // paper feel; the soft shadow keeps it grounded.
          gradient: enabled
              ? LinearGradient(
                  colors: [a.accent, a.accentDim],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
          color: enabled ? null : palette.c.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled
                ? Colors.white.withValues(alpha: 0.14)
                : palette.c.border,
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: a.accentDim.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: vPad),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading) ...[
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: palette.c.muted,
                      ),
                    ),
                    // The spinner sat flush against "Please wait…" with
                    // no gap — same 8px the icon branch already uses.
                    const SizedBox(width: 8),
                  ] else if (icon != null) ...[
                    Icon(
                      icon!,
                      size: 16,
                      color: enabled ? a.accentFg : palette.c.muted,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    loading ? 'Please wait…' : label,
                    style: TextStyle(
                      color: enabled ? a.accentFg : palette.c.muted,
                      fontSize: labelSize,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

/// Outlined ghost button (mirrors `outlineBtn` / `ghostBtnStyle`).
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.palette,
    this.label = '',
    required this.onPressed,
    this.icon,
    this.color,
    this.minHeight = 40,
  });

  final AppPalette palette;
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final c = palette.c;
    final fg = color ?? c.text;
    return PressScale(
      enabled: onPressed != null,
      child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        side: BorderSide(color: color ?? c.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: Size(0, minHeight),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon!, size: 16),
            if (label.isNotEmpty) const SizedBox(width: 6),
          ],
          if (label.isNotEmpty) Text(label),
        ],
      ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Labels, fields, chips
// ---------------------------------------------------------------------------

/// Uppercase mono section label (mirrors the `Section` component + labelStyle).
class SectionLabel extends StatelessWidget {
  const SectionLabel({super.key, required this.palette, required this.text});

  final AppPalette palette;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: monoStyle(
        palette,
        size: 10,
        weight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
    );
  }
}

/// Labeled form field wrapper with optional error text (mirrors FormField).
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.palette,
    required this.label,
    required this.child,
    this.error,
  });

  final AppPalette palette;
  final String label;
  final Widget child;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionLabel(palette: palette, text: label),
        const SizedBox(height: 8),
        child,
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(
            error!,
            style: TextStyle(color: palette.danger, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

/// Small mono hashtag chip (mirrors the tag chips in LibraryView).
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.palette,
    required this.tag,
    this.color,
  });

  final AppPalette palette;
  final String tag;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = palette.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border.all(color: c.borderFaint),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '#$tag',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: monoStyle(
          palette,
          size: 10,
          color: color ?? palette.accent.accent2,
        ),
      ),
    );
  }
}

/// Selectable pill chip (field filter / sort chips).
class SelectChip extends StatelessWidget {
  const SelectChip({
    super.key,
    required this.palette,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AppPalette palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = palette.c;
    final sel = palette.accent.accent;
    // Material + InkWell gives the ripple and tap semantics a bare
    // GestureDetector lacks; minHeight keeps a comfortable tap target.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? sel : c.surface,
            border: Border.all(color: selected ? sel : c.border),
            borderRadius: BorderRadius.circular(20),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: sel.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? palette.accent.accentFg : c.muted,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status / state widgets
// ---------------------------------------------------------------------------

/// Moderation status badge (mirrors `StatusBadge` in AdminPanel.tsx).
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.palette, required this.status});

  final AppPalette palette;
  final PaperStatus status;

  @override
  Widget build(BuildContext context) {
    final color = palette.statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.30)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Generic empty state (mirrors `EmptyState` in ProfilePage.tsx).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.palette,
    required this.icon,
    required this.title,
    required this.sub,
  });

  final AppPalette palette;
  final IconData icon;
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final c = palette.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: c.muted),
          const SizedBox(height: 14),
          Text(
            title,
            style: displayStyle(palette, size: 17, color: c.muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            sub,
            style: bodyStyle(palette, size: 13, color: c.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Error banner (mirrors the auth modal error box).
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final errColor = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: errColor.withValues(alpha: 0.1),
        border: Border.all(
          color: errColor.withValues(alpha: 0.28),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: TextStyle(color: errColor, fontSize: 12),
      ),
    );
  }
}

/// Comment composer: avatar + multi-line field + Post button. Shared by
/// the paper reader and the catalog detail screen (moved here from the
/// reader so both use the same composer). Posts only when the field is
/// non-empty; clears itself after posting.
class CommentComposer extends StatefulWidget {
  const CommentComposer({
    super.key,
    required this.palette,
    required this.user,
    required this.onPost,
    this.hintText = 'Share your thoughts…',
  });

  final AppPalette palette;
  final AppUser user;
  final ValueChanged<String> onPost;
  final String hintText;

  @override
  State<CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<CommentComposer> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final c = p.c;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AvatarImage(
          url: widget.user.avatar,
          size: 32,
          borderColor: c.border,
          borderWidth: 2,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TextField(
                controller: _ctrl,
                maxLines: 3,
                style: bodyStyle(p, size: 14),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              GoldButton(
                palette: p,
                label: 'Post',
                onPressed: _ctrl.text.trim().isEmpty
                    ? null
                    : () {
                        widget.onPost(_ctrl.text.trim());
                        _ctrl.clear();
                        setState(() {});
                      },
                minHeight: 40,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
