import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/paging.dart';
import '../data/order_models.dart';
import '../data/orders_repository.dart';

/// One list per API status ("TODAY", "ONGOING", "COMPLETED" …). Each keeps its pages while you switch tabs.
class OrdersController extends PagedNotifier<OrderItem> {
  OrdersController(this.status);

  final String status;

  @override
  PagedState<OrderItem> build() {
    ref.watch(userScopeProvider); // a sign-out throws the previous store's orders away
    return super.build();
  }

  @override
  Future<PageResult<OrderItem>> fetchPage(int page) => ref.read(ordersRepositoryProvider).page(status, page);
}

final ordersProvider = NotifierProvider.family<OrdersController, PagedState<OrderItem>, String>(OrdersController.new);