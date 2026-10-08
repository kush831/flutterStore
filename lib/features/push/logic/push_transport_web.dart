import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../../../core/config/app_env.dart';
import 'push_transport.dart';

PushTransport createTransport() => WebTransport();

class WebTransport implements PushTransport {
  JSObject? get _b => globalContext.getProperty<JSObject?>('storePush'.toJS);

  @override
  bool get supported => AppEnv.oneSignalAppId.isNotEmpty && _b != null;

  @override
  bool get askAtSignIn => false; // a browser needs a click for the permission dialog

  @override
  Future<void> init({required bool Function(IncomingPush) onForeground, required void Function(IncomingPush) onClick, required void Function(String id) onSubscriptionId}) async {
    IncomingPush read(Map<String, dynamic> m) => IncomingPush(m['data'] is Map ? m['data'] as Map : null, '${m['title'] ?? ''}', '${m['body'] ?? ''}');

    final callback = ((JSString kind, JSString json) {
      final m = jsonDecode(json.toDart) as Map<String, dynamic>;
      switch (kind.toDart) {
        case 'foreground':
          return onForeground(read(m)).toJS;
        case 'click':
          onClick(read(m));
        case 'subscription':
          onSubscriptionId('${m['id'] ?? ''}');
      }
      return false.toJS;
    }).toJS;
    _b?.callMethod<JSAny?>('init'.toJS, AppEnv.oneSignalAppId.toJS, callback);
  }

  Future<void> _call(String name, [JSAny? arg]) async {
    final b = _b;
    if (b == null) return;
    final r = arg == null ? b.callMethod<JSAny?>(name.toJS) : b.callMethod<JSAny?>(name.toJS, arg);
    if (r.isA<JSPromise>()) await (r as JSPromise).toDart;
  }

  bool _flag(String name) => _b?.callMethod<JSBoolean>(name.toJS).toDart ?? false;

  @override
  Future<void> login(String id) => _call('login', id.toJS);
  @override
  Future<void> logout() => _call('logout');
  @override
  Future<bool> requestPermission({bool fallbackToSettings = false}) async {
    await _call('requestPermission');
    return permission;
  }

  @override
  bool get permission => _flag('permission');
  @override
  bool get optedIn => _flag('optedIn');
  @override
  Future<void> optIn() => _call('optIn');
  @override
  Future<void> optOut() => _call('optOut');
}