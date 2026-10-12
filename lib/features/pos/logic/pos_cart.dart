import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_providers.dart';
import '../data/pos_catalog_models.dart';
import 'pos_auth.dart';
import 'pos_cart_logic.dart';

/// The cart of the open POS shift. Kept on the device, so an app restart keeps it.
/// Cleared when the shift is closed and when the staff member signs out of POS.
class PosCart extends Notifier<List<PosCartItem>> {
  static const _key = 'pos_cart';

  @override
  List<PosCartItem> build() {
    ref.watch(posScopeProvider); // a POS sign-out starts a fresh cart
    return cartFromJson(ref.read(sharedPreferencesProvider).getString(_key));
  }

  void _set(List<PosCartItem> items) {
    state = items;
    ref.read(sharedPreferencesProvider).setString(_key, cartToJson(items));
  }

  void add(PosProduct product, PosVariant variant, {List<PosModifierContent> modifiers = const [], int qty = 1}) => _set(cartAdd(state, product, variant, modifiers: modifiers, qty: qty));
  void removeOne(String key) => _set(cartRemoveOne(state, key));
  void removeLine(String key) => _set(cartRemoveLine(state, key));
  void clear() => _set(const []);
  void replace(String oldKey, PosProduct product, PosVariant variant, {required List<PosModifierContent> modifiers, required int qty}) => _set(cartReplace(state, oldKey, product, variant, modifiers: modifiers, qty: qty));
}

final posCartProvider = NotifierProvider<PosCart, List<PosCartItem>>(PosCart.new);
final posCartCountProvider = Provider<int>((ref) => cartCount(ref.watch(posCartProvider)));
final posCartTotalProvider = Provider<double>((ref) => cartTotal(ref.watch(posCartProvider)));