/// Image helpers: avatar data URLs (no Firebase Storage needed).
///
/// Custom avatars are downscaled to a small JPEG and stored inline in the
/// Firestore user document as a `data:image/jpeg;base64,…` URL, so profile
/// pictures work without the Blaze plan.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Downscales [bytes] so its longest side is 256px and returns it as a
/// `data:image/jpeg;base64,…` URL (typically 20–50 KB — well under the
/// Firestore 1 MB document limit). The whole photo is kept — no cropping —
/// so faces stay recognizable: the old center-square crop cut the top and
/// bottom off portrait photos (and the sides off landscape ones). Small
/// photos are left alone, never upscaled.
String avatarToDataUrl(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw StateError('Could not decode image');
  }
  // Scale proportionally (one dimension given = the other follows the
  // aspect ratio); a photo already at or under 256px stays untouched.
  final resized = decoded.width >= decoded.height
      ? (decoded.width > 256
          ? img.copyResize(decoded, width: 256)
          : decoded)
      : (decoded.height > 256
          ? img.copyResize(decoded, height: 256)
          : decoded);
  final jpg = img.encodeJpg(resized, quality: 82);
  return 'data:image/jpeg;base64,${base64Encode(jpg)}';
}

/// True when [url] is an inline data URL rather than a network URL.
bool isDataUrl(String url) => url.startsWith('data:');

/// Decodes the payload of a `data:…;base64,…` URL.
Uint8List dataUrlToBytes(String url) {
  final comma = url.indexOf(',');
  if (comma < 0) throw StateError('Not a data URL');
  return base64Decode(url.substring(comma + 1));
}
