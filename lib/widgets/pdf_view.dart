/// Embedded PDF viewer dispatcher.
///
/// On web this exports the real iframe-based viewer; on every other
/// platform it exports a stub that renders nothing (the copy-link fallback
/// in the reader is used instead). The conditional import keeps web-only
/// libraries out of non-web builds.
library;

export 'pdf_view_stub.dart' if (dart.library.html) 'pdf_view_web.dart';
