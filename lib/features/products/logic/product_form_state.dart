import 'dart:convert';
import 'dart:typed_data';

import '../../../core/media/image_picking.dart';
import '../data/product_form_models.dart';

const kMaxProductImages = 4;

/// ⚠️ Which existing-image ids go into `product_image_ids_array`?
///  false = exactly like Jetpack: only ids whose URL does not start with "https" (in practice none).
///  true  = the ids of every existing image the user kept.
/// Test on a test product (see the checklist). If an image you removed in the app comes back after saving, set true.
const kSendKeptImageIds = false;

enum ProductField { cover, sku, name, category, subCategory, prepTime, sequence }

class ProductForm {
  const ProductForm({
    this.coverPhoto,
    this.coverUrl = '',
    this.newImages = const [],
    this.keptImages = const [],
    this.sku = '',
    this.name = '',
    this.description = '',
    this.ingredients = '',
    this.prepTime = '',
    this.sequence = '',
    this.statusKey = -1,
    this.foodTypeKey = -1,
    this.categoryKey = -1,
    this.subCategoryKey = -1,
    this.manageInventory = false,
  });

  final PickedPhoto? coverPhoto; // a new cover chosen on this phone
  final String coverUrl; // the cover the server already has
  final List<PickedPhoto> newImages;
  final List<ExistingImage> keptImages;
  final String sku;
  final String name;
  final String description;
  final String ingredients;
  final String prepTime;
  final String sequence;
  final int statusKey;
  final int foodTypeKey;
  final int categoryKey;
  final int subCategoryKey;
  final bool manageInventory;

  bool get hasCover => coverPhoto != null || coverUrl.isNotEmpty;
  int get imageCount => keptImages.length + newImages.length;
  bool get canAddImage => imageCount < kMaxProductImages;

  ProductForm copyWith({
    PickedPhoto? coverPhoto,
    bool clearCoverPhoto = false,
    String? coverUrl,
    List<PickedPhoto>? newImages,
    List<ExistingImage>? keptImages,
    String? sku,
    String? name,
    String? description,
    String? ingredients,
    String? prepTime,
    String? sequence,
    int? statusKey,
    int? foodTypeKey,
    int? categoryKey,
    int? subCategoryKey,
    bool? manageInventory,
  }) =>
      ProductForm(
        coverPhoto: clearCoverPhoto ? null : (coverPhoto ?? this.coverPhoto),
        coverUrl: coverUrl ?? this.coverUrl,
        newImages: newImages ?? this.newImages,
        keptImages: keptImages ?? this.keptImages,
        sku: sku ?? this.sku,
        name: name ?? this.name,
        description: description ?? this.description,
        ingredients: ingredients ?? this.ingredients,
        prepTime: prepTime ?? this.prepTime,
        sequence: sequence ?? this.sequence,
        statusKey: statusKey ?? this.statusKey,
        foodTypeKey: foodTypeKey ?? this.foodTypeKey,
        categoryKey: categoryKey ?? this.categoryKey,
        subCategoryKey: subCategoryKey ?? this.subCategoryKey,
        manageInventory: manageInventory ?? this.manageInventory,
      );

  factory ProductForm.fromProduct(ProductBasics p) => ProductForm(
    coverUrl: p.coverUrl,
    keptImages: p.images,
    sku: p.sku,
    name: p.name,
    description: p.description,
    ingredients: p.ingredients,
    prepTime: p.prepTime,
    sequence: p.sequence > 0 ? '${p.sequence}' : '',
    statusKey: p.status,
    foodTypeKey: p.foodType,
    categoryKey: p.categoryId,
    subCategoryKey: p.subCategoryId,
    manageInventory: p.manageInventory == 1,
  );
}

/// The problems of a form, all at once: field → the key of the server text to show.
Map<ProductField, String> validateProduct(
    ProductForm f, {
      required bool isFood,
      required bool skuAutoGenerate,
      required bool subCategoryRequired,
    }) {
  final e = <ProductField, String>{};
  if (!f.hasCover) e[ProductField.cover] = 'products_addproductscreen_upload_cover_title';
  if (!skuAutoGenerate && f.sku.trim().isEmpty) e[ProductField.sku] = 'products_addproductscreen_sku_required';
  if (f.name.trim().isEmpty) e[ProductField.name] = 'products_addproductscreen_name_required';
  if (f.categoryKey < 0) e[ProductField.category] = 'products_addproductscreen_category_required';
  if (subCategoryRequired && f.subCategoryKey < 0) e[ProductField.subCategory] = 'products_addproductscreen_sub_category_required';
  if (isFood) {
    final k = _positiveInt(f.prepTime, 'products_addproductscreen_preparation_time');
    if (k != null) e[ProductField.prepTime] = k;
  }
  final s = _positiveInt(f.sequence, 'products_addproductscreen_sequence');
  if (s != null) e[ProductField.sequence] = s;
  return e;
}

String? _positiveInt(String raw, String prefix) {
  final t = raw.trim();
  if (t.isEmpty) return '${prefix}_required';
  final n = int.tryParse(t);
  if (n == null) return '${prefix}_enterValidNumber';
  if (n <= 0) return '${prefix}_mustBeGreaterThan0';
  return null;
}

/// The cover as the server expects it: text, a data URI (the same as Jetpack sends).
String coverDataUri(Uint8List bytes) => 'data:image/png;base64,${base64Encode(bytes)}';

/// The value of `product_image_ids_array`: comma-separated ids.
String keptImageIds(List<ExistingImage> kept, {bool all = kSendKeptImageIds}) =>
    [for (final i in kept) if (i.id != 0 && (all || !i.url.startsWith('https'))) i.id].join(',');

/// Every text field of the step-1 save (the cover and the new pictures are added by the repository).
Map<String, String> step1Fields({
  required String productId,
  required ProductForm f,
  required String locale,
  required String coverData,
  required String keptIds,
}) =>
    {
      'id': productId,
      'sku_id': f.sku.trim(),
      'product_name': f.name.trim(),
      'product_ingredients': f.ingredients.trim(),
      'status': '${f.statusKey < 0 ? 0 : f.statusKey}',
      'product_description': f.description.trim(),
      'category_id': '${f.categoryKey}',
      'sequence': f.sequence.trim(),
      'manage_inventory': f.manageInventory ? '1' : '2', // 1 = on, 2 = off
      'product_preparation_time': f.prepTime.trim(),
      'sub_category_id': '${f.subCategoryKey < 0 ? 0 : f.subCategoryKey}',
      'type': '${f.foodTypeKey < 0 ? 0 : f.foodTypeKey}',
      'multi_part': '1',
      'product_cover_image': coverData,
      'product_image_ids_array': keptIds,
      'locale': locale,
    };