/// Non-web fallback for [downloadFile]: opens the URL in the browser app,
/// which downloads it (Cloudinary `fl_attachment` URLs) or views it.
library;

import 'package:url_launcher/url_launcher.dart';

/// Opens [url] in the external browser; [filename] is unused off web.
Future<void> downloadFile(String url, String filename) async {
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
