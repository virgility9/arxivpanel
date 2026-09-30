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

// ---------------------------------------------------------------------------
// Typography helpers
// ---------------------------------------------------------------------------

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

/// Compact form for tight spaces: 18420 -> "18.4k".
String formatCompact(int n) {
  if (n >= 1000) {
    final v = n / 1000;
    final s = v >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    return '${s}k';
  }
  return n.toString();
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
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
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
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final img = Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      // Loading placeholder so images don't pop in from blank.
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          width: width,
          height: height,
          color: const Color(0xFF1C1C2A),
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
      errorBuilder: (context, _, _) => Container(
        width: width,
        height: height,
        color: const Color(0xFF1C1C2A),
        child: const Center(child: Text('📄', style: TextStyle(fontSize: 24))),
      ),
    );
    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: img);
    }
    return img;
  }
}

class AvatarImage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: borderWidth > 0
            ? Border.all(
                color: borderColor ?? Colors.transparent,
                width: borderWidth,
              )
            : null,
      ),
      child: ClipOval(
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, _, _) => Container(
            color: const Color(0xFF2A2A3A),
            child: const Center(
              child: Text('👤', style: TextStyle(fontSize: 16)),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Brand
// ---------------------------------------------------------------------------

/// The Σ mark + "ArxivPanel" wordmark from Navbar.tsx.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, required this.palette, this.fontSize = 20});

  final AppPalette palette;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final a = palette.accent;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [a.accent, a.accentDim],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            'Σ',
            style: TextStyle(
              color: a.accentFg,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        RichText(
          text: TextSpan(
            style: displayStyle(
              palette,
              size: fontSize,
              weight: FontWeight.w600,
            ),
            children: [
              const TextSpan(text: 'Arxiv'),
              TextSpan(
                text: 'Panel',
                style: TextStyle(color: a.accent),
              ),
            ],
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
  final String? icon;
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
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight),
        decoration: BoxDecoration(
          gradient: enabled
              ? LinearGradient(
                  colors: [a.accent, a.accentDim],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: enabled ? null : palette.c.surface2,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: vPad),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: palette.c.muted,
                      ),
                    )
                  else if (icon != null) ...[
                    Text(icon!, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    loading ? 'Please wait…' : label,
                    style: TextStyle(
                      color: enabled ? a.accentFg : palette.c.muted,
                      fontSize: labelSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
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
    required this.label,
    required this.onPressed,
    this.color,
    this.minHeight = 40,
  });

  final AppPalette palette;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final c = palette.c;
    final fg = color ?? c.text;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        side: BorderSide(color: color ?? c.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        minimumSize: Size(0, minHeight),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      child: Text(label),
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
            style: const TextStyle(color: Color(0xFFE06B6B), fontSize: 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        '#$tag',
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
    this.selectedColor,
  });

  final AppPalette palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? selectedColor;

  @override
  Widget build(BuildContext context) {
    final c = palette.c;
    final sel = selectedColor ?? palette.accent.accent;
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
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? palette.accent.accentFg : c.muted,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
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

  Color get _color {
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

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
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
  final String icon;
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
          Text(icon, style: const TextStyle(fontSize: 40)),
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

/// Small icon + value + label stat tile (mirrors ProfilePage stats grid).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.palette,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final AppPalette palette;
  final String icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = palette.c;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(
            value,
            style: displayStyle(
              palette,
              size: 22,
              weight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: monoStyle(palette, size: 9, letterSpacing: 0.1),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE06B6B).withValues(alpha: 0.1),
        border: Border.all(
          color: const Color(0xFFE06B6B).withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFFE06B6B), fontSize: 12),
      ),
    );
  }
}
