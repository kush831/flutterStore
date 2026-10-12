import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/pos_checkout_repository.dart';
import '../data/pos_sale_models.dart';
import 'pos_auth.dart';

/// The sale just paid (see [PosLastSale]). Gone when the staff member signs out of POS.
class PosLastSaleNotifier extends Notifier<PosLastSale?> {
  @override
  PosLastSale? build() {
    ref.watch(posScopeProvider);
    return null;
  }

  void set(PosLastSale s) => state = s;
  void clear() => state = null;
}

final posLastSaleProvider = NotifierProvider<PosLastSaleNotifier, PosLastSale?>(PosLastSaleNotifier.new);

final posReceiptProvider = FutureProvider.autoDispose.family<PosReceipt, String>((ref, orderId) {
  ref.watch(posScopeProvider);
  return ref.watch(posCheckoutRepositoryProvider).orderDetail(orderId);
});