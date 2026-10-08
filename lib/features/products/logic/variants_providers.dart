import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../data/products_repository.dart';
import '../data/variant_models.dart';

final variantsProvider = FutureProvider.autoDispose.family<VariantsData, String>((ref, productId) {
  ref.watch(userScopeProvider);
  return ref.watch(productsRepositoryProvider).variantsData(productId);
});

final stockProvider = FutureProvider.autoDispose.family<StockData, String>((ref, productId) {
  ref.watch(userScopeProvider);
  return ref.watch(productsRepositoryProvider).stockData(productId);
});