import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/paging.dart';
import '../../../core/time/period_range.dart';
import '../data/earnings_models.dart';
import '../data/earnings_repository.dart';

/// Holds the period's summary, which comes with the first page of orders.
class EarningsSummaryHolder extends Notifier<EarningsSummary?> {
  EarningsSummaryHolder(this.range);

  final PeriodRange range;

  @override
  EarningsSummary? build() => null;

  void set(EarningsSummary s) => state = s;
}

final earningsSummaryProvider = NotifierProvider.autoDispose.family<EarningsSummaryHolder, EarningsSummary?, PeriodRange>(EarningsSummaryHolder.new);

/// The orders of one period, page by page. Each period keeps its own list.
class EarningsController extends PagedNotifier<EarningOrder> {
  EarningsController(this.range);

  final PeriodRange range;

  @override
  PagedState<EarningOrder> build() {
    ref.watch(userScopeProvider);
    return super.build();
  }

  @override
  Future<PageResult<EarningOrder>> fetchPage(int page) async {
    final r = await ref.read(earningsRepositoryProvider).page(range, page);
    if (page == 1 && ref.mounted) ref.read(earningsSummaryProvider(range).notifier).set(r.summary);
    return PageResult(r.orders, r.next);
  }
}

final earningsProvider = NotifierProvider.autoDispose.family<EarningsController, PagedState<EarningOrder>, PeriodRange>(EarningsController.new);