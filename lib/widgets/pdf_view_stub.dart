/// Fallback for the embedded PDF viewer on platforms with neither
/// `dart:html` nor `dart:io`.
///
/// `buildPdfView` mirrors the real implementations' signature so the reader
/// screen can call it unconditionally; it renders nothing. In practice
/// every current target (web, Android, iOS, desktop) takes one of the
/// real branches.
library;

import 'package:flutter/material.dart';

Widget buildPdfView(String url) => const SizedBox.shrink();
