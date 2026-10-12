import '../../../core/network/json_reader.dart';
import '../logic/pos_shift_logic.dart' show posNum;

/// The numbers the server uses for an order's status.
const kOrderNew = 1;
const kOrderCancelled = 2;
const kOrderProcessing = 6;
const kOrderReady = 7;
const kOrderCompleted = 11;
const kOrderExpired = 12;

/// One order in the list.
class PosOrderRow {
  const PosOrderRow({
    required this.orderId,
    this.orderNumber = '',
    this.status = 0,
    this.statusText = '',
    this.date = '',
    this.orderType = '',
    this.table = '',
    this.customerName = '',
    this.customerPhone = '',
    this.paymentMethod = '',
    this.quantity = 0,
    this.cartAmount = '',
    this.finalAmount = '',
    this.sessionId = '',
  });

  final String orderId;
  final String orderNumber;
  final int status;
  final String statusText;
  final String date;
  final String orderType;
  final String table;
  final String customerName;
  final String customerPhone;
  final String paymentMethod;
  final int quantity;
  final String cartAmount;
  final String finalAmount;
  final String sessionId;

  /// What was paid; Jetpack falls back to the cart amount when there is no paid amount.
  double get amount => posNum(finalAmount.trim().isNotEmpty ? finalAmount : cartAmount);

  factory PosOrderRow.fromJson(JsonReader r) => PosOrderRow(
    orderId: r.text('orderId'),
    orderNumber: r.text('orderNumber'),
    status: r.integer('orderStatus') ?? 0,
    statusText: r.text('orderStatusText'),
    date: r.text('orderDate'),
    orderType: r.text('posOrderType'),
    table: r.text('posTableNumber'),
    customerName: r.text('posCustomerName'),
    customerPhone: r.text('posCustomerPhone'),
    paymentMethod: r.text('paymentMethod'),
    quantity: r.integer('quantity') ?? 0,
    cartAmount: r.text('cartAmount'),
    finalAmount: r.text('finalAmountPaid'),
    sessionId: r.text('posSessionId'),
  );
}