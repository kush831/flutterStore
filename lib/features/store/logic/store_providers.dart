import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../data/store_models.dart';
import '../data/store_repository.dart';

/// The store's own profile, with its weekly timings.
final storeProfileProvider = FutureProvider.autoDispose<StoreProfile>((ref) {
  ref.watch(userScopeProvider);
  return ref.watch(storeRepositoryProvider).profile();
});