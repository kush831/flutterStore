import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/json_reader.dart';
import '../../../core/storage/storage_providers.dart';
import 'pos_auth.dart';
import 'pos_cart_logic.dart';
import 'pos_checkout_logic.dart';

class PosHeld extends Notifier<List<PosHeldCart>> {
  static const _key = 'pos_held_carts';

  @override
  List<PosHeldCart> build() {
    ref.watch(posScopeProvider);
    final raw = ref.read(sharedPreferencesProvider).getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final d = jsonDecode(raw);
      if (d is! List) return const [];
      return [
        for (final e in d)
          if (e is Map)
                () {
              final r = JsonReader(e);
              return PosHeldCart(id: r.text('id'), items: r.list('items', PosCartItem.fromJson), customerName: r.text('customer'), createdAt: r.integer('at') ?? 0, heldBy: r.text('by'));
            }(),
      ];
    } catch (_) {
      return const []; // a damaged list is an empty list
    }
  }

  void _set(List<PosHeldCart> list) {
    state = list;
    ref.read(sharedPreferencesProvider).setString(_key, jsonEncode([for (final h in list) h.toJson()]));
  }

  /// Sets the cart aside. An empty cart is not held.
  void hold(List<PosCartItem> items, {String customerName = ''}) {
    if (items.isEmpty) return;
    final staffId = ref.read(posAuthProvider).staff?.staffId ?? '';
    final now = DateTime.now();
    _set([...state, PosHeldCart(id: heldCartId(now), items: items, customerName: customerName, createdAt: now.millisecondsSinceEpoch, heldBy: staffId)]);
  }

  void remove(String id) => _set([for (final h in state) if (h.id != id) h]);

  void clear() => _set(const []);
}

final posHeldCartsProvider = NotifierProvider<PosHeld, List<PosHeldCart>>(PosHeld.new);