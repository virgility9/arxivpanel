/// Embedded PDF viewer dispatcher.
///
/// On web this exports the real iframe-based viewer; on `dart:io`
/// platforms (Android/iOS) it exports the in-app pdfx viewer; on every
/// other platform it exports a stub that renders nothing. The conditional
/// import keeps web-only libraries out of non-web builds, and pdfx out
/// of the web build.
library;

export 'pdf_view_stub.dart'
    if (dart.library.html) 'pdf_view_web.dart'
    if (dart.library.io) 'pdf_view_mobile.dart';
