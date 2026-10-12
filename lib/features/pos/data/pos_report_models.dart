import '../../../core/network/json_reader.dart';
import 'pos_orders_models.dart';

/// A revenue figure with its growth, as the server writes it ("₹1,234.50", "+12.5%").
class PosRevenueSummary {
  const PosRevenueSummary({this.revenue = '', this.revenueRaw = 0, this.revenueGrowth = '', this.orders = 0, this.ordersGrowth = '', this.avgTicket = '', this.avgTicketGrowth = ''});

  final String revenue;
  final double revenueRaw;
  final String revenueGrowth;
  final int orders;
  final String ordersGrowth;
  final String avgTicket;
  final String avgTicketGrowth;

  factory PosRevenueSummary.fromJson(JsonReader r) => PosRevenueSummary(
    revenue: r.text('revenue'),
    revenueRaw: r.number('revenueRaw') ?? 0,
    revenueGrowth: r.text('revenueGrowth'),
    orders: r.integer('orders') ?? 0,
    ordersGrowth: r.text('ordersGrowth'),
    avgTicket: r.text('avgTicket'),
    avgTicketGrowth: r.text('avgTicketGrowth'),
  );
}

class PosHourlySlot {
  const PosHourlySlot({this.hour = 0, this.label = '', this.revenue = '', this.revenueRaw = 0, this.orders = 0});

  final int hour;
  final String label;
  final String revenue;
  final double revenueRaw;
  final int orders;

  factory PosHourlySlot.fromJson(JsonReader r) => PosHourlySlot(hour: r.integer('hour') ?? 0, label: r.text('label'), revenue: r.text('revenue'), revenueRaw: double.tryParse(r.text('revenueRaw').replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? (r.number('revenueRaw') ?? 0), orders: r.integer('orders') ?? 0);
}

class PosPeakHours {
  const PosPeakHours({this.peakHour = '', this.peakRevenue = '', this.hourly = const []});

  final String peakHour;
  final String peakRevenue;
  final List<PosHourlySlot> hourly;

  factory PosPeakHours.fromJson(JsonReader r) => PosPeakHours(peakHour: r.text('peakHour'), peakRevenue: r.text('peakRevenue'), hourly: r.list('hourlyBreakdown', PosHourlySlot.fromJson));
}

class PosCategoryPerformance {
  const PosCategoryPerformance({this.id = '', this.name = '', this.revenue = '', this.revenueRaw = 0, this.percentage = '', this.growth = '', this.isPositive = true});

  final String id;
  final String name;
  final String revenue;
  final double revenueRaw;
  final String percentage; // "37.5% of gross"
  final String growth;
  final bool isPositive;

  factory PosCategoryPerformance.fromJson(JsonReader r) => PosCategoryPerformance(
    id: r.text('categoryId'),
    name: r.text('categoryName'),
    revenue: r.text('revenue'),
    revenueRaw: double.tryParse(r.text('revenueRaw').replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? 0,
    percentage: r.text('percentage'),
    growth: r.text('growth'),
    isPositive: r.has('isPositive') ? r.flag('isPositive') : true,
  );
}

class PosBestItem {
  const PosBestItem({this.id = '', this.name = '', this.category = '', this.totalSold = '', this.revenue = '', this.revenueRaw = 0, this.growth = '', this.isPositive = true});

  final String id;
  final String name;
  final String category;
  final String totalSold;
  final String revenue;
  final double revenueRaw;
  final String growth;
  final bool isPositive;

  factory PosBestItem.fromJson(JsonReader r) => PosBestItem(
    id: r.text('productId'),
    name: r.text('productName'),
    category: r.text('categoryName'),
    totalSold: r.text('totalSold'),
    revenue: r.text('revenue'),
    revenueRaw: double.tryParse(r.text('revenueRaw').replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? 0,
    growth: r.text('growth'),
    isPositive: r.has('isPositive') ? r.flag('isPositive') : true,
  );
}

class PosStaffRank {
  const PosStaffRank({this.staffId = '', this.name = '', this.orders = 0, this.avgOrder = '', this.revenue = '', this.revenueRaw = 0});

  final String staffId;
  final String name;
  final int orders;
  final String avgOrder;
  final String revenue;
  final double revenueRaw;

  factory PosStaffRank.fromJson(JsonReader r) => PosStaffRank(
    staffId: r.text('staffId'),
    name: r.text('staffName'),
    orders: r.integer('totalOrders') ?? 0,
    avgOrder: r.text('avgOrder'),
    revenue: r.text('totalRevenue'),
    revenueRaw: double.tryParse(r.text('totalRevenueRaw').replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? 0,
  );
}

class PosPaymentShare {
  const PosPaymentShare({this.id = '', this.name = '', this.orders = 0, this.amount = '', this.amountRaw = 0, this.percentage = 0, this.percentageText = ''});

  final String id;
  final String name;
  final int orders;
  final String amount;
  final double amountRaw;
  final double percentage;
  final String percentageText;

  factory PosPaymentShare.fromJson(JsonReader r) => PosPaymentShare(
    id: r.text('paymentMethodId'),
    name: r.text('paymentMethodName'),
    orders: r.integer('totalOrders') ?? 0,
    amount: r.text('totalAmount'),
    amountRaw: double.tryParse(r.text('totalAmountRaw').replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? 0,
    percentage: r.number('percentage') ?? 0,
    percentageText: r.text('percentageText'),
  );
}

class PosPaymentSplit {
  const PosPaymentSplit({this.totalAmount = '', this.breakdown = const []});

  final String totalAmount;
  final List<PosPaymentShare> breakdown;

  factory PosPaymentSplit.fromJson(JsonReader r) => PosPaymentSplit(totalAmount: r.text('totalAmount'), breakdown: r.list('breakdown', PosPaymentShare.fromJson));
}

class PosOrderQueue {
  const PosOrderQueue({this.waiting = 0, this.preparing = 0, this.ready = 0, this.total = 0});

  final int waiting;
  final int preparing;
  final int ready;
  final int total;

  factory PosOrderQueue.fromJson(JsonReader r) => PosOrderQueue(waiting: r.integer('waiting') ?? 0, preparing: r.integer('preparing') ?? 0, ready: r.integer('ready') ?? 0, total: r.integer('total') ?? 0);
}

class PosShiftSummary {
  const PosShiftSummary({this.openingCash = '', this.currentCash = '', this.transactions = 0, this.expectedCash = '', this.actualCash = '', this.status = '', this.loginAt = '', this.logoutAt = ''});

  final String openingCash;
  final String currentCash;
  final int transactions;
  final String expectedCash;
  final String actualCash;
  final String status;
  final String loginAt;
  final String logoutAt;

  factory PosShiftSummary.fromJson(JsonReader r) => PosShiftSummary(
    openingCash: r.text('openingCash'),
    currentCash: r.text('currentCash'),
    transactions: r.integer('transactions') ?? 0,
    expectedCash: r.text('expectedCash'),
    actualCash: r.text('actualCash'),
    status: r.text('sessionStatus'),
    loginAt: r.text('sessionLoginAt'),
    logoutAt: r.text('sessionLogoutAt'),
  );
}

/// The whole report: one answer feeds the Dashboard and Analytics.
class PosReport {
  const PosReport({
    this.period = '',
    this.revenue = const PosRevenueSummary(),
    this.peak = const PosPeakHours(),
    this.categories = const [],
    this.bestItems = const [],
    this.staff = const [],
    this.payments = const PosPaymentSplit(),
    this.queue = const PosOrderQueue(),
    this.shift,
    this.recentOrders = const [],
  });

  final String period;
  final PosRevenueSummary revenue;
  final PosPeakHours peak;
  final List<PosCategoryPerformance> categories;
  final List<PosBestItem> bestItems;
  final List<PosStaffRank> staff;
  final PosPaymentSplit payments;
  final PosOrderQueue queue;
  final PosShiftSummary? shift;
  final List<PosOrderRow> recentOrders;

  /// Nothing to show: no orders and no breakdown.
  bool get isEmpty => revenue.orders == 0 && revenue.revenueRaw == 0 && categories.isEmpty && bestItems.isEmpty && payments.breakdown.isEmpty && staff.isEmpty && peak.hourly.isEmpty;

  factory PosReport.fromJson(JsonReader root) {
    final d = root.sub('data');
    return PosReport(
      period: d.text('period'),
      revenue: PosRevenueSummary.fromJson(d.sub('revenueSummary')),
      peak: PosPeakHours.fromJson(d.sub('peakHours')),
      categories: d.list('categoryPerformance', PosCategoryPerformance.fromJson),
      bestItems: d.list('bestSellingItems', PosBestItem.fromJson),
      staff: d.list('staffLeaderboard', PosStaffRank.fromJson),
      payments: PosPaymentSplit.fromJson(d.sub('paymentMethodsSplit')),
      queue: PosOrderQueue.fromJson(d.sub('orderQueue')),
      shift: d.has('shiftSummary') ? PosShiftSummary.fromJson(d.sub('shiftSummary')) : null,
      recentOrders: [for (final o in d.list('recentOrders', PosOrderRow.fromJson)) if (o.orderId.isNotEmpty) o],
    );
  }
}