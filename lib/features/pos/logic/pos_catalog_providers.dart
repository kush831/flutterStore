import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/paging.dart';
import '../data/pos_catalog_models.dart';
import '../data/pos_catalog_repository.dart';
import 'pos_auth.dart';

/// Segment 3 is food (Jetpack: `segmentId == 3`). Every other segment sells like a grocery.
final posIsFoodProvider = Provider<bool>((ref) => ref.watch(posAuthProvider.select((s) => s.staff?.business.segmentId == '3')));

final posCategoriesProvider = FutureProvider.autoDispose<List<PosCategory>>((ref) {
  ref.watch(posScopeProvider);
  return ref.watch(posCatalogRepositoryProvider).categories();
});

final posSubcategoriesProvider = FutureProvider.autoDispose.family<List<PosCategory>, String>((ref, categoryId) {
  ref.watch(posScopeProvider);
  return ref.watch(posCatalogRepositoryProvider).subcategories(categoryId);
});

/// Which list of products: a category (empty = All) and a sub-category (empty = the whole category).
@immutable
class PosProductsKey {
  const PosProductsKey(this.categoryId, [this.subCategoryId = '']);

  final String categoryId;
  final String subCategoryId;

  @override
  bool operator ==(Object other) => other is PosProductsKey && other.categoryId == categoryId && other.subCategoryId == subCategoryId;

  @override
  int get hashCode => Object.hash(categoryId, subCategoryId);
}

class PosProductsController extends PagedNotifier<PosProduct> {
  PosProductsController(this.key);

  final PosProductsKey key;

  @override
  PagedState<PosProduct> build() {
    ref.watch(posScopeProvider);
    return super.build();
  }

  @override
  Future<PageResult<PosProduct>> fetchPage(int page) async {
    final segment = ref.read(posAuthProvider).staff?.business.segmentId ?? '';
    final r = await ref.read(posCatalogRepositoryProvider).products(segmentId: segment, categoryId: key.categoryId, subCategoryId: key.subCategoryId, page: page);
    return PageResult(r.items, r.next);
  }
}

final posProductsProvider = NotifierProvider.autoDispose.family<PosProductsController, PagedState<PosProduct>, PosProductsKey>(PosProductsController.new);

/// One search. The screen waits for the typing to pause (400 ms) before it asks for a new keyword.
final posSearchResultsProvider = FutureProvider.autoDispose.family<PosSearchResult, String>((ref, keyword) {
  ref.watch(posScopeProvider);
  return ref.watch(posCatalogRepositoryProvider).search(keyword);
});

final posProductDetailProvider = FutureProvider.autoDispose.family<PosProductDetail, String>((ref, productId) {
  ref.watch(posScopeProvider);
  return ref.watch(posCatalogRepositoryProvider).productDetail(productId);
});