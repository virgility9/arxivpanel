/// Shared motion helpers: screen and tab transitions.
///
/// Built only from core Flutter widgets (no packages). Every helper
/// collapses to "no animation" when the OS asks to reduce motion
/// ([MediaQueryData.disableAnimations]).
library;

import 'package:flutter/material.dart';

/// Whether motion should be skipped (OS "reduce motion" / "remove animations").
bool motionReduced(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// Cross-fades between [child]s with a subtle upward slide on the incoming
/// one. Give [child] a distinct `key` whenever the content changes.
///
/// The stack fills the available space ([expand]) so screens that rely on
/// tight constraints (e.g. inside an `Expanded`) lay out exactly as before.
class MotionSwitcher extends StatelessWidget {
  const MotionSwitcher({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 240),
    this.slide = true,
    this.slideOffset = const Offset(0, 0.02),
    this.expand = false,
  });

  final Widget child;
  final Duration duration;
  final bool slide;
  final Offset slideOffset;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: motionReduced(context) ? Duration.zero : duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        fit: expand ? StackFit.expand : StackFit.loose,
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) {
        final faded = FadeTransition(opacity: animation, child: child);
        if (!slide) return faded;
        return SlideTransition(
          position: Tween<Offset>(
            begin: slideOffset,
            end: Offset.zero,
          ).animate(animation),
          child: faded,
        );
      },
      child: child,
    );
  }
}

/// Lightweight press feedback: scales [child] to 0.97 while a pointer is
/// down, springing back on release (100ms, like a physical button).
/// Visual only — it never owns the tap, so it composes with the
/// GestureDetector / InkWell inside (cards, feed items, buttons).
/// A scroll drag cancels the press, so lists don't shrink while
/// scrolling; pass [enabled] false for disabled buttons.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
    this.scale = 0.97,
    this.duration = const Duration(milliseconds: 100),
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final double scale;
  final Duration duration;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: widget.duration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Toggle-icon pop: when [active] flips, the new icon bounces
/// 1.0 → 1.25 → 1.0 while fading in, so the color swap reads as a pop.
/// Stateless — [AnimatedSwitcher] does the work, keyed on [active] so
/// the switcher treats the two states as different children.
class PopIcon extends StatelessWidget {
  const PopIcon({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        final scale = TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween(begin: 1.0, end: 1.25),
            weight: 40,
          ),
          TweenSequenceItem(
            tween: Tween(begin: 1.25, end: 1.0),
            weight: 60,
          ),
        ]).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
      child: KeyedSubtree(key: ValueKey(active), child: child),
    );
  }
}

/// Gold shimmer sweep, reusing the splash screen's exact shader logic
/// (1.6s loop, white band at 0.45 alpha sweeping left to right).
/// Wrap placeholder cards in it while Firestore fetches land.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (motionReduced(context)) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Same highlight band as the splash logo.
        final center = -2.0 + 4.0 * _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(center - 1, 0),
            end: Alignment(center + 1, 0),
            colors: [
              Colors.transparent,
              Colors.white.withValues(alpha: 0.45),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(bounds),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A number that glides from its previous value to [value] instead of
/// snapping. Used for stats counters (profile) and result counts.
class AnimatedCount extends StatefulWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    this.format,
    this.style,
    this.duration = const Duration(milliseconds: 400),
  });

  final int value;
  final String Function(int value)? format;
  final TextStyle? style;
  final Duration duration;

  @override
  State<AnimatedCount> createState() => _AnimatedCountState();
}

class _AnimatedCountState extends State<AnimatedCount> {
  late IntTween _tween;

  @override
  void initState() {
    super.initState();
    _tween = IntTween(begin: 0, end: widget.value);
  }

  @override
  void didUpdateWidget(AnimatedCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _tween = IntTween(begin: oldWidget.value, end: widget.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: _tween,
      duration: motionReduced(context) ? Duration.zero : widget.duration,
      builder: (context, value, _) => Text(
        widget.format?.call(value) ?? '$value',
        style: widget.style,
      ),
    );
  }
}
