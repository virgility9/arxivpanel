/// Blob URLs for picked files, behind a conditional import.
///
/// On web this creates a `blob:` URL for in-memory bytes (used for the
/// picked-PDF preview in the post screen); blob URLs don't exist off web,
/// so the stub throws if creation is ever called there — callers guard
/// with `kIsWeb`, exactly like `file_pick.dart`.
library;

import 'dart:typed_data';

import 'blob_url_stub.dart'
    if (dart.library.html) 'blob_url_web.dart' as impl;

/// Creates a `blob:` URL for [bytes] with the given MIME type (web only).
String createBlobUrl(Uint8List bytes, String mimeType) =>
    impl.createBlobUrl(bytes, mimeType);

/// Revokes a URL created by [createBlobUrl] (web only; no-op off web).
void revokeBlobUrl(String url) => impl.revokeBlobUrl(url);
