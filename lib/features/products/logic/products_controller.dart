import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/error_text.dart';
import '../../../core/network/paging.dart';
import '../../../core/strings/strings_controller.dart';
import '../data/product_models.dart';
import '../data/products_repository.dart';

class ProductsController extends PagedNotifier<Product> {
  ProductsController(this.query);

  final ProductQuery query;

  ProductsRepository get _repo => ref.read(productsRepositoryProvider);

  @override
  PagedState<Product> build() {
    ref.watch(userScopeProvider); // a sign-out throws the previous store's products away
    return super.build();
  }

  @override
  Future<PageResult<Product>> fetchPage(int page) => _repo.page(query, page);

  /// The switch moves at once. Returns the error text (and puts the switch back) when the server refuses.
  Future<String?> toggleProduct(String productId, bool on) async {
    _patch(productId, (p) => p.copyWith(available: on, busy: true));
    try {
      await _repo.setProductAvailable(productId, on);
      _patch(productId, (p) => p.copyWith(busy: false));
      return null;
    } catch (e) {
      _patch(productId, (p) => p.copyWith(available: !on, busy: false));
      return errorText(e, ref.read(stringsProvider));
    }
  }

  Future<String?> toggleVariant(String productId, String variantId, bool on) async {
    _patchVariant(productId, variantId, (v) => v.copyWith(available: on, busy: true));
    try {
      await _repo.setVariantAvailable(variantId, on);
      _patchVariant(productId, variantId, (v) => v.copyWith(busy: false));
      return null;
    } catch (e) {
      _patchVariant(productId, variantId, (v) => v.copyWith(available: !on, busy: false));
      return errorText(e, ref.read(stringsProvider));
    }
  }

  // the list may have been closed while a call was running
  void _patch(String productId, Product Function(Product) update) {
    if (!ref.mounted) return;
    updateWhere((p) => p.id == productId, update);
  }

  void _patchVariant(String productId, String variantId, ProductVariant Function(ProductVariant) update) {
    _patch(productId, (p) => p.copyWith(variants: [for (final v in p.variants) v.id == variantId ? update(v) : v]));
  }
}

final productsProvider = NotifierProvider.autoDispose.family<ProductsController, PagedState<Product>, ProductQuery>(ProductsController.new);

final productCategoriesProvider = FutureProvider.autoDispose<List<ProductCategory>>((ref) {
  ref.watch(userScopeProvider);
  return ref.watch(productsRepositoryProvider).categories();
});