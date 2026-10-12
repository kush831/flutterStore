import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/end_points.dart';
import '../logic/pos_auth.dart';
import 'pos_catalog_models.dart';

class PosCatalogRepository {
  PosCatalogRepository(this._api);

  final ApiClient _api;

  Future<List<PosCategory>> categories() async {
    final root = await _api.postForm(EndPoints.posCategories);
    return [for (final c in root.list('data', PosCategory.fromJson)) if (c.id.isNotEmpty) c];
  }

  Future<List<PosCategory>> subcategories(String categoryId) async {
    final root = await _api.postForm(EndPoints.posSubCategories, {'category_id': categoryId});
    return [for (final c in root.list('data', PosCategory.fromJson)) if (c.id.isNotEmpty) c];
  }

  /// A page of products. An empty [categoryId] is the "All" list (the server wants filter = ALL for it).
  Future<({List<PosProduct> items, int? next})> products({required String segmentId, required String categoryId, required String subCategoryId, required int page}) async {
    final root = await _api.postForm(EndPoints.posProducts, {
      'category_id': categoryId,
      'segment_id': segmentId,
      'page': page,
      'sub_category_id': subCategoryId,
      'filter': categoryId.isEmpty ? 'ALL' : '',
    });
    final d = root.sub('data');
    final items = [for (final p in d.list('list', (r) => PosProduct.fromJson(r, categoryId: categoryId))) if (p.id.isNotEmpty) p];
    final more = d.sub('pagination').flag('hasMore');
    return (items: items, next: (more && items.isNotEmpty) ? page + 1 : null);
  }
  Future<PosSearchResult> search(String keyword) async => PosSearchResult.fromJson((await _api.postForm(EndPoints.posSearch, {'keyword': keyword.trim()})).sub('data'));

  Future<PosProductDetail> productDetail(String productId) async => PosProductDetail.fromJson(await _api.postForm(EndPoints.posProductDetail, {'product_id': productId}));
}

final posCatalogRepositoryProvider = Provider<PosCatalogRepository>((ref) => PosCatalogRepository(ref.watch(posApiProvider)));
