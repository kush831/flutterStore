import 'package:apporio_store_30sept/features/products/data/product_form_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/end_points.dart';
import '../../../core/network/paging.dart';
import '../../../core/storage/app_prefs.dart';
import '../../../core/storage/storage_providers.dart';
import '../logic/product_form_state.dart';
import 'product_models.dart';

/// What the list shows. `searchText` is the typed search, or the chosen category's name (Jetpack's rule).
class ProductQuery {
  const ProductQuery({this.type = 'ALL', this.searchText = ''});

  /// ALL | LOWSTOCK | OUTOFSTOCK
  final String type;
  final String searchText;

  static String normalizeType(String? t) {
    final u = (t ?? '').trim().toUpperCase();
    return (u == 'LOWSTOCK' || u == 'OUTOFSTOCK') ? u : 'ALL';
  }

  @override
  bool operator ==(Object other) => other is ProductQuery && other.type == type && other.searchText == searchText;

  @override
  int get hashCode => Object.hash(type, searchText);
}

class ProductsRepository {
  ProductsRepository(this._api, this._prefs);

  final ApiClient _api;
  final AppPrefs _prefs;

  String get _locale => _prefs.language ?? 'en';

  Future<PageResult<Product>> page(ProductQuery q, int page) async {
    final root = await _api.postForm(EndPoints.getProducts, {
      'page': page,
      'type': q.type,
      'search_text': q.searchText,
      'locale': _locale,
    });
    final d = root.sub('data');
    final items = [for (final p in d.list('items', Product.fromJson)) if (p.id.isNotEmpty) p];
    return PageResult(items, nextPageOf(page, d.str('nextPageUrl'), gotItems: items.isNotEmpty));
  }

  Future<List<ProductCategory>> categories() async {
    final root = await _api.get(EndPoints.merchantCategories);
    return [for (final c in root.sub('data').list('categories', ProductCategory.fromJson)) if (c.name.isNotEmpty) c];
  }

  /// "1" = available, "2" = not available (not "0").
  Future<void> setProductAvailable(String productId, bool on) => _api.postJson(EndPoints.updateProductStatus, {
    'status_for': 'PRODUCT',
    'product_id': productId,
    'status': on ? '1' : '2',
    'locale': _locale,
  });

  Future<void> setVariantAvailable(String variantId, bool on) => _api.postJson(EndPoints.updateProductStatus, {
    'status_for': 'VARIANT',
    'product_variant_id': variantId,
    'status': on ? '1' : '2',
    'locale': _locale,
  });

  Future<ProductFormData> formData(String productId) async {
    final root = await _api.postForm(EndPoints.productStep1, {'product_id': productId, 'locale': _locale});
    return ProductFormData.fromJson(root);
  }

  Future<List<FormOption>> subCategories(int categoryId) async {
    final root = await _api.postJson(EndPoints.subCategories, {'category_id': '$categoryId', 'locale': _locale});
    return [for (final o in root.list('data', FormOption.fromJson)) if (o.key >= 0) o];
  }

  /// Saves step 1. `productId` is '' for a new product. Returns the product's id and the server's message.
  Future<({String id, String message})> saveBasics(String productId, ProductForm f, {void Function(double)? onProgress}) async {
    // The server expects the cover in every save, as text. A new photo is encoded; the current one is downloaded again (Jetpack does the same).
    var cover = '';
    if (f.coverPhoto != null) {
      cover = coverDataUri(f.coverPhoto!.bytes);
    } else if (f.coverUrl.isNotEmpty) {
      cover = coverDataUri(await _api.download(f.coverUrl));
    }

    final fields = <String, Object?>{
      ...step1Fields(productId: productId, f: f, locale: _locale, coverData: cover, keptIds: keptImageIds(f.keptImages)),
    };
    final files = <(String, UploadFile)>[
      for (var i = 0; i < f.newImages.length; i++) ('product_image[$i]', UploadFile(bytes: f.newImages[i].bytes, filename: f.newImages[i].name)),
    ];
    // no new picture: the server still wants the key (it errors with "undefined array key 0" otherwise)
    if (files.isEmpty) fields['product_image[]'] = '';

    final root = await _api.postMultipart(
      EndPoints.saveProductStep1,
      fields: fields,
      files: files,
      onProgress: onProgress == null ? null : (sent, total) => total > 0 ? onProgress(sent / total) : null,
    );
    return (id: root.sub('data').text('id'), message: root.text('message'));
  }
}

final productsRepositoryProvider = Provider<ProductsRepository>(
      (ref) => ProductsRepository(ref.watch(apiClientProvider), ref.watch(appPrefsProvider)),
);