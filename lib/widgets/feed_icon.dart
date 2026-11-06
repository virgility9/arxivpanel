/// Custom newspaper icon for the Feed tab.
///
/// Drawn as an alpha mask and embedded as base64 — the same pattern as the
/// tab icons in `app_icons.dart` (tinted with [ColorFiltered] so it can be
/// gold when selected and muted when not). It lives in its own file so
/// `app_icons.dart` stays under the push size cap; see
/// `~/workspace/feed-icon/make_icon.py` for the drawing script.
library;

import 'dart:convert';

import 'package:flutter/material.dart';

const _feedIconBase64 =
    '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';

class FeedIconImage extends StatelessWidget {
  const FeedIconImage({super.key, this.size = 24, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final image = Image.memory(
      base64Decode(_feedIconBase64),
      width: size,
      height: size,
      gaplessPlayback: true,
    );
    final tint = color;
    if (tint == null) return image;
    return ColorFiltered(
      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      child: image,
    );
  }
}
