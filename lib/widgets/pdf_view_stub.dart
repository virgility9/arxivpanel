/// Non-web stub for the embedded PDF viewer.
///
/// `buildPdfView` mirrors the web implementation's signature so the reader
/// screen can call it unconditionally; on mobile/desktop it renders nothing
/// and the reader falls back to the copy-link card.
library;

import 'package:flutter/material.dart';

Widget buildPdfView(String url) => const SizedBox.shrink();
