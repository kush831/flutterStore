import 'package:apporio_store_30sept/features/products/data/product_detail_models.dart';
import 'package:apporio_store_30sept/features/products/data/product_form_models.dart';
import 'package:apporio_store_30sept/features/products/data/variant_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/network/end_points.dart';
import '../../../core/network/paging.dart';
import '../../../core/storage/app_prefs.dart';
import '../../../core/storage/storage_providers.dart';
import '../logic/option_logic.dart';
import '../logic/product_form_state.dart';
import '../logic/variant_logic.dart';
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

  Future<VariantsData> variantsData(String productId) async {
    final root = await _api.postForm(EndPoints.productStep2, {'product_id': productId, 'locale': _locale});
    return VariantsData.fromJson(root);
  }

  /// One call per variant. `variantId` is '' for a new one. Returns the server's message.
  Future<String> saveVariant(String productId, String variantId, VariantForm f) async {
    final root = await _api.postJson(EndPoints.saveProductStep2, variantBody(productId: productId, variantId: variantId, f: f, locale: _locale));
    return root.text('message');
  }

  Future<StockData> stockData(String productId) async {
    final root = await _api.postForm(EndPoints.productStep3, {'product_id': productId, 'locale': _locale});
    return StockData.fromJson(root);
  }

  /// `newStock` is the new TOTAL (current + the change).
  Future<String> saveStock({required String variantId, required int newStock, required String cost, required String selling}) async {
    final root = await _api.postJson(EndPoints.saveProductStep3, {
      'new_stock': '$newStock',
      'product_cost': cost.trim(),
      'product_selling_price': selling.trim(),
      'product_variant_id': variantId,
      'locale': _locale,
    });
    return root.text('message');
  }

  Future<ProductDetail> detail(String productId) async {
    final root = await _api.postForm(EndPoints.productDetails, {'product_id': productId, 'locale': _locale});
    final d = ProductDetail.fromJson(root);
    if (d.id.isEmpty) throw const AppException('', kind: ErrorKind.server, detail: 'product detail without details');
    return d;
  }

  Future<List<OptionGroup>> mappingOptions(String productId) async {
    final root = await _api.postForm(EndPoints.productOptions, {'product_id': productId, 'locale': _locale});
    return [for (final g in root.sub('data').list('responseData', OptionGroup.fromJson)) if (g.options.isNotEmpty) g];
  }

  /// `all` is every option of every group (with its ticked state). Returns the server's message.
  Future<String> saveMappedOptions(String productId, List<MappedOption> all) async {
    final root = await _api.postJson(EndPoints.saveOptions, {
      'product_id': productId,
      'arr_option': optionsPayload(all), // JSON TEXT inside the JSON body
      'locale': _locale,
    });
    return root.text('message');
  }
}

final productsRepositoryProvider = Provider<ProductsRepository>(
      (ref) => ProductsRepository(ref.watch(apiClientProvider), ref.watch(appPrefsProvider)),
);