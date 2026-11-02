/// Non-web stub for blob URLs (see `blob_url.dart`).
///
/// Blob URLs don't exist off web; callers guard with `kIsWeb`, so these
/// are never called on Android/desktop. `createBlobUrl` throws to surface
/// a programming error; `revokeBlobUrl` is a harmless no-op.
library;

import 'dart:typed_data';

String createBlobUrl(Uint8List bytes, String mimeType) =>
    throw UnimplementedError('Blob URLs are only available on web.');

void revokeBlobUrl(String url) {}
