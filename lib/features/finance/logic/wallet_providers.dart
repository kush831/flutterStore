import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/paging.dart';
import '../../../core/time/period_range.dart';
import '../data/wallet_models.dart';
import '../data/wallet_repository.dart';

/// Holds the balance that comes with the first page of a list.
class BalanceHolder extends Notifier<String?> {
  BalanceHolder(this.range);

  final PeriodRange range;

  @override
  String? build() => null;

  void set(String balance) => state = balance;
}

final walletBalanceProvider = NotifierProvider.autoDispose.family<BalanceHolder, String?, PeriodRange>(BalanceHolder.new);
final cashoutBalanceProvider = NotifierProvider.autoDispose.family<BalanceHolder, String?, PeriodRange>(BalanceHolder.new);

class WalletController extends PagedNotifier<WalletEntry> {
  WalletController(this.range);

  final PeriodRange range;

  @override
  PagedState<WalletEntry> build() {
    ref.watch(userScopeProvider);
    return super.build();
  }

  @override
  Future<PageResult<WalletEntry>> fetchPage(int page) async {
    final r = await ref.read(walletRepositoryProvider).wallet(range, page);
    if (page == 1 && ref.mounted) ref.read(walletBalanceProvider(range).notifier).set(r.balance);
    return PageResult(r.entries, r.next);
  }
}

final walletProvider = NotifierProvider.autoDispose.family<WalletController, PagedState<WalletEntry>, PeriodRange>(WalletController.new);

class CashoutController extends PagedNotifier<CashoutEntry> {
  CashoutController(this.range);

  final PeriodRange range;

  @override
  PagedState<CashoutEntry> build() {
    ref.watch(userScopeProvider);
    return super.build();
  }

  @override
  Future<PageResult<CashoutEntry>> fetchPage(int page) async {
    final r = await ref.read(walletRepositoryProvider).cashouts(range, page);
    if (page == 1 && ref.mounted) ref.read(cashoutBalanceProvider(range).notifier).set(r.balance);
    return PageResult(r.entries, r.next);
  }
}

final cashoutProvider = NotifierProvider.autoDispose.family<CashoutController, PagedState<CashoutEntry>, PeriodRange>(CashoutController.new);