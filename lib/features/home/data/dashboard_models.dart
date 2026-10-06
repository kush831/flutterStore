import '../../../core/network/json_reader.dart';

class DashboardData {
  const DashboardData({
    required this.storeName,
    this.profileImage = '',
    this.currency = '',
    this.isOpen = false,
    this.orderExpireTime = 0,
    this.membershipEnabled = false,
    this.subscriptionActive = false,
    this.subscriptionMessage = '',
    this.pending = 0,
    this.inProgress = 0,
    this.completed = 0,
    this.outOfStock = 0,
    this.lowStock = 0,
    this.salesToday = '',
    this.salesWeek = '',
    this.salesMonth = '',
  });

  final String storeName;
  final String profileImage;
  final String currency;
  final bool isOpen;

  /// Minutes an order may stay unanswered (used by the Orders screens).
  final int orderExpireTime;
  final bool membershipEnabled;
  final bool subscriptionActive;
  final String subscriptionMessage;
  final int pending;
  final int inProgress;
  final int completed;
  final int outOfStock;
  final int lowStock;
  final String salesToday;
  final String salesWeek;
  final String salesMonth;

  bool get membershipNeeded => membershipEnabled && !subscriptionActive;

  DashboardData copyWith({bool? isOpen}) => DashboardData(
    storeName: storeName,
    profileImage: profileImage,
    currency: currency,
    isOpen: isOpen ?? this.isOpen,
    orderExpireTime: orderExpireTime,
    membershipEnabled: membershipEnabled,
    subscriptionActive: subscriptionActive,
    subscriptionMessage: subscriptionMessage,
    pending: pending,
    inProgress: inProgress,
    completed: completed,
    outOfStock: outOfStock,
    lowStock: lowStock,
    salesToday: salesToday,
    salesWeek: salesWeek,
    salesMonth: salesMonth,
  );

  factory DashboardData.fromJson(JsonReader root) {
    final d = root.sub('data');
    final s = d.sub('storeDetails');
    final sub = s.sub('subscriptionDetails');
    final orders = d.sub('orderCounts');
    final stock = d.sub('stockCounts');
    final sales = d.sub('salesSummary');
    return DashboardData(
      storeName: s.text('name'),
      profileImage: s.text('profileImage'),
      currency: sales.str('currency') ?? s.text('currency'),
      isOpen: s.flag('isOpen'),
      orderExpireTime: s.integer('orderExpireTime') ?? 0,
      membershipEnabled: s.flag('isMembershipEnable'),
      subscriptionActive: sub.flag('isActive'),
      subscriptionMessage: sub.text('message'),
      pending: orders.integer('pending') ?? 0,
      inProgress: orders.integer('process') ?? 0,
      completed: orders.integer('completed') ?? 0,
      outOfStock: stock.integer('outOfStock') ?? 0,
      lowStock: stock.integer('lowStock') ?? 0,
      salesToday: sales.text('today'),
      salesWeek: sales.text('thisWeek'),
      salesMonth: sales.text('thisMonth'),
    );
  }
}

class BusinessSummary {
  const BusinessSummary({
    this.products = '',
    this.orders = '',
    this.orderAmount = '',
    this.merchantEarning = '',
    this.storeEarning = '',
  });

  final String products;
  final String orders;
  final String orderAmount;
  final String merchantEarning;
  final String storeEarning;

  factory BusinessSummary.fromJson(JsonReader root) {
    final b = root.sub('data').sub('responseData').sub('businessSummary');
    return BusinessSummary(
      products: b.text('products'),
      orders: b.text('orders'),
      orderAmount: b.text('orderAmount'),
      merchantEarning: b.text('merchantEarning'),
      storeEarning: b.text('storeEarning'),
    );
  }
}