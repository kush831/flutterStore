import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/paging.dart';
import '../data/pos_shift_repository.dart' show posBusinessIdProvider;
import '../data/pos_staff_models.dart';
import '../data/pos_staff_repository.dart';
import 'pos_auth.dart';

final posStaffSummaryProvider = FutureProvider.autoDispose<PosStaffSummary>((ref) {
  ref.watch(posScopeProvider);
  return ref.watch(posStaffRepositoryProvider).summary(ref.watch(posBusinessIdProvider));
});

final posStaffDetailProvider = FutureProvider.autoDispose.family<PosStaffDetail, String>((ref, staffId) {
  ref.watch(posScopeProvider);
  return ref.watch(posStaffRepositoryProvider).detail(ref.watch(posBusinessIdProvider), staffId);
});

/// The "N members" of a staff list comes with its first page.
class PosStaffTotal extends Notifier<int?> {
  PosStaffTotal(this.search);

  final String search;

  @override
  int? build() => null;

  void set(int total) => state = total;
}

final posStaffTotalProvider = NotifierProvider.autoDispose.family<PosStaffTotal, int?, String>(PosStaffTotal.new);

/// The team, page by page. The search text is part of the key: each search has its own list.
class PosStaffListController extends PagedNotifier<PosStaffMember> {
  PosStaffListController(this.search);

  final String search;

  @override
  PagedState<PosStaffMember> build() {
    ref.watch(posScopeProvider);
    return super.build();
  }

  @override
  Future<PageResult<PosStaffMember>> fetchPage(int page) async {
    final r = await ref.read(posStaffRepositoryProvider).staff(ref.read(posBusinessIdProvider), page, search);
    if (page == 1 && ref.mounted) ref.read(posStaffTotalProvider(search).notifier).set(r.total);
    return PageResult(r.items, r.next);
  }
}

final posStaffListProvider = NotifierProvider.autoDispose.family<PosStaffListController, PagedState<PosStaffMember>, String>(PosStaffListController.new);

class PosStatusLogController extends PagedNotifier<PosStatusEntry> {
  PosStatusLogController(this.staffId);

  final String staffId;

  @override
  PagedState<PosStatusEntry> build() {
    ref.watch(posScopeProvider);
    return super.build();
  }

  @override
  Future<PageResult<PosStatusEntry>> fetchPage(int page) async {
    final r = await ref.read(posStaffRepositoryProvider).statusLog(ref.read(posBusinessIdProvider), staffId, page);
    return PageResult(r.items, r.next);
  }
}

final posStatusLogProvider = NotifierProvider.autoDispose.family<PosStatusLogController, PagedState<PosStatusEntry>, String>(PosStatusLogController.new);