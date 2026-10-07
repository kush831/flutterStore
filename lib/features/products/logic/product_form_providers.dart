import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../data/product_form_models.dart';
import '../data/products_repository.dart';

/// The step-1 form data. `''` = a new product.
final productFormDataProvider = FutureProvider.autoDispose.family<ProductFormData, String>((ref, productId) {
  ref.watch(userScopeProvider);
  return ref.watch(productsRepositoryProvider).formData(productId);
});

final subCategoriesProvider = FutureProvider.autoDispose.family<List<FormOption>, int>(
      (ref, categoryId) => ref.watch(productsRepositoryProvider).subCategories(categoryId),
);