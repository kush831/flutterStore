import 'dart:convert';

import '../data/pos_checkout_models.dart';
import 'pos_cart_logic.dart';

/// Jetpack picks the order type from the name of the POS service: Dine In, Pickup, Delivery, Take Away.
String orderTypeKey(String serviceName) {
  final n = serviceName.toLowerCase();
  if (n.contains('dine')) return 'dine_in';
  if (n.contains('pickup')) return 'self_pickup';
  if (n.contains('delivery')) return 'delivery';
  if (n.contains('take') || n.contains('away')) return 'take_away';
  return 'dine_in';
}

/// The `product_details` text of "save cart": a JSON list of variant id, quantity and the ids of the extras.
String productDetailsJson(List<PosCartItem> items) => jsonEncode([
  for (final i in items) {'product_variant_id': int.tryParse(i.variant.id) ?? 0, 'quantity': i.quantity, 'options': [for (final m in i.modifiers) m.id]},
]);

/// "10%" for a percentage offer, otherwise the fixed amount formatted by [money].
String promoOffLabel(PosPromo p, String Function(String) money) => p.isPercent ? '${p.value}%' : money(p.value);

// ── held carts ────────────────────────────────────────────────────────────────

/// A cart set aside to be resumed later. Kept on the device. (Jetpack dropped the extras when holding; they are kept here.)
class PosHeldCart {
  const PosHeldCart({required this.id, required this.items, this.customerName = '', required this.createdAt, this.heldBy = ''});

  final String id;
  final List<PosCartItem> items;
  final String customerName; // empty = walk-in
  final int createdAt; // milliseconds since 1970
  final String heldBy; // the staff id

  int get count => cartCount(items);
  double get total => cartTotal(items);

  bool isToday(DateTime now) {
    final d = DateTime.fromMillisecondsSinceEpoch(createdAt);
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  Map<String, dynamic> toJson() => {'id': id, 'items': [for (final i in items) i.toJson()], 'customer': customerName, 'at': createdAt, 'by': heldBy};
}

/// "H-RS-" + month, day, hour, minute, second. (Jetpack wrote a fixed "0629" where the date belongs.)
String heldCartId(DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  return 'H-RS-${two(now.month)}${two(now.day)}${two(now.hour)}${two(now.minute)}${two(now.second)}';
}

/// How old a held cart is: the text key and the number to put into it.
({String key, int? n}) heldAge(int createdAt, DateTime now) {
  final minutes = now.difference(DateTime.fromMillisecondsSinceEpoch(createdAt)).inMinutes;
  if (minutes < 1) return (key: 'pos_held_just_now', n: null);
  if (minutes < 60) return (key: 'pos_held_min_ago', n: minutes);
  return (key: 'pos_held_hours_ago', n: minutes ~/ 60);
}

enum HeldTab { all, mine, today }

/// The held carts of a tab, narrowed by the search text (cart id or customer name).
List<PosHeldCart> filterHeld(List<PosHeldCart> all, {required HeldTab tab, required String staffId, required String query, required DateTime now}) {
  final q = query.trim().toLowerCase();
  return [
    for (final h in all)
      if ((tab == HeldTab.all || (tab == HeldTab.mine && h.heldBy == staffId) || (tab == HeldTab.today && h.isToday(now))) &&
          (q.isEmpty || h.id.toLowerCase().contains(q) || h.customerName.toLowerCase().contains(q)))
        h,
  ];
}