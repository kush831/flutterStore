import '../../../core/network/json_reader.dart';
import '../logic/pos_shift_logic.dart' show posNum;

/// A category, or a sub-category (they have the same shape).
class PosCategory {
  const PosCategory({required this.id, this.name = '', this.image = '', this.hasSubcategory = false});

  final String id;
  final String name;
  final String image;
  final bool hasSubcategory;

  factory PosCategory.fromJson(JsonReader r) => PosCategory(id: r.text('id'), name: r.text('categoryName'), image: r.text('categoryImage'), hasSubcategory: r.flag('hasSubcategory'));
}

class PosVariant {
  const PosVariant({required this.id, this.productId = '', this.title = '', this.price = '', this.discount = '', this.discountedPrice = '', this.weightUnit = '', this.stock});

  final String id;
  final String productId;
  final String title;
  final String price;
  final String discount;
  final String discountedPrice;
  final String weightUnit;
  final int? stock; // null = the server did not say

  double get base => posNum(price);

  /// What the customer pays: the discounted price when the server sends a real one.
  /// (Jetpack took a discounted price of "0" literally, which made the item free.)
  double get unit {
    final d = double.tryParse(discountedPrice.trim());
    return (d != null && d > 0) ? d : base;
  }

  bool get hasDiscount => unit < base - 0.005;
  int get percentOff => (base > 0 && hasDiscount) ? ((base - unit) / base * 100).round() : 0;

  /// "500 g", "Large" … whatever names this variant.
  String get label => title.trim().isNotEmpty ? title : weightUnit;

  factory PosVariant.fromJson(JsonReader r) => PosVariant(
    id: r.text('id'),
    productId: r.text('productId'),
    title: r.text('title'),
    price: r.text('price'),
    discount: r.text('discount'),
    discountedPrice: r.text('discountedPrice'),
    weightUnit: r.text('weightUnit'),
    stock: r.integer('stockQuantity'),
  );

  Map<String, dynamic> toJson() => {'id': id, 'product_id': productId, 'title': title, 'price': price, 'discount': discount, 'discounted_price': discountedPrice, 'weight_unit': weightUnit, 'stock_quantity': stock};
}

class PosModifierContent {
  const PosModifierContent({required this.id, this.title = '', this.price = '', this.selected = false});

  final String id;
  final String title;
  final String price;
  final bool selected; // preselected by the server

  double get amount => posNum(price);

  factory PosModifierContent.fromJson(JsonReader r) => PosModifierContent(id: r.text('id'), title: r.text('title'), price: r.text('price'), selected: r.flag('selected'));

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'price': price, 'selected': selected ? 1 : 0};
}

class PosModifierGroup {
  const PosModifierGroup({this.title = '', this.mandatory = false, this.maxSelection = 0, this.contents = const []});

  final String title;
  final bool mandatory;
  final int maxSelection;
  final List<PosModifierContent> contents;

  /// How many may be picked. 0 from the server means "no limit" (Jetpack showed "Choose 0-0").
  int get limit => maxSelection > 0 ? maxSelection : contents.length;

  factory PosModifierGroup.fromJson(JsonReader r) => PosModifierGroup(title: r.text('cellTitle'), mandatory: r.flag('mandatory'), maxSelection: r.integer('maxSelection') ?? 0, contents: r.list('cellContents', PosModifierContent.fromJson));
  Map<String, dynamic> toJson() => {'cell_title': title, 'mandatory': mandatory ? 1 : 0, 'max_selection': maxSelection, 'cell_contents': [for (final c in contents) c.toJson()]};
}

class PosProduct {
  const PosProduct({
    required this.id,
    this.name = '',
    this.skuId = '',
    this.foodType = 0,
    this.image = '',
    this.price = '',
    this.formattedPrice = '',
    this.stock,
    this.manageInventory = false,
    this.description = '',
    this.variants = const [],
    this.modifiers = const [],
    this.categoryId = '',
  });

  final String id;
  final String name;
  final String skuId;
  final int foodType;
  final String image;
  final String price;
  final String formattedPrice;
  final int? stock;
  final bool manageInventory;
  final String description;
  final List<PosVariant> variants;
  final List<PosModifierGroup> modifiers;
  final String categoryId; // the category it was listed under (the cart counts per category)

  /// More than a plain "add": a size to pick, or extras.
  bool get hasChoices => modifiers.isNotEmpty || variants.length > 1;

  /// The variant a plain "+" adds. A product the server sends without variants gets one made from its price.
  PosVariant get firstVariant => variants.isNotEmpty ? variants.first : PosVariant(id: '0', productId: id, price: price);

  /// Out of stock: inventory is managed and every variant is known to be at zero. Unknown stock counts as available.
  bool get outOfStock {
    if (!manageInventory) return false;
    if (variants.isEmpty) return stock != null && stock! <= 0;
    return variants.every((v) => v.stock != null && v.stock! <= 0);
  }

  /// The lowest price the customer can pay for it.
  double get fromPrice => variants.isEmpty ? posNum(price) : variants.map((v) => v.unit).reduce((a, b) => a < b ? a : b);

  /// The largest discount among the variants, in percent.
  int get percentOff => variants.fold(0, (a, v) => v.percentOff > a ? v.percentOff : a);

  factory PosProduct.fromJson(JsonReader r, {String categoryId = ''}) => PosProduct(
    id: r.text('productId'),
    name: r.text('name'),
    skuId: r.text('skuId'),
    foodType: r.integer('foodType') ?? 0,
    image: r.text('image'),
    price: r.text('price'),
    formattedPrice: r.text('formattedPrice'),
    stock: r.integer('stock'),
    manageInventory: r.flag('manageInventory'),
    description: r.text('description'),
    variants: r.list('variants', PosVariant.fromJson),
    modifiers: r.list('modifiers', PosModifierGroup.fromJson),
    categoryId: categoryId,
  );

  /// The part of a product the saved cart needs (the chosen variant and extras are saved beside it).
///   /// Everything about the product, in the shape the server sends it (so [PosProduct.fromJson] reads it back).
//   /// The saved cart and the held carts keep it whole, so a line can be edited again later.
  Map<String, dynamic> toJson() => {
        'product_id': id,
        'name': name,
        'sku_id': skuId,
        'food_type': foodType,
        'image': image,
        'price': price,
        'formatted_price': formattedPrice,
        'stock': stock,
        'manage_inventory': manageInventory ? 1 : 0,
        'description': description,
        'category_id': categoryId,
        'variants': [for (final v in variants) v.toJson()],
        'modifiers': [for (final g in modifiers) g.toJson()],
      };
}

/// A category found by a search, with its sub-categories.
class PosSearchCategory {
  const PosSearchCategory({required this.id, this.name = '', this.image = '', this.subs = const []});

  final String id;
  final String name;
  final String image;
  final List<PosCategory> subs;

  factory PosSearchCategory.fromJson(JsonReader r) => PosSearchCategory(id: r.text('id'), name: r.text('categoryName'), image: r.text('categoryImage'), subs: r.list('subcategories', PosCategory.fromJson));
}

class PosSearchResult {
  const PosSearchResult({this.categories = const [], this.products = const []});

  final List<PosSearchCategory> categories;
  final List<PosProduct> products;

  bool get isEmpty => categories.isEmpty && products.isEmpty;
  int get count => categories.length + products.length;

  factory PosSearchResult.fromJson(JsonReader d) => PosSearchResult(
    categories: [for (final c in d.list('categories', PosSearchCategory.fromJson)) if (c.id.isNotEmpty) c],
    products: [for (final p in d.list('products', (r) => PosProduct.fromJson(r))) if (p.id.isNotEmpty) p],
  );
}

/// A variant as the product detail API describes it (not the same shape as in the product list).
class PosDetailVariant {
  const PosDetailVariant({required this.id, this.sku = '', this.name = '', this.price = '', this.discount = '', this.weightUnit = '', this.stock, this.available = true});

  final String id;
  final String sku;
  final String name;
  final String price;
  final String discount;
  final String weightUnit;
  final int? stock;
  final bool available;

  factory PosDetailVariant.fromJson(JsonReader r) => PosDetailVariant(
    id: r.text('productVariantId'),
    sku: r.text('productVariantSkuId'),
    name: r.text('name'),
    price: r.text('productPrice'),
    discount: r.text('discount'),
    weightUnit: r.text('weightUnit'),
    stock: r.integer('stockQuantity'),
    available: r.has('productAvailability') ? r.flag('productAvailability') : true,
  );
}

class PosOptionItem {
  const PosOptionItem({required this.id, this.name = '', this.amount = '', this.checked = false});

  final String id;
  final String name;
  final String amount;
  final bool checked;

  factory PosOptionItem.fromJson(JsonReader r) => PosOptionItem(id: r.text('id'), name: r.text('name'), amount: r.text('amount'), checked: r.flag('checked'));
}

class PosOptionGroup {
  const PosOptionGroup({this.type = '', this.items = const []});

  final String type;
  final List<PosOptionItem> items;

  factory PosOptionGroup.fromJson(JsonReader r) => PosOptionGroup(type: r.text('type'), items: r.list('optionData', PosOptionItem.fromJson));
}

class PosProductDetail {
  const PosProductDetail({
    required this.id,
    this.sku = '',
    this.name = '',
    this.cover = '',
    this.images = const [],
    this.currency = '',
    this.foodType = 0,
    this.description = '',
    this.ingredients = '',
    this.manageInventory = false,
    this.available = true,
    this.variants = const [],
    this.options = const [],
  });

  final String id;
  final String sku;
  final String name;
  final String cover;
  final List<String> images;
  final String currency;
  final int foodType;
  final String description;
  final String ingredients;
  final bool manageInventory;
  final bool available;
  final List<PosDetailVariant> variants;
  final List<PosOptionGroup> options;

  /// The cover first, then the other photos, each once.
  List<String> get gallery => <String>{if (cover.isNotEmpty) cover, ...images.where((i) => i.isNotEmpty)}.toList();

  factory PosProductDetail.fromJson(JsonReader root) {
    final d = root.sub('data').sub('productDetails');
    return PosProductDetail(
      id: d.text('productId'),
      sku: d.text('skuId'),
      name: d.text('productName'),
      cover: d.text('productCoverImage'),
      images: d.list('productImage', (r) => r.text('image')),
      currency: d.text('currency'),
      foodType: d.integer('foodType') ?? 0,
      description: d.text('productDescription'),
      ingredients: d.text('ingredients'),
      manageInventory: d.flag('manageInventory'),
      available: d.has('productAvailability') ? d.flag('productAvailability') : true,
      variants: d.list('subItems', PosDetailVariant.fromJson),
      options: [for (final g in d.list('options', PosOptionGroup.fromJson)) if (g.items.isNotEmpty) g],
    );
  }
}