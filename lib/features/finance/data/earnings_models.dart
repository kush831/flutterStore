import '../../../core/network/json_reader.dart';

class EarningOrder {
  const EarningOrder({
    required this.orderId,
    this.storeEarning = '',
    this.merchantEarning = '',
    this.orderAmount = '',
    this.cartAmount = '',
    this.tax = '',
    this.deliveryCharges = '',
    this.otherCharges = '',
    this.createdAt = '',
  });

  final String orderId;
  final String storeEarning;
  final String merchantEarning;
  final String orderAmount;
  final String cartAmount;
  final String tax;
  final String deliveryCharges;
  final String otherCharges;
  final String createdAt;

  /// "2026-10-10 10:42:00" → a date, or null when the server wrote something else.
  DateTime? get createdDate => DateTime.tryParse(createdAt.trim().replaceFirst(' ', 'T'));

  factory EarningOrder.fromJson(JsonReader r) => EarningOrder(
    orderId: r.text('orderId'),
    storeEarning: r.text('storeEarning'),
    merchantEarning: r.text('merchantEarning'),
    orderAmount: r.text('orderAmount'),
    cartAmount: r.text('cartAmount'),
    tax: r.text('tax'),
    deliveryCharges: r.text('deliveryCharges'),
    otherCharges: r.text('otherCharges'),
    createdAt: r.text('createdAt'),
  );
}

class EarningsSummary {
  const EarningsSummary({this.totalOrders = 0, this.orderAmount = '', this.merchantEarning = '', this.storeEarning = '', this.currency = ''});

  final int totalOrders;
  final String orderAmount;
  final String merchantEarning;
  final String storeEarning;
  final String currency;
}

/// One page of the earnings API: the period's summary (the same on every page) and this page's orders.
class EarningsPage {
  const EarningsPage({required this.summary, required this.orders, required this.next});

  final EarningsSummary summary;
  final List<EarningOrder> orders;
  final int? next;

  factory EarningsPage.fromJson(JsonReader root, int page, int? Function(int page, String? nextUrl, bool gotItems) nextPageOf) {
    final b = root.sub('data').sub('responseData').sub('businessSummary');
    final orders = [for (final o in b.list('orders', EarningOrder.fromJson)) if (o.orderId.isNotEmpty) o];
    return EarningsPage(
      summary: EarningsSummary(
        totalOrders: b.integer('totalOrders') ?? 0,
        orderAmount: b.text('orderAmount'),
        merchantEarning: b.text('merchantEarning'),
        storeEarning: b.text('storeEarning'),
        currency: b.text('currency'),
      ),
      orders: orders,
      next: nextPageOf(page, b.str('nextPageUrl'), orders.isNotEmpty),
    );
  }
}