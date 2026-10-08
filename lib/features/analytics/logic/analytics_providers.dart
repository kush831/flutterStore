import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../finance/data/earnings_models.dart';
import '../../finance/data/earnings_repository.dart';
import 'analytics_logic.dart';

/// The numbers of one period. Every bar is one call that reads only the totals the earnings API gives for a date range.
final analyticsProvider = FutureProvider.autoDispose.family<AnalyticsData, AnalyticsPeriod>((ref, period) async {
  ref.watch(userScopeProvider);
  final repo = ref.watch(earningsRepositoryProvider);
  final now = DateTime.now();
  final ranges = analyticsBuckets(period, now);
  final before = previousBuckets(period, now);

  Future<EarningsSummary> totalsOf(BucketRange r) async => (await repo.page(r.range, 1)).summary;

  final results = await runInChunks<EarningsSummary>([for (final r in ranges) () => totalsOf(r), () => totalsOf(before)], 6);
  return buildAnalytics(period: period, ranges: ranges, summaries: results.sublist(0, ranges.length), previous: results.last);
});