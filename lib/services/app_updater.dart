/// In-app APK updater (Android only, no new dependency).
///
/// Talks to MainActivity over the "arxiv/update" MethodChannel. The
/// native side downloads the APK with Android's DownloadManager, so
/// progress shows in the phone's notification shade, then launches
/// the system installer when the download finishes. On web (and any
/// non-Android platform) this returns "unsupported" and the caller
/// falls back to opening the link.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppUpdater {
  static const MethodChannel _channel = MethodChannel('arxiv/update');

  /// Starts the download + install flow. Returns "started",
  /// "already_downloading", "needs_unknown_sources", "unsupported", or
  /// "failed".
  static Future<String> downloadAndInstall({
    required String url,
    required String version,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return 'unsupported';
    }
    try {
      final result = await _channel.invokeMethod<String>(
        'downloadAndInstall',
        <String, String>{'url': url, 'version': version},
      );
      return result ?? 'failed';
    } on PlatformException {
      return 'failed';
    } on MissingPluginException {
      return 'failed';
    }
  }
}
