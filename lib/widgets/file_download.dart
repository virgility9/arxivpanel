/// File download dispatcher.
///
/// On web this exports the anchor-click implementation; on every other
/// platform it exports the url_launcher fallback (same conditional-export
/// pattern as `pdf_view.dart`).
library;

export 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart';
