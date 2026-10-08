import '../../../core/network/json_reader.dart';

class DetailVariant {
  const DetailVariant({required this.id, this.name = '', this.price = '', this.discount = '', this.unit = '', this.stock = '', this.available = false});

  final String id;
  final String name;
  final String price;
  final String discount;
  final String unit;
  final String stock;
  final bool available;

  bool get hasDiscount => !RegExp(r'^[0\s.,]*$').hasMatch(discount);

  factory DetailVariant.fromJson(JsonReader r) => DetailVariant(
    id: r.text('productVariantId'),
    name: r.text('name'),
    price: r.text('productPrice'),
    discount: r.text('discount'),
    unit: r.text('weightUnit'),
    stock: r.text('stockQuantity'),
    available: r.flag('productAvailability'),
  );
}

/// An add-on option of a product (a topping, a size of sauce …).
class MappedOption {
  const MappedOption({required this.id, this.name = '', this.amount = '', this.checked = false, this.showAmountField = false});

  final String id;
  final String name;
  final String amount;
  final bool checked;
  final bool showAmountField; // this option carries a price

  MappedOption copyWith({bool? checked, String? amount}) =>
      MappedOption(id: id, name: name, amount: amount ?? this.amount, checked: checked ?? this.checked, showAmountField: showAmountField);

  factory MappedOption.fromJson(JsonReader r) => MappedOption(
    id: r.text('id'),
    name: r.text('name'),
    amount: r.text('amount'),
    checked: r.flag('checked'),
    showAmountField: r.flag('showAmountField'),
  );
}

class OptionGroup {
  const OptionGroup({required this.type, this.options = const []});

  final String type;
  final List<MappedOption> options;

  /// The mapping API calls the list `options`, the product detail API calls it `option_data`.
  factory OptionGroup.fromJson(JsonReader r, {String key = 'options'}) => OptionGroup(
    type: r.text('type'),
    options: [for (final o in r.list(key, MappedOption.fromJson)) if (o.id.isNotEmpty) o],
  );
}

class ProductDetail {
  const ProductDetail({
    required this.id,
    this.name = '',
    this.cover = '',
    this.currency = '',
    this.foodType = '',
    this.description = '',
    this.ingredients = '',
    this.manageInventory = '',
    this.available = false,
    this.variants = const [],
    this.optionGroups = const [],
    this.images = const [],
  });

  final String id;
  final String name;
  final String cover;
  final String currency;
  final String foodType;
  final String description;
  final String ingredients;
  final String manageInventory;
  final bool available;
  final List<DetailVariant> variants;
  final List<OptionGroup> optionGroups;
  final List<String> images; // the cover first, then the product images

  bool get isVeg => foodType.trim() == '1';
  bool get tracksInventory => manageInventory.trim() == '1';

  static double? _num(String s) => double.tryParse(s.replaceAll(RegExp(r'[^0-9.]'), ''));

  /// The cheapest and the dearest variant price (as the server wrote them), or null.
  ({String min, String max})? get priceRange {
    DetailVariant? lo, hi;
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

  /// Only the options that are mapped (ticked) to this product.
  List<OptionGroup> get mappedGroups => [
    for (final g in optionGroups)
      if (g.options.any((o) => o.checked)) OptionGroup(type: g.type, options: [for (final o in g.options) if (o.checked) o]),
  ];

  /// The price is not one fixed number.
  bool get priceVaries => variants.length > 1 || mappedGroups.isNotEmpty;

  factory ProductDetail.fromJson(JsonReader root) {
    final d = root.sub('data').sub('productDetails');
    final cover = d.text('productCoverImage');
    final more = [for (final i in d.list('productImage', (r) => r.text('image'))) if (i.isNotEmpty && i != cover) i];
    return ProductDetail(
      id: d.text('productId'),
      name: d.text('productName'),
      cover: cover,
      currency: d.text('currency'),
      foodType: d.text('foodType'),
      description: d.text('productDescription'),
      ingredients: d.text('ingredients'),
      manageInventory: d.text('manageInventory'),
      available: d.flag('productAvailability'),
      variants: [for (final v in d.list('subItems', DetailVariant.fromJson)) if (v.id.isNotEmpty) v],
      optionGroups: d.list('options', (r) => OptionGroup.fromJson(r, key: 'optionData')),
      images: [if (cover.isNotEmpty) cover, ...more],
    );
  }
}