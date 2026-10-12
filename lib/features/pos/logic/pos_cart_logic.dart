import 'dart:convert';

import '../../../core/network/json_reader.dart';
import '../data/pos_catalog_models.dart';

/// One line of the cart: a product, the variant chosen, the extras chosen and how many.
class PosCartItem {
  const PosCartItem({required this.product, required this.variant, required this.quantity, this.modifiers = const []});

  final PosProduct product;
  final PosVariant variant;
  final int quantity;
  final List<PosModifierContent> modifiers;

  /// Two lines are the same line when the product, the variant and the SET of extras match.
  String get key {
    final ids = modifiers.map((m) => m.id).toList()..sort();
    return '${product.id}|${variant.id}|${ids.join(',')}';
  }

  double get unitPrice => variant.unit + modifiers.fold(0.0, (a, m) => a + m.amount);
  double get lineTotal => unitPrice * quantity;

  PosCartItem withQuantity(int q) => PosCartItem(product: product, variant: variant, quantity: q, modifiers: modifiers);

  Map<String, dynamic> toJson() => {'p': product.toJson(), 'v': variant.toJson(), 'm': [for (final m in modifiers) m.toJson()], 'q': quantity};

  factory PosCartItem.fromJson(JsonReader r) {
    final pr = r.sub('p');
    return PosCartItem(
      product: PosProduct.fromJson(pr, categoryId: pr.text('categoryId')),
      variant: PosVariant.fromJson(r.sub('v')),
      quantity: r.integer('q') ?? 1,
      modifiers: r.list('m', PosModifierContent.fromJson),
    );
  }
}

/// Adds [qty] of this exact line, or raises the quantity of the line that already matches.
List<PosCartItem> cartAdd(List<PosCartItem> items, PosProduct product, PosVariant variant, {List<PosModifierContent> modifiers = const [], int qty = 1}) {
  final probe = PosCartItem(product: product, variant: variant, quantity: qty, modifiers: modifiers);
  final i = items.indexWhere((e) => e.key == probe.key);
  if (i < 0) return [...items, probe];
  return [for (var k = 0; k < items.length; k++) k == i ? items[k].withQuantity(items[k].quantity + qty) : items[k]];
}

/// One less of a line; at 1 the line goes.
List<PosCartItem> cartRemoveOne(List<PosCartItem> items, String key) {
  final i = items.indexWhere((e) => e.key == key);
  if (i < 0) return items;
  if (items[i].quantity <= 1) return [...items]..removeAt(i);
  return [for (var k = 0; k < items.length; k++) k == i ? items[k].withQuantity(items[k].quantity - 1) : items[k]];
}

List<PosCartItem> cartRemoveLine(List<PosCartItem> items, String key) => [for (final e in items) if (e.key != key) e];

int cartCount(List<PosCartItem> items) => items.fold(0, (a, e) => a + e.quantity);

double cartTotal(List<PosCartItem> items) => items.fold(0.0, (a, e) => a + e.lineTotal);

/// How many of this variant are in the cart, whatever extras they carry.
int quantityOfVariant(List<PosCartItem> items, String productId, String variantId) => items.where((e) => e.product.id == productId && e.variant.id == variantId).fold(0, (a, e) => a + e.quantity);

/// How many of this product are in the cart, in any variant.
int quantityOfProduct(List<PosCartItem> items, String productId) => items.where((e) => e.product.id == productId).fold(0, (a, e) => a + e.quantity);

int countForCategory(List<PosCartItem> items, String categoryId) => items.where((e) => e.product.categoryId == categoryId).fold(0, (a, e) => a + e.quantity);

/// How many more of this variant may be added: null = no limit, 0 = none (the stock is already in the cart).
int? roomFor(List<PosCartItem> items, PosProduct product, PosVariant variant) {
  if (!product.manageInventory) return null;
  final stock = variant.stock ?? (product.variants.isEmpty ? product.stock : null);
  if (stock == null) return null;
  final left = stock - quantityOfVariant(items, product.id, variant.id);
  return left < 0 ? 0 : left;
}

String cartToJson(List<PosCartItem> items) => jsonEncode([for (final e in items) e.toJson()]);

List<PosCartItem> cartFromJson(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final d = jsonDecode(raw);
    if (d is! List) return const [];
    return [for (final e in d) if (e is Map) PosCartItem.fromJson(JsonReader(e))];
  } catch (_) {
    return const []; // a damaged saved cart is an empty cart, never a crash
  }
}
/// Replaces a line with an edited one (another size, other extras, another quantity). The new line takes the old one's place,
/// unless it now matches a line that is already there: then the two merge.
List<PosCartItem> cartReplace(List<PosCartItem> items, String oldKey, PosProduct product, PosVariant variant, {required List<PosModifierContent> modifiers, required int qty}) {
  final i = items.indexWhere((e) => e.key == oldKey);
  if (i < 0) return cartAdd(items, product, variant, modifiers: modifiers, qty: qty);
  final fresh = PosCartItem(product: product, variant: variant, quantity: qty, modifiers: modifiers);
  final without = [...items]..removeAt(i);
  final j = without.indexWhere((e) => e.key == fresh.key);
  if (j >= 0) return [for (var k = 0; k < without.length; k++) k == j ? without[k].withQuantity(without[k].quantity + qty) : without[k]];
  return [...without.take(i), fresh, ...without.skip(i)];
}

/// What the customer saves through item discounts (not counting a promo code).
double cartSavings(List<PosCartItem> items) => items.fold(0.0, (a, e) => a + (e.variant.hasDiscount ? (e.variant.base - e.variant.unit) * e.quantity : 0));