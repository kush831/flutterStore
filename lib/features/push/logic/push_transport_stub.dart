import 'push_transport.dart';

PushTransport createTransport() => _Off();

class _Off implements PushTransport {
  @override
  bool get supported => false;
  @override
  bool get askAtSignIn => false;
  @override
  Future<void> init({required bool Function(IncomingPush) onForeground, required void Function(IncomingPush) onClick, required void Function(String id) onSubscriptionId}) async {}
  @override
  Future<void> login(String id) async {}
  @override
  Future<void> logout() async {}
  @override
  Future<bool> requestPermission({bool fallbackToSettings = false}) async => false;
  @override
  bool get permission => false;
  @override
  bool get optedIn => false;
  @override
  Future<void> optIn() async {}
  @override
  Future<void> optOut() async {}
}