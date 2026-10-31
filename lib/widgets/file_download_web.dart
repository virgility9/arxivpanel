/// Web implementation of [downloadFile].
///
/// Triggers a browser download via a temporary anchor element, so the file
/// saves instead of opening a new tab. Used with Cloudinary `fl_attachment`
/// URLs, which already carry a Content-Disposition: attachment header.
library;

import 'package:web/web.dart' as web;

/// Downloads [url] to the user's device, suggesting [filename].
Future<void> downloadFile(String url, String filename) async {
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}
