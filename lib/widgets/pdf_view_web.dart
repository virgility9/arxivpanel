/// Web implementation of the embedded PDF viewer.
///
/// Renders the paper's PDF URL in an <iframe> via [HtmlElementView], so
/// Chrome's built-in PDF viewer handles rendering. Only ever imported on
/// web (see `pdf_view.dart`). Uses `package:web` instead of the deprecated
/// `dart:html`.
library;

import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

int _pdfViewCounter = 0;

/// Returns a widget embedding [url] in an iframe. Each call registers a
/// unique view type so revisiting the tab (or opening another paper) never
/// collides with a previous registration.
Widget buildPdfView(String url) {
  final viewType = 'arxivpanel-pdf-${_pdfViewCounter++}';
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final iframe = web.HTMLIFrameElement()
      ..src = url
      ..title = 'Paper PDF';
    iframe.style
      ..border = 'none'
      ..width = '100%'
      ..height = '100%';
    return iframe;
  });
  return HtmlElementView(viewType: viewType);
}
