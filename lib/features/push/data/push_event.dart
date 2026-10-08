import 'dart:convert';

import '../../../core/router/routes.dart';

enum PushType { newOrder, upcomingOrder, orderAccepted, orderDelivered, orderCompleted, orderCancelled, orderExpired, openCloseStore, logout, walletUpdate, chat, other }

PushType pushTypeOf(String raw) => switch (raw.trim().toUpperCase()) {
  'ORDER_PLACED' => PushType.newOrder,
  'UPCOMING_ORDER_PLACED' => PushType.upcomingOrder,
  'ORDER_ACCEPTED' => PushType.orderAccepted,
  'ORDER_DELIVERED' => PushType.orderDelivered,
  'ORDER_COMPLETED' => PushType.orderCompleted,
  'ORDER_CANCELLED' => PushType.orderCancelled,
  'ORDER_AUTO_EXPIRED' => PushType.orderExpired,
  'OPEN_CLOSE_STORE' => PushType.openCloseStore,
  'LOGOUT' => PushType.logout,
  'WALLET_UPDATE' => PushType.walletUpdate,
  'CHAT_STORE_USER' => PushType.chat,
  _ => PushType.other,
};

String _text(Object? v) {
  final s = v == null ? '' : '$v'.trim();
  return s == 'null' ? '' : s;
}

class PushEvent {
  const PushEvent({required this.type, this.rawType = '', this.orderId = '', this.orderNo = '', this.isOpen = '', this.title = '', this.body = ''});

  final PushType type;
  final String rawType;
  final String orderId;
  final String orderNo;
  final String isOpen; // "1" open · "2" closed
  final String title;
  final String body;

  bool get isNewOrder => type == PushType.newOrder || type == PushType.upcomingOrder;

  /// The additional data of a push. The order id is inside `segment_data` (an object or a JSON text);
  /// when it is missing there, the top-level `order_id` is used (Jetpack lost it in that case).
  factory PushEvent.fromData(Map<dynamic, dynamic>? data, {String title = '', String body = ''}) {
    final d = data ?? const {};
    var seg = const <dynamic, dynamic>{};
    final raw = d['segment_data'];
    if (raw is Map) {
      seg = raw;
    } else if (raw is String && raw.trim().startsWith('{')) {
      try {
        final j = jsonDecode(raw);
        if (j is Map) seg = j;
      } catch (_) {}
    }
    final fromSeg = _text(seg['order_id']);
    final rawType = _text(d['notification_type']);
    return PushEvent(
      type: pushTypeOf(rawType),
      rawType: rawType,
      orderId: fromSeg.isNotEmpty ? fromSeg : _text(d['order_id']),
      orderNo: _text(d['order_number']),
      isOpen: _text(d['is_open']),
      title: title,
      body: body,
    );
  }

  /// What the native notification puts in the deep link: apporiostore://app/push?type=…&order_id=…
  factory PushEvent.fromUri(Uri u) {
    final q = u.queryParameters;
    final rawType = _text(q['type']);
    return PushEvent(type: pushTypeOf(rawType), rawType: rawType, orderId: _text(q['order_id']), orderNo: _text(q['order_no']), isOpen: _text(q['is_open']));
  }
}

/// Where a push leads (null = nowhere). The one place that decides, for taps from the system and from the banner.
String? pushRoute(PushEvent e) {
  String detail() => '${Routes.orders}/${Uri.encodeComponent(e.orderId)}';
  switch (e.type) {
    case PushType.newOrder:
    case PushType.upcomingOrder:
      return e.orderId.isEmpty ? Routes.ordersTab('new') : detail();
    case PushType.orderAccepted:
      return Routes.ordersTab('preparing');
    case PushType.orderDelivered:
    case PushType.orderCompleted:
      return Routes.ordersTab('completed');
    case PushType.orderCancelled:
      return Routes.ordersTab('cancelled');
    case PushType.orderExpired:
      return Routes.ordersTab('expired');
    case PushType.walletUpdate:
      return Routes.wallet;
    case PushType.openCloseStore:
      return Routes.home;
    case PushType.logout:
      return null;
    case PushType.chat:
    case PushType.other:
      return e.orderId.isEmpty ? Routes.home : detail();
  }
}