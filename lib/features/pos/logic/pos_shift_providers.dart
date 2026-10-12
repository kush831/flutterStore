
import 'package:apporio_store_30sept/features/pos/data/pos_shift_models.dart';
import 'package:apporio_store_30sept/features/pos/data/pos_shift_repository.dart';
import 'package:apporio_store_30sept/features/pos/logic/pos_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/paging.dart';

// every terminal of the store (the terminals screen)

final posTerminalProvider = FutureProvider.autoDispose<List<PosTerminal>>((ref){
  ref.watch(posScopeProvider);
  return ref.watch(posShiftRepositoryProvider).terminals(ref.watch(posBusinessIdProvider));
});

// only the free terminals,as the server decides (Open Session, Transfer Terminal)

final posAvailableTerminalsProvider = FutureProvider.autoDispose<List<PosTerminal>>((ref){
  ref.watch(posScopeProvider);
  return ref.watch(posShiftRepositoryProvider).terminals(ref.watch(posBusinessIdProvider),onlyAvailable: true);
});

class PosShiftHistoryController extends PagedNotifier<PosShift> {
  @override
  PagedState<PosShift> build() {
    ref.watch(posScopeProvider);
    return super.build();
  }

  @override
  Future<PageResult<PosShift>> fetchPage(int page) async {
    final r = await ref.read(posShiftRepositoryProvider).shiftHistory(ref.read(posBusinessIdProvider), page);
    return PageResult(r.items, r.next);
  }
}

final posShiftHistoryProvider = NotifierProvider.autoDispose<PosShiftHistoryController, PagedState<PosShift>>(PosShiftHistoryController.new);

class PosAllSessionsController extends PagedNotifier<PosManagerSession> {
  @override
  PagedState<PosManagerSession> build() {
    ref.watch(posScopeProvider);
    return super.build();
  }

  @override
  Future<PageResult<PosManagerSession>> fetchPage(int page) async {
    final r = await ref.read(posShiftRepositoryProvider).managerSessions(ref.read(posBusinessIdProvider), page);
    return PageResult(r.items, r.next);
  }
}

final posAllSessionsProvider = NotifierProvider.autoDispose<PosAllSessionsController, PagedState<PosManagerSession>>(PosAllSessionsController.new);