import 'push_transport_stub.dart'
if (dart.library.io) 'push_transport_mobile.dart'
if (dart.library.js_interop) 'push_transport_web.dart';

/// A push as the shared code sees it, whatever platform it came from.
class IncomingPush {
  const IncomingPush(this.data, this.title, this.body);

  final Map<dynamic, dynamic>? data;
  final String title;
  final String body;
}

abstract class PushTransport {
  bool get supported;

  /// Browsers only allow the permission dialog after a click, so the web asks from the Settings switch instead of at sign-in.
  bool get askAtSignIn;

  /// [onForeground] returns true to hide the system notification. [onClick] is a tap on a notification.
  Future<void> init({
    required bool Function(IncomingPush) onForeground,
    required void Function(IncomingPush) onClick,
    required void Function(String id) onSubscriptionId,
  });
  Future<void> login(String id);
  Future<void> logout();
  Future<bool> requestPermission({bool fallbackToSettings = false});
  bool get permission;
  bool get optedIn;
  Future<void> optIn();
  Future<void> optOut();
}

PushTransport createPushTransport() => createTransport();