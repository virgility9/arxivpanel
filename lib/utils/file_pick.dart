/// Single-file picking with bytes.
///
/// On web this drives a hidden `<input type="file">` directly through
/// `package:web` (no plugin registration involved); on other platforms it
/// delegates to `file_picker`. Returns null when the user cancels.
///
/// The web implementation lives behind a conditional import, so Android
/// (and other non-web) builds never compile `dart:js_interop` or
/// `package:web` — importing those unconditionally broke `assembleDebug`
/// with "'JSObject' isn't a type" errors from inside `package:web`.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/foundation.dart';

import 'file_pick_stub.dart'
    if (dart.library.html) 'file_pick_web.dart' as web_impl;

/// What kind of file to pick.
enum PickKind {
  image,
  pdf,
}

/// A picked file: its bytes and original file name.
class PickedFile {
  const PickedFile({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;

  /// Lowercase extension without the dot (`jpg`, `png`, `pdf`, …).
  String get extension {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }
}

/// Compact single-line rendering of an error for toasts.
String shortError(Object e) {
  final s = e.toString().replaceAll(RegExp(r'\s+'), ' ');
  return s.length > 90 ? '${s.substring(0, 90)}…' : s;
}

/// Picks a single file and reads its bytes. Null = the user cancelled.
Future<PickedFile?> pickSingleFile(PickKind kind) async {
  if (kIsWeb) return web_impl.pickWebFile(kind);
  final file = await fp.FilePicker.pickFile(
    type: kind == PickKind.image ? fp.FileType.image : fp.FileType.custom,
    allowedExtensions: kind == PickKind.pdf ? const ['pdf'] : null,
  );
  if (file == null) return null;
  return PickedFile(bytes: await file.readAsBytes(), name: file.name);
}
