import '../../../core/time/period_range.dart';
import '../../finance/data/earnings_models.dart';

enum AnalyticsPeriod { daily, weekly, monthly }

/// One bar of the chart: a day, a block of 7 days, or a calendar month.
class BucketRange {
  const BucketRange(this.start, this.end);

  final DateTime start;
  final DateTime end;

  PeriodRange get range => PeriodRange.custom(start, end);
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// The bars, oldest first. Daily: 7 days. Weekly: 5 blocks of 7 days ending today. Monthly: 12 calendar months (this one up to today).
List<BucketRange> analyticsBuckets(AnalyticsPeriod p, DateTime now) {
  final today = _day(now);
  switch (p) {
    case AnalyticsPeriod.daily:
      return [
        for (var i = 6; i >= 0; i--) () {
          final d = DateTime(today.year, today.month, today.day - i);
          return BucketRange(d, d);
        }(),
      ];
    case AnalyticsPeriod.weekly:
      return [
        for (var w = 4; w >= 0; w--) () {
          final end = DateTime(today.year, today.month, today.day - 7 * w);
          return BucketRange(DateTime(end.year, end.month, end.day - 6), end);
        }(),
      ];
    case AnalyticsPeriod.monthly:
      return [
        for (var m = 11; m >= 0; m--) () {
          final first = DateTime(today.year, today.month - m, 1);
          final last = m == 0 ? today : DateTime(first.year, first.month + 1, 0);
          return BucketRange(first, last);
        }(),
      ];
  }
}

/// The period of the same length right before the bars. The changes (▲ ▼) compare against it.
BucketRange previousBuckets(AnalyticsPeriod p, DateTime now) {
  final today = _day(now);
  switch (p) {
    case AnalyticsPeriod.daily:
      return BucketRange(DateTime(today.year, today.month, today.day - 13), DateTime(today.year, today.month, today.day - 7));
    case AnalyticsPeriod.weekly:
      return BucketRange(DateTime(today.year, today.month, today.day - 69), DateTime(today.year, today.month, today.day - 35));
    case AnalyticsPeriod.monthly:
      return BucketRange(DateTime(today.year, today.month - 23, 1), DateTime(today.year, today.month - 11, 0)); // the last day of the month 12 months ago
  }
}

/// "₹ 1,234.50" → 1234.5. A value it cannot read is 0.
double parseAmount(String s) => double.tryParse(s.replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? 0;

/// A number as text for the money formatter: no ".00" when it is whole.
String amountText(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

/// Percent change from [previous] to [current]. null when there is nothing to compare with.
double? pctChange(double current, double previous) {
  if (previous == 0) return null;
  return (current - previous) / previous * 100;
}

class Totals {
  const Totals({this.orders = 0, this.revenue = 0, this.store = 0, this.merchant = 0});

  final int orders;
  final double revenue;
  final double store;
  final double merchant;

  double get avgOrder => orders > 0 ? revenue / orders : 0;

  /// The store's share of the revenue, in percent.
  double get storeRate => revenue > 0 ? store / revenue * 100 : 0;

  factory Totals.fromSummary(EarningsSummary s) =>
      Totals(orders: s.totalOrders, revenue: parseAmount(s.orderAmount), store: parseAmount(s.storeEarning), merchant: parseAmount(s.merchantEarning));

  factory Totals.sum(Iterable<Totals> all) => Totals(
    orders: all.fold(0, (a, t) => a + t.orders),
    revenue: all.fold(0.0, (a, t) => a + t.revenue),
    store: all.fold(0.0, (a, t) => a + t.store),
    merchant: all.fold(0.0, (a, t) => a + t.merchant),
  );
}

class AnalyticsData {
  const AnalyticsData({required this.period, required this.ranges, required this.buckets, required this.current, required this.previous, required this.currency});

  final AnalyticsPeriod period;
  final List<BucketRange> ranges;
  final List<Totals> buckets; // one per bar, in the same order as [ranges]
  final Totals current;
  final Totals previous;
  final String currency;

  /// The bar with the most revenue, or -1 when there is no revenue at all.
  int get bestIndex {
    var best = -1;
    var max = 0.0;
    for (var i = 0; i < buckets.length; i++) {
      if (buckets[i].revenue > max) {
        max = buckets[i].revenue;
        best = i;
      }
    }
    return best;
  }

  double? get revenueChange => pctChange(current.revenue, previous.revenue);
  double? get ordersChange => pctChange(current.orders.toDouble(), previous.orders.toDouble());
  double? get avgOrderChange => pctChange(current.avgOrder, previous.avgOrder);
  double? get storeRateChange => pctChange(current.storeRate, previous.storeRate);
}

/// [summaries] are the bars' totals in the order of [ranges]; [previous] is the period before them.
AnalyticsData buildAnalytics({
  required AnalyticsPeriod period,
  required List<BucketRange> ranges,
  required List<EarningsSummary> summaries,
  required EarningsSummary previous,
}) {
  final totals = [for (final s in summaries) Totals.fromSummary(s)];
  final currency = [for (final s in [...summaries, previous]) if (s.currency.isNotEmpty) s.currency].firstOrNull ?? '';
  return AnalyticsData(period: period, ranges: ranges, buckets: totals, current: Totals.sum(totals), previous: Totals.fromSummary(previous), currency: currency);
}

/// Runs the jobs [size] at a time (a handful of parallel calls, not a flood), keeping their order.
Future<List<T>> runInChunks<T>(List<Future<T> Function()> jobs, int size) async {
  final out = <T>[];
  for (var i = 0; i < jobs.length; i += size) {
    final end = i + size > jobs.length ? jobs.length : i + size;
    out.addAll(await Future.wait([for (final j in jobs.sublist(i, end)) j()]));
  }
  return out;
}