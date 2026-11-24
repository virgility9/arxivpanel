/// Runs an action once, [delay] after the last call — the typeahead
/// pattern: while the user is still typing, each keystroke restarts
/// the wait; the action fires only once they pause. Used by the
/// Browse search fields so a search goes out ~300ms after the user
/// stops typing instead of once per letter (or only on Enter).
library;

import 'dart:async';

class Debouncer {
  Debouncer([this.delay = const Duration(milliseconds: 300)]);

  final Duration delay;
  Timer? _timer;

  /// Schedules [action] after [delay]; a new call cancels the pending
  /// one, so only the last call in a burst runs.
  void call(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Drops a pending action without running it (Enter runs the search
  /// at once; clearing the field drops the queued search).
  void cancel() => _timer?.cancel();

  void dispose() => _timer?.cancel();
}
