/// PDF page-count detection for arxivpanel.
///
/// Counts pages straight from the PDF bytes — no plugins, no network, so it
/// works the moment a file is picked from the device.
library;

import 'dart:convert';
import 'dart:typed_data';

/// Returns the number of pages in [bytes], or 0 if it can't be determined.
///
/// Scans for page-object markers (`/Type /Page`, excluding the `/Pages`
/// page-tree node). This heuristic covers the overwhelming majority of PDFs
/// (Word / Google Docs / Chrome print exports keep page objects as plain
/// text). It returns 0 — rather than a wrong guess — for non-PDFs or fully
/// object-stream-compressed files.
int countPdfPages(Uint8List bytes) {
  if (bytes.length < 5) return 0;
  final head = latin1.decode(bytes.sublist(0, 5), allowInvalid: true);
  if (!head.startsWith('%PDF-')) return 0;
  final text = latin1.decode(bytes, allowInvalid: true);
  // `(?![\w])` keeps `/Type /Pages` (page-tree node) from being counted.
  return RegExp(r'/Type\s*/Page(?![\w])').allMatches(text).length;
}
