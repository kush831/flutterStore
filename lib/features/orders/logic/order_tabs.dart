enum OrderTone { info, warning, success, danger }

class OrderSub {
  const OrderSub(this.status, this.labelKey);

  final String status; // sent as the `status` parameter
  final String labelKey;
}

/// The 7 tabs. `status` is the API value, `param` is the ?tab= value used by deep links.
enum OrderTab {
  newOrders('TODAY', 'new', 'orders_ordersscreen_tab_new', OrderTone.info, [
    OrderSub('TODAY', 'orders_ordersscreen_tab_today'),
    OrderSub('UPCOMING', 'orders_ordersscreen_tab_upcoming'),
  ]),
  preparing('ONGOING', 'ongoing', 'orders_ordersscreen_tab_preparing', OrderTone.warning, [
    OrderSub('PENDING_PROCESSING', 'orders_ordersscreen_filter_pending_process_title'),
    OrderSub('PICKUP_VERIFICATION', 'orders_ordersscreen_filter_pending_pickup_title'),
    OrderSub('ONTHEWAY', 'orders_ordersscreen_filter_on_the_way_title'),
  ]),
  ready('UPCOMING', 'upcoming', 'orders_ordersscreen_tab_ready', OrderTone.info),
  cancelled('CANCELLED', 'cancelled', 'orders_ordersscreen_past_cancelled_tab_title', OrderTone.danger),
  rejected('REJECTED', 'rejected', 'orders_ordersscreen_past_rejected_tab_title', OrderTone.danger),
  expired('EXPIRED', 'expired', 'orders_ordersscreen_past_auto_expired_tab_title', OrderTone.danger),
  completed('COMPLETED', 'completed', 'orders_ordersscreen_past_completed_tab_title', OrderTone.success);

  const OrderTab(this.status, this.param, this.labelKey, this.tone, [this.subs = const []]);

  final String status;
  final String param;
  final String labelKey;
  final OrderTone tone;
  final List<OrderSub> subs;

  static OrderTab fromParam(String? p) {
    for (final t in values) {
      if (t.param == p) return t;
    }
    return newOrders;
  }

  /// The colour of the status pill. It follows the TAB, not the translated status text.
  OrderTone toneFor(String selectedStatus) => (this == preparing && selectedStatus == 'ONTHEWAY') ? OrderTone.info : tone;
}