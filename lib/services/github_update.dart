/// Latest-release check against GitHub Releases (the OTA source of truth).
///
/// The release page is created with `scripts/release.ps1` after
/// `flutter build apk --release`. No key is needed: the public
/// releases API is unauthenticated (60 requests/hour per device IP,
/// and the app only checks once per launch plus a manual check from
/// Settings). Never throws — any failure returns null and the app
/// simply shows no update prompt.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

/// Fetches the latest GitHub release for virgil's repo and maps it to
/// [AppUpdateInfo]: version from the tag (`v1.0.1` -> `1.0.1`), notes
/// from the release body, download URL from the first `.apk` asset.
/// Returns null when there is no release yet, no APK asset is attached,
/// or the request fails.
Future<AppUpdateInfo?> fetchLatestGithubRelease() async {
  const url =
      'https://api.github.com/repos/virgility9/arxivpanel/releases/latest';
  try {
    final response = await http
        .get(
          Uri.parse(url),
          headers: {'Accept': 'application/vnd.github+json'},
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final tag = (data['tag_name'] as String? ?? '').trim();
    if (tag.isEmpty) return null;
    // Tags are `v1.0.1`; the version compare expects plain `1.0.1`.
    final version = tag.startsWith('v') ? tag.substring(1) : tag;
    String downloadUrl = '';
    final assets = data['assets'];
    if (assets is List) {
      for (final asset in assets) {
        if (asset is Map<String, dynamic>) {
          final name = (asset['name'] as String? ?? '').toLowerCase();
          final assetUrl = asset['browser_download_url'] as String? ?? '';
          if (name.endsWith('.apk') && assetUrl.isNotEmpty) {
            downloadUrl = assetUrl;
            break;
          }
        }
      }
    }
    if (downloadUrl.isEmpty) return null;
    final published = data['published_at'] as String? ?? '';
    return AppUpdateInfo(
      latestVersion: version,
      downloadUrl: downloadUrl,
      notes: (data['body'] as String? ?? '').trim(),
      updatedAt: DateTime.tryParse(published) ?? DateTime.now(),
    );
  } catch (_) {
    return null;
  }
}
