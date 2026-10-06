import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Jetpack's LogoutManager. The API answers `result: "999"` when the session is no longer valid.
/// Many requests can fail at the same moment → ONE event.
class SessionEvents {
  final _controller = StreamController<String>.broadcast();
  bool _handling = false;

  Stream<String> get expired => _controller.stream;

  /// Called by the network layer on result "999".
  void sessionExpired([String message = '']) {
    if (_handling) return;
    _handling = true;
    _controller.add(message);
  }

  /// Call once the user is on the login screen (or logged in again).
  void reset() => _handling = false;

  void dispose() => _controller.close();
}

final sessionEventsProvider = Provider<SessionEvents>((ref) {
  final e = SessionEvents();
  ref.onDispose(e.dispose);
  return e;
});