import '../../../core/network/json_reader.dart';
import 'pos_checkout_models.dart';

/// What the server answers when an order is placed.
class PosPlacedOrder {
  const PosPlacedOrder({required this.orderId, this.orderNumber = '', this.status = 0, this.sentToKitchen = false, this.message = ''});

  final String orderId;
  final String orderNumber;
  final int status;
  final bool sentToKitchen;
  final String message;

  factory PosPlacedOrder.fromJson(JsonReader root) {
    final d = root.sub('data');
    return PosPlacedOrder(orderId: d.text('orderId'), orderNumber: d.text('orderNumber'), status: d.integer('orderStatus') ?? 0, sentToKitchen: d.flag('posKitchenDisplay'), message: root.text('message'));
  }
}

class PosReceiptOption {
  const PosReceiptOption({this.id = '', this.name = '', this.amount = ''});

  final String id;
  final String name;
  final String amount;

  factory PosReceiptOption.fromJson(JsonReader r) => PosReceiptOption(id: r.text('id'), name: r.text('optionName'), amount: r.text('amount'));
}

class PosReceiptItem {
  const PosReceiptItem({this.productId = '', this.variantId = '', this.name = '', this.variant = '', this.quantity = 0, this.price = '', this.total = '', this.options = const []});

  final String productId;
  final String variantId;
  final String name;
  final String variant;
  final int quantity;
  final String price;
  final String total;
  final List<PosReceiptOption> options;

  factory PosReceiptItem.fromJson(JsonReader r) => PosReceiptItem(
    productId: r.text('productId'),
    variantId: r.text('productVariantId'),
    name: r.text('productName'),
    variant: r.text('variantName'),
    quantity: r.integer('quantity') ?? 0,
    price: r.text('price'),
    total: r.text('totalAmount'),
    options: r.list('options', PosReceiptOption.fromJson),
  );
}

/// One entry of an order's timeline: the status, when, and where.
class PosTimelineStep {
  const PosTimelineStep({this.time = '', this.value = '', this.location = ''});

  final String time;
  final String value;
  final String location;

  factory PosTimelineStep.fromJson(JsonReader r) => PosTimelineStep(time: r.text('statusTime'), value: r.text('statusValue'), location: r.text('location'));
}

/// A placed order: the receipt and the order detail screen both read it (the server's `get-order-detail`).
class PosReceipt {
  const PosReceipt({
    required this.orderId,
    this.orderNumber = '',
    this.status = 0,
    this.statusText = '',
    this.paymentStatus = '',
    this.date = '',
    this.orderType = '',
    this.serviceType = '',
    this.table = '',
    this.customerName = '',
    this.customerPhone = '',
    this.paymentMethod = '',
    this.currency = '',
    this.cashier = '',
    this.terminal = '',
    this.sessionId = '',
    this.items = const [],
    this.bill = const [],
    this.timeline = const [],
  });

  final String orderId;
  final String orderNumber;
  final int status;
  final String statusText;
  final String paymentStatus;
  final String date;
  final String orderType;
  final String serviceType;
  final String table;
  final String customerName;
  final String customerPhone;
  final String paymentMethod;
  final String currency;
  final String cashier;
  final String terminal;
  final String sessionId;
  final List<PosReceiptItem> items;
  final List<PosBillRow> bill;
  final List<PosTimelineStep> timeline;

  factory PosReceipt.fromJson(JsonReader root) {
    final d = root.sub('data');
    return PosReceipt(
      orderId: d.text('orderId'),
      orderNumber: d.text('orderNumber'),
      status: d.integer('orderStatus') ?? 0,
      statusText: d.text('orderStatusText'),
      paymentStatus: d.text('paymentStatus'),
      date: d.text('orderDate'),
      orderType: d.text('posOrderType'),
      serviceType: d.text('serviceType'),
      table: d.text('posTableNumber'),
      customerName: d.text('posCustomerName'),
      customerPhone: d.text('posCustomerPhone'),
      paymentMethod: d.text('paymentMethod'),
      currency: d.text('currency'),
      cashier: d.sub('staffDetails').text('staffName'),
      terminal: d.text('terminalName'),
      sessionId: d.text('posSessionId'),
      items: d.list('products', PosReceiptItem.fromJson),
      bill: d.list('billDetails', PosBillRow.fromJson),
      timeline: d.list('orderStatusDetails', PosTimelineStep.fromJson),
    );
  }
}

/// The sale that was just paid, kept in memory for the success screen and the receipt
/// (the server's order record does not keep the cash tendered or the change).
class PosLastSale {
  const PosLastSale({required this.orderId, this.orderNumber = '', this.methodName = '', this.cashReceived, this.changeDue, this.totalText = '', this.customerPhone = ''});

  final String orderId;
  final String orderNumber;
  final String methodName;
  final double? cashReceived; // null unless the customer paid in cash
  final double? changeDue;
  final String totalText;
  final String customerPhone;
}