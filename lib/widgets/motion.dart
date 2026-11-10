/// Shared motion helpers: screen/tab transitions and list entrance effects.
///
/// Built only from core Flutter widgets (no packages). Every helper
/// collapses to "no animation" when the OS asks to reduce motion
/// ([MediaQueryData.disableAnimations]).
library;

import 'dart:math' as math;

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
    this.expand = false,
  });

  final Widget child;
  final Duration duration;
  final bool slide;
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
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(animation),
          child: faded,
        );
      },
      child: child,
    );
  }
}

/// Fades and slides [child] in once when it first appears. [index] staggers
/// siblings in a list (capped so long lists don't wait forever).
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (motionReduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + math.min(index, 6) * 60),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 14), child: child),
      ),
      child: child,
    );
  }
}
