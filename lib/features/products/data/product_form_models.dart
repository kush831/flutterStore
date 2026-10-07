import '../../../core/network/json_reader.dart';

/// One choice in a server list: { "key": 3, "value": "Starters" }.
class FormOption {
  const FormOption(this.key, this.value);

  final int key;
  final String value;

  factory FormOption.fromJson(JsonReader r) => FormOption(r.integer('key') ?? -1, r.text('value'));
}

/// A picture the server already has for this product.
class ExistingImage {
  const ExistingImage({required this.id, required this.url});

  final int id;
  final String url;

  factory ExistingImage.fromJson(JsonReader r) => ExistingImage(id: r.integer('id') ?? 0, url: r.text('image'));
}

/// The saved step-1 values of an existing product.
class ProductBasics {
  const ProductBasics({
    required this.id,
    this.sku = '',
    this.name = '',
    this.description = '',
    this.ingredients = '',
    this.foodType = -1,
    this.categoryId = -1,
    this.coverUrl = '',
    this.prepTime = '',
    this.sequence = 0,
    this.status = -1,
    this.manageInventory = 2,
    this.subCategoryId = -1,
    this.images = const [],
  });

  final int id;
  final String sku;
  final String name;
  final String description;
  final String ingredients;
  final int foodType;
  final int categoryId;
  final String coverUrl;
  final String prepTime;
  final int sequence;
  final int status;
  final int manageInventory; // 1 = stock is tracked, 2 = off
  final int subCategoryId;
  final List<ExistingImage> images;

  factory ProductBasics.fromJson(JsonReader r) => ProductBasics(
    id: r.integer('id') ?? 0,
    sku: r.text('skuId'),
    name: r.text('name'),
    description: r.text('description'),
    ingredients: r.text('productIngredients'),
    foodType: r.integer('foodType') ?? -1,
    categoryId: r.integer('categoryId') ?? -1,
    coverUrl: r.text('productCoverImage'),
    prepTime: r.text('productPreparationTime'),
    sequence: r.integer('sequence') ?? 0,
    status: r.integer('status') ?? -1,
    manageInventory: r.integer('manageInventory') ?? 2,
    subCategoryId: r.integer('subCategoryId') ?? -1,
    images: [for (final i in r.list('arrImages', ExistingImage.fromJson)) if (i.url.isNotEmpty) i],
  );
}

/// Everything the step-1 form needs: the product (null for a new one) and the lists to choose from.
class ProductFormData {
  const ProductFormData({
    this.product,
    this.categories = const [],
    this.foodTypes = const [],
    this.statuses = const [],
    this.skuId = 0,
    this.subCategoryOptional = false,
    this.skuAutoGenerate = false,
  });

  final ProductBasics? product;
  final List<FormOption> categories;
  final List<FormOption> foodTypes;
  final List<FormOption> statuses;
  final int skuId; // the next SKU number when the server generates it
  final bool subCategoryOptional;
  final bool skuAutoGenerate;

  factory ProductFormData.fromJson(JsonReader root) {
    final d = root.sub('data');
    final p = d.sub('product');
    return ProductFormData(
      product: (p.integer('id') ?? 0) > 0 ? ProductBasics.fromJson(p) : null,
      categories: d.list('arrCategory', FormOption.fromJson),
      foodTypes: d.list('arrFoodType', FormOption.fromJson),
      statuses: d.list('arrStatus', FormOption.fromJson),
      skuId: d.integer('skuId') ?? 0,
      subCategoryOptional: d.flag('subCatOptional'),
      skuAutoGenerate: d.flag('enableSkuAutoGenerate'),
    );
  }
}