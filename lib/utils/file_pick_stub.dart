/// Non-web stub for the web file picker (see the conditional import in
/// `file_pick.dart`). Never called: `pickSingleFile` only routes here on
/// web, where the real implementation is used instead.
library;

import 'file_pick.dart';

/// Throws: there is no web file picker off web.
Future<PickedFile?> pickWebFile(PickKind kind) {
  throw UnimplementedError('pickWebFile is only available on web');
}
