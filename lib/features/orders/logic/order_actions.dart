import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/logic/dashboard_controller.dart';
import '../data/driver_models.dart';
import '../data/order_detail_models.dart';
import '../data/orders_repository.dart';
import 'order_detail_provider.dart';
import 'orders_controller.dart';

/// The server's button names that this app can run.
abstract final class OrderActions {
  static const accept = 'ACCEPT';
  static const reject = 'REJECT';
  static const process = 'PROCESS';
  static const ready = 'ORDER_READY';
  static const deliver = 'DELIVER';
  static const assign = 'ASSIGN';
  static const pickup = 'PICKUP_VERIFICATION';
  // internal names for the two assign flavours (the server button is just ASSIGN)
  static const autoAssign = 'AUTO_ASSIGN';
  static const manualAssign = 'MANUAL_ASSIGN';

  static String normalize(String a) => a.trim().toUpperCase();
  static bool isPickup(String a) => normalize(a).contains(pickup);
  static bool isReject(String a) => normalize(a) == reject;

  static bool isKnown(String a) {
    final n = normalize(a);
    return n == accept || n == reject || n == process || n == ready || n == deliver || n == assign || isPickup(n);
  }

  /// What to show: no "CALL" buttons (they are on the cards), nothing this app cannot run.
  static List<OrderAction> visible(List<OrderAction> all) {
    final out = <OrderAction>[];
    for (final a in all) {
      final n = normalize(a.action);
      if (n.contains('CALL')) continue;
      if (!isKnown(n)) {
        if (kDebugMode) debugPrint('Order action not supported yet: ${a.action}');
        continue;
      }
      out.add(a);
    }
    return out;
  }

  /// Is [busy] (the running action) the one behind this button?
  static bool isBusyFor(String? busy, String buttonAction) {
    if (busy == null) return false;
    final n = normalize(buttonAction);
    return busy == n || (n == assign && (busy == autoAssign || busy == manualAssign)) || (isPickup(n) && busy == pickup);
  }
}

/// state = the action that is running right now, or null. Only one at a time.
class OrderActionsController extends Notifier<String?> {
  @override
  String? build() => null;

  OrdersRepository get _repo => ref.read(ordersRepositoryProvider);

  /// Runs one action and returns the server's message. Throws AppException with the server's message on a refusal.
  Future<String> perform(String orderId, String action, {String otp = '', List<int> driverIds = const []}) async {
    if (state != null) throw StateError('Another action is running');
    state = action;
    try {
      final message = switch (action) {
        OrderActions.accept => await _repo.accept(orderId),
        OrderActions.reject => await _repo.reject(orderId),
        OrderActions.process => await _repo.process(orderId),
        OrderActions.ready => await _repo.ready(orderId),
        OrderActions.deliver => await _repo.deliver(orderId),
        OrderActions.autoAssign => await _repo.autoAssign(orderId),
        OrderActions.manualAssign => await _repo.manualAssign(orderId, driverIds),
        OrderActions.pickup => await _repo.verifyPickup(orderId, otp),
        _ => throw StateError('Unknown order action $action'),
      };
      _afterSuccess(orderId, action);
      return message;
    } finally {
      state = null;
    }
  }

  void _afterSuccess(String orderId, String action) {
    // Step 24: stop this order's alarm after Accept, Reject and Assign (OrderAlarm.stop(orderId))
    ref.invalidate(orderDetailProvider(orderId)); // new buttons, new status
    ref.invalidate(ordersProvider); // the order moves between tabs
    ref.read(dashboardProvider.notifier).refresh(); // the counters on Home
  }
}

final orderActionsProvider = NotifierProvider.autoDispose<OrderActionsController, String?>(OrderActionsController.new);

/// The drivers that can take this order.
final driversProvider = FutureProvider.autoDispose.family<List<Driver>, String>(
      (ref, orderId) => ref.watch(ordersRepositoryProvider).drivers(orderId),
);