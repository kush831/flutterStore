import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/session_events.dart'; // grep -rn "final sessionEventsProvider" lib   if the path differs
import '../../../core/router/app_router.dart';
import '../../../core/router/routes.dart';
import '../../../core/storage/storage_providers.dart';
import '../../home/logic/dashboard_controller.dart';
import '../../orders/logic/orders_controller.dart';
import '../../splash/logic/config_controller.dart';
import '../data/push_event.dart';
import 'order_alarm.dart';
import 'push_transport.dart';

/// The new-order banner at the top of the screen (null = hidden).
class PushBanner extends Notifier<PushEvent?> {
  @override
  PushEvent? build() => null;

  void show(PushEvent e) => state = e;
  void hide() => state = null;
}

final pushBannerProvider = NotifierProvider<PushBanner, PushEvent?>(PushBanner.new);

final pushTransportProvider = Provider<PushTransport>((ref) => createPushTransport());

class PushService {
  PushService(this._ref);

  final Ref _ref;
  bool _started = false;
  bool _listening = false;
  String? _pending; // a tap that arrived before the app finished starting

  PushTransport get _t => _ref.read(pushTransportProvider);
  OrderAlarm get _alarm => _ref.read(orderAlarmProvider);

  Future<void> init() async {
    if (!_listening) {
      _listening = true;
      // the native alarm needs the flag even when only the background service runs
      _ref.listen<bool>(appConfigProvider.select((c) => c?.orderNotificationNonStop ?? false), (_, on) => _alarm.setNonStop(on), fireImmediately: true);
    }
    if (_started || !_t.supported) return;
    _started = true;

    await _t.init(onForeground: _onForeground, onClick: _onClick, onSubscriptionId: _saveId);
    // a tap on a system notification can arrive while the app is still on the splash screen
    _ref.read(routerProvider).routerDelegate.addListener(_flushPending);

    // the store was already signed in when the app started: the listener in app.dart only sees later changes
    if (_ref.read(authControllerProvider).loggedIn) {
      await onSignedIn(_ref.read(appPrefsProvider).businessSegmentId);
    }
  }
  void _saveId(String id) {
    debugPrint('PUSH subscription id: $id');
    if (id.isNotEmpty) _ref.read(appPrefsProvider).savePlayerId(id); // the next login sends it as player_id
  }

  Future<void> onSignedIn(String storeId) async {
    if (!_t.supported) return;
    if (storeId.isNotEmpty && storeId != 'null') await _t.login(storeId);
    if (_t.askAtSignIn) await _t.requestPermission(); // the browser asks from the Settings switch instead
  }

  Future<void> onSignedOut() async {
    _ref.read(pushBannerProvider.notifier).hide();
    await _alarm.stop();
    if (_t.supported) await _t.logout();
  }

  // ── a push arrives while the app is open. Returns true to hide the system notification. ──

  bool _onForeground(IncomingPush p) {
    final e = PushEvent.fromData(p.data, title: p.title, body: p.body);
    switch (e.type) {
      case PushType.logout:
        _ref.read(sessionEventsProvider).sessionExpired(e.body); // signs out; the login screen shows the message
        return true;
      case PushType.openCloseStore:
        final dash = _ref.read(dashboardProvider.notifier);
        switch (e.isOpen) {
          case '1':
            dash.applyRemoteStoreStatus(true);
          case '2':
            dash.applyRemoteStoreStatus(false);
          default:
            dash.refresh();
        }
        return true;
      case PushType.newOrder:
      case PushType.upcomingOrder:
        _refreshData();
        _ref.read(pushBannerProvider.notifier).show(e); // our banner replaces the system notification
        if (_ref.read(appConfigProvider)?.orderNotificationNonStop ?? false) {
          _alarm.start(e.orderId); // loops until View, X or accept
        } else {
          _alarm.ring(); // one ring with new_order.wav
          HapticFeedback.heavyImpact();
        }
        return true;
      case PushType.orderExpired:
        _alarm.stop(e.orderId);
        _ref.read(pushBannerProvider.notifier).hide();
        _refreshData();
        return false; // the system shows the notification itself
      case PushType.orderAccepted:
      case PushType.orderDelivered:
      case PushType.orderCompleted:
      case PushType.orderCancelled:
      case PushType.walletUpdate:
      case PushType.chat:
        _refreshData();
        return false;
      case PushType.other:
        return true; // as Jetpack: ON_THE_WAY, SIGNUP_APPROVED, PICKUP_VERIFICATION and unknown ones stay silent
    }
  }

  void _refreshData() {
    _ref.invalidate(ordersProvider);
    _ref.read(dashboardProvider.notifier).refresh();
  }

  // ── a tap on a system notification ──

  void _onClick(IncomingPush p) {
    final e = PushEvent.fromData(p.data, title: p.title, body: p.body);
    if (e.type == PushType.logout) {
      _ref.read(sessionEventsProvider).sessionExpired(e.body);
      return;
    }
    open(e);
  }

  /// Opens what the push is about, and stops its alarm.
  void open(PushEvent e) {
    if (e.isNewOrder || e.type == PushType.orderExpired) _alarm.stop(e.orderId);
    _ref.read(pushBannerProvider.notifier).hide();
    final path = pushRoute(e);
    if (path == null) return;
    if (_onSplash) {
      _pending = path; // go there when the app has started
      return;
    }
    _go(path);
  }

  bool get _onSplash => _ref.read(routerProvider).routerDelegate.currentConfiguration.uri.path == Routes.splash;

  void _flushPending() {
    final p = _pending;
    if (p == null || _onSplash) return;
    _pending = null;
    Future.microtask(() => _go(p)); // not inside the router's own notification
  }

  void _go(String path) {
    final router = _ref.read(routerProvider);
    path.startsWith('${Routes.orders}/') ? router.push(path) : router.go(path); // an order opens on top of where you were
  }
}

final pushServiceProvider = Provider<PushService>((ref) => PushService(ref));

/// The Settings switch: notifications are on when the permission is given and the subscription is on.
class PushEnabled extends Notifier<bool> {
  PushTransport get _t => ref.read(pushTransportProvider);

  @override
  bool build() => _t.supported && _t.permission && _t.optedIn;

  Future<void> set(bool on) async {
    if (!_t.supported) return;
    if (!on) {
      await _t.optOut();
      state = false;
      return;
    }
    var allowed = _t.permission;
    if (!allowed) allowed = await _t.requestPermission(fallbackToSettings: true); // refused before: open the system settings
    if (allowed) {
      await _t.optIn();
      state = true;
    }
  }
}

final pushEnabledProvider = NotifierProvider.autoDispose<PushEnabled, bool>(PushEnabled.new);