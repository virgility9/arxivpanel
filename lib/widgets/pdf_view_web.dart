/// Web implementation of the embedded PDF viewer.
///
/// Renders the paper's PDF URL in an <iframe> via [HtmlElementView], so
/// Chrome's built-in PDF viewer handles rendering. Only ever imported on
/// web (see `pdf_view.dart`).
library;

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

int _pdfViewCounter = 0;

/// Returns a widget embedding [url] in an iframe. Each call registers a
/// unique view type so revisiting the tab (or opening another paper) never
/// collides with a previous registration.
Widget buildPdfView(String url) {
  final viewType = 'arxivpanel-pdf-${_pdfViewCounter++}';
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    return html.IFrameElement()
      ..src = url
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..title = 'Paper PDF';
  });
  return HtmlElementView(viewType: viewType);
}
