import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../../../core/config/app_env.dart';
import 'push_transport.dart';

PushTransport createTransport() => MobileTransport();

class MobileTransport implements PushTransport {
  @override
  bool get supported => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) && AppEnv.oneSignalAppId.isNotEmpty;

  @override
  bool get askAtSignIn => true;

  @override
  Future<void> init({required bool Function(IncomingPush) onForeground, required void Function(IncomingPush) onClick, required void Function(String id) onSubscriptionId}) async {
    OneSignal.initialize(AppEnv.oneSignalAppId);
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      final n = event.notification;
      if (onForeground(IncomingPush(n.additionalData, n.title ?? '', n.body ?? ''))) event.preventDefault();
    });
    OneSignal.Notifications.addClickListener((event) {
      final n = event.notification;
      onClick(IncomingPush(n.additionalData, n.title ?? '', n.body ?? ''));
    });
    OneSignal.User.pushSubscription.addObserver((s) => onSubscriptionId(s.current.id ?? ''));
    onSubscriptionId(OneSignal.User.pushSubscription.id ?? '');
  }

  @override
  Future<void> login(String id) => OneSignal.login(id);
  @override
  Future<void> logout() => OneSignal.logout();
  @override
  Future<bool> requestPermission({bool fallbackToSettings = false}) => OneSignal.Notifications.requestPermission(fallbackToSettings);
  @override
  bool get permission => OneSignal.Notifications.permission;
  @override
  bool get optedIn => OneSignal.User.pushSubscription.optedIn ?? false;
  @override
  Future<void> optIn() => OneSignal.User.pushSubscription.optIn();
  @override
  Future<void> optOut() => OneSignal.User.pushSubscription.optOut();
}