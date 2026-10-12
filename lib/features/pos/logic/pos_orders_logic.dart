import '../data/pos_catalog_models.dart';
import '../data/pos_orders_models.dart';
import '../data/pos_permission.dart';
import '../data/pos_sale_models.dart';

/// The tabs of the Orders screen, each with the status number the server filters by (All sends none).
enum PosOrdersTab {
  all(null, 'tab_all', 'empty_all'),
  news(kOrderNew, 'tab_new', 'empty_new'),
  processing(kOrderProcessing, 'tab_processing', 'empty_process'),
  ready(kOrderReady, 'tab_ready', 'empty_ready'),
  completed(kOrderCompleted, 'tab_completed', 'empty_completed'),
  cancelled(kOrderCancelled, 'tab_cancelled', 'empty_cancelled'),
  expired(kOrderExpired, 'tab_expired', 'empty_expired');

  const PosOrdersTab(this.status, this._tab, this._empty);

  final int? status;
  final String _tab;
  final String _empty;

  String get tabKey => 'pos_posordersscreen_$_tab';
  String get emptyKey => 'pos_posordersscreen_$_empty';
  String get emptySubKey => 'pos_posordersscreen_${_empty}_sub';

  /// `?tab=cancelled` in a link.
  static PosOrdersTab fromName(String? name) => PosOrdersTab.values.where((t) => t.name == name).firstOrNull ?? PosOrdersTab.all;
}

enum OrderTone { primary, cancelled, processing, ready, completed, expired }

/// The look of a status comes from its number, never from the words (which the server translates).
OrderTone toneOf(int status) => switch (status) {
  kOrderCancelled => OrderTone.cancelled,
  kOrderProcessing => OrderTone.processing,
  kOrderReady => OrderTone.ready,
  kOrderCompleted => OrderTone.completed,
  kOrderExpired => OrderTone.expired,
  _ => OrderTone.primary,
};

/// The text key for a status badge, or null for a status this app does not know (the server's own words are shown).
String? statusKey(int status) => switch (status) {
  kOrderNew => 'pos_posordersscreen_status_new',
  kOrderCancelled => 'pos_posordersscreen_status_cancelled',
  kOrderProcessing => 'pos_posordersscreen_status_processing',
  kOrderReady => 'pos_posordersscreen_status_ready',
  kOrderCompleted => 'pos_posordersscreen_status_completed',
  kOrderExpired => 'pos_posordersscreen_status_expired',
  _ => null,
};

/// "● Pos New Order" → "Pos New Order". The dot is drawn by the badge itself.
String stripBullet(String s) => s.replaceFirst(RegExp(r'^[\s●•·]+'), '').trim();

/// The text key for how an order was placed (Jetpack matches the server's order type).
String orderTypeKey(String type) => switch (type.trim().toLowerCase()) {
  'dine_in' || 'dinein' => 'pos_posordersscreen_type_dine_in',
  'take_away' || 'takeaway' => 'pos_posordersscreen_type_takeaway',
  'delivery' => 'pos_posordersscreen_type_delivery',
  'self_pickup' || 'pickup' => 'pos_posordersscreen_type_pickup',
  _ => 'pos_posordersscreen_type_pos',
};

/// The kitchen's pipeline: New → Processing → Ready → Completed. null = nothing comes after (or the order is closed).
int? nextStatus(int status) => switch (status) {
  kOrderNew => kOrderProcessing,
  kOrderProcessing => kOrderReady,
  kOrderReady => kOrderCompleted,
  _ => null,
};

String? nextActionKey(int status) => switch (status) {
  kOrderNew => 'pos_posorderdetailscreen_moveToPreparing',
  kOrderProcessing => 'pos_posorderdetailscreen_moveToReadyToDeliver',
  kOrderReady => 'pos_orderqueue_complete',
  _ => null,
};

/// Who may take the next step.
String? nextPermission(int status) => switch (status) {
  kOrderNew => PosPerm.ordersProcess,
  kOrderProcessing => PosPerm.ordersReady,
  kOrderReady => PosPerm.ordersComplete,
  _ => null,
};

/// Jetpack offers "Cancel Order" for a new or a processing order.
bool canCancel(int status) => status == kOrderNew || status == kOrderProcessing;

/// The three stages of the live queue.
const kQueueStatuses = [kOrderNew, kOrderProcessing, kOrderReady];

/// A finished order's lines as cart lines, for "New Order". The prices are the ones paid; the cart is priced again by the server.
List<({PosProduct product, PosVariant variant, List<PosModifierContent> modifiers, int qty})> reorderLines(PosReceipt r) => [
  for (final i in r.items)
    if (i.variantId.isNotEmpty && i.quantity > 0)
      (
      product: PosProduct(id: i.productId, name: i.name, price: i.price, variants: [PosVariant(id: i.variantId, productId: i.productId, title: i.variant, price: i.price)]),
      variant: PosVariant(id: i.variantId, productId: i.productId, title: i.variant, price: i.price),
      modifiers: [for (final o in i.options) PosModifierContent(id: o.id, title: o.name, price: o.amount)],
      qty: i.quantity,
      ),
];