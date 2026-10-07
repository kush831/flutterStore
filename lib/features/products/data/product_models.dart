import '../../../core/network/json_reader.dart';

class ProductVariant {
  const ProductVariant({
    required this.id,
    this.name = '',
    this.price = '',
    this.discount = '',
    this.unit = '',
    this.stock = '',
    this.available = false,
    this.busy = false,
  });

  final String id;
  final String name;
  final String price; // as formatted by the server
  final String discount;
  final String unit;
  final String stock; // quantity as text
  final bool available;
  final bool busy; // a switch call is running

  /// Jetpack's rule: out of stock = the quantity is exactly "0".
  bool get outOfStock => stock.trim() == '0';

  /// "0", "0.00" and "" mean no discount.
  bool get hasDiscount => !RegExp(r'^[0\s.,]*$').hasMatch(discount);

  ProductVariant copyWith({bool? available, bool? busy}) => ProductVariant(
    id: id,
    name: name,
    price: price,
    discount: discount,
    unit: unit,
    stock: stock,
    available: available ?? this.available,
    busy: busy ?? this.busy,
  );

  factory ProductVariant.fromJson(JsonReader r) => ProductVariant(
    id: r.text('productVariantId'),
    name: r.text('name'),
    price: r.text('productPrice'),
    discount: r.text('discount'),
    unit: r.text('weightUnit'),
    stock: r.text('stockQuantity'),
    available: r.flag('productAvailability'),
  );
}

class Product {
  const Product({
    required this.id,
    this.sku = '',
    this.name = '',
    this.cover = '',
    this.image = '',
    this.currency = '',
    this.foodType = '',
    this.category = '',
    this.manageInventory = '',
    this.available = false,
    this.variants = const [],
    this.busy = false,
  });

  final String id;
  final String sku;
  final String name;
  final String cover;
  final String image;
  final String currency;
  final String foodType;
  final String category;
  final String manageInventory;
  final bool available;
  final List<ProductVariant> variants;
  final bool busy; // the product switch call is running

  String get picture => cover.isNotEmpty ? cover : image;

  /// "1" = veg, anything else = non-veg (Jetpack).
  bool get isVeg => foodType.trim() == '1';

  /// manage_inventory: "1" = stock is tracked, "2" = off.
  bool get tracksInventory => manageInventory.trim() == '1';

  int get variantCount => variants.length;

  /// Every variant is at zero.
  bool get isOutOfStock => variants.isNotEmpty && variants.every((v) => v.outOfStock);

  static double? _num(String s) => double.tryParse(s.replaceAll(RegExp(r'[^0-9.]'), ''));

  /// The cheapest and the dearest variant price (as the server wrote them), or null.
  ({String min, String max})? get priceRange {
    ProductVariant? lo, hi;
    double? loV, hiV;
    for (final v in variants) {
      final n = _num(v.price);
      if (n == null) continue;
      if (loV == null || n < loV) {
        loV = n;
        lo = v;
      }
      if (hiV == null || n > hiV) {
        hiV = n;
        hi = v;
      }
    }
    return lo == null ? null : (min: lo.price, max: hi!.price);
  }

  Product copyWith({bool? available, bool? busy, List<ProductVariant>? variants}) => Product(
    id: id,
    sku: sku,
    name: name,
    cover: cover,
    image: image,
    currency: currency,
    foodType: foodType,
    category: category,
    manageInventory: manageInventory,
    available: available ?? this.available,
    variants: variants ?? this.variants,
    busy: busy ?? this.busy,
  );

  factory Product.fromJson(JsonReader r) => Product(
    id: r.text('productId'),
    sku: r.text('skuId'),
    name: r.text('productName'),
    cover: r.text('productCoverImage'),
    image: r.text('productImage'),
    currency: r.text('currency'),
    foodType: r.text('foodType'),
    category: r.text('category'),
    manageInventory: r.text('manageInventory'),
    available: r.flag('productAvailability'),
    variants: r.list('subItems', ProductVariant.fromJson),
  );
}

class ProductCategory {
  const ProductCategory({required this.id, required this.name, this.image = ''});

  final String id;
  final String name;
  final String image;

  factory ProductCategory.fromJson(JsonReader r) => ProductCategory(id: r.text('categoryId'), name: r.text('categoryName'), image: r.text('categoryImage'));
}