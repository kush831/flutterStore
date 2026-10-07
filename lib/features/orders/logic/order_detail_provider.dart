import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../data/order_detail_models.dart';
import '../data/orders_repository.dart';

/// One order by id. While it reloads the previous data stays on screen.
final orderDetailProvider = FutureProvider.autoDispose.family<OrderDetail, String>((ref, id) {
  ref.watch(userScopeProvider);
  return ref.watch(ordersRepositoryProvider).detail(id);
});