/// Web-only file picking implementation for `file_pick.dart`.
///
/// Only ever imported on web (see the conditional import in
/// `file_pick.dart`). Drives a hidden `<input type="file">` directly through
/// `package:web` (no plugin registration involved).
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'file_pick.dart';

/// Web implementation: hidden `<input type="file">` + FileReader.
///
/// The input must stay attached to the document for the `change` event to
/// fire (WebKit drops events for detached inputs). Cancellation is detected
/// via the input's `cancel` event (Chromium) with a window `focus` fallback
/// for browsers without it.
Future<PickedFile?> pickWebFile(PickKind kind) {
  final completer = Completer<PickedFile?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = kind == PickKind.image ? 'image/*' : '.pdf,application/pdf'
    ..style.display = 'none';

  var done = false;

  // The JS listener wrappers are declared up-front (assigned below) so the
  // control functions defined next can reference them.
  late JSFunction changeJs;
  late JSFunction cancelJs;
  late JSFunction focusJs;

  void cleanup() {
    input.removeEventListener('change', changeJs);
    input.removeEventListener('cancel', cancelJs);
    web.window.removeEventListener('focus', focusJs);
    input.remove();
  }

  void finish(PickedFile? result) {
    if (done) return;
    done = true;
    cleanup();
    completer.complete(result);
  }

  void onChange(web.Event _) {
    if (done) return;
    // A selection was made — mark done synchronously so the focus event
    // firing right after can't cancel the in-flight FileReader read.
    done = true;
    try {
      final files = input.files;
      final file = files != null && files.length > 0 ? files.item(0) : null;
      if (file == null || file.name.isEmpty) {
        cleanup();
        completer.complete(null);
        return;
      }
      final reader = web.FileReader();
      reader.addEventListener(
        'loadend',
        ((web.Event _) {
          try {
            final byteBuffer = (reader.result as JSArrayBuffer?)?.toDart;
            cleanup();
            completer.complete(
              byteBuffer == null
                  ? null
                  : PickedFile(
                      bytes: byteBuffer.asUint8List(),
                      name: file.name,
                    ),
            );
          } catch (_) {
            cleanup();
            completer.complete(null);
          }
        }).toJS,
      );
      reader.addEventListener(
        'error',
        ((web.Event _) {
          cleanup();
          completer.complete(null);
        }).toJS,
      );
      reader.readAsArrayBuffer(file);
    } catch (_) {
      cleanup();
      completer.complete(null);
    }
  }

  changeJs = onChange.toJS;
  cancelJs = ((web.Event _) => finish(null)).toJS;
  focusJs = ((web.Event _) {
    // Fires when the dialog closes without a selection AND on unrelated
    // refocuses; the delay + `done` guard keep it from racing `change`.
    Future.delayed(const Duration(milliseconds: 600), () => finish(null));
  }).toJS;

  input.addEventListener('change', changeJs);
  input.addEventListener('cancel', cancelJs);
  web.window.addEventListener('focus', focusJs);

  web.document.body!.append(input);
  input.click();
  return completer.future;
}
