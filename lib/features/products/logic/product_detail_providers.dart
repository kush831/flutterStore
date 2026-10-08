import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../data/product_detail_models.dart';
import '../data/products_repository.dart';

final productDetailProvider = FutureProvider.autoDispose.family<ProductDetail, String>((ref, id) {
  ref.watch(userScopeProvider);
  return ref.watch(productsRepositoryProvider).detail(id);
});

final mappingOptionsProvider = FutureProvider.autoDispose.family<List<OptionGroup>, String>((ref, productId) {
  ref.watch(userScopeProvider);
  return ref.watch(productsRepositoryProvider).mappingOptions(productId);
});