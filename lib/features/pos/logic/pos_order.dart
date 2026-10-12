import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../data/pos_checkout_models.dart';
import '../data/pos_checkout_repository.dart';
import '../data/pos_repository.dart';
import 'pos_auth.dart';
import 'pos_cart.dart';
import 'pos_checkout_logic.dart';

/// What the cashier chose for this order besides the items: the type of service, the customer, the promo code.
class PosOrderChoices {
  const PosOrderChoices({this.serviceTypeId, this.customer = PosCustomer.walk, this.promoCode = ''});

  final String? serviceTypeId; // null = the first service of the store
  final PosCustomer customer;
  final String promoCode;

  PosOrderChoices copyWith({String? serviceTypeId, PosCustomer? customer, String? promoCode}) => PosOrderChoices(serviceTypeId: serviceTypeId ?? this.serviceTypeId, customer: customer ?? this.customer, promoCode: promoCode ?? this.promoCode);
}

class PosOrder extends Notifier<PosOrderChoices> {
  @override
  PosOrderChoices build() {
    ref.watch(posScopeProvider);
    return const PosOrderChoices();
  }

  void setService(String id) => state = state.copyWith(serviceTypeId: id);
  void setCustomer(PosCustomer c) => state = state.copyWith(customer: c);
  void setPromo(String code) => state = state.copyWith(promoCode: code);

  /// A new order starts clean (after an order is placed, a cart is cleared or held).
  void reset() => state = PosOrderChoices(serviceTypeId: state.serviceTypeId);
}

final posOrderProvider = NotifierProvider<PosOrder, PosOrderChoices>(PosOrder.new);

/// The cart as the server prices it. It asks again, a moment after anything changes (the items, the service, the customer, the
/// promo code); while it waits the screen keeps showing the previous bill. null = the cart is empty.
final posQuoteProvider = FutureProvider.autoDispose<PosCartQuote?>((ref) async {
  ref.watch(posScopeProvider);
  final items = ref.watch(posCartProvider);
  final choices = ref.watch(posOrderProvider);
  final staff = ref.watch(posAuthProvider).staff;
  if (items.isEmpty || staff == null) return null;

  var stale = false;
  ref.onDispose(() => stale = true);
  await Future<void>.delayed(const Duration(milliseconds: 350)); // one request for a burst of taps
  if (stale) return null;

  final session = await ref.watch(posActiveSessionProvider.future);
  if (session == null || !session.isActive) throw const AppException('No open shift', kind: ErrorKind.api);
  final services = staff.business.serviceTypes;
  final service = services.where((s) => s.id == choices.serviceTypeId).firstOrNull ?? services.firstOrNull;

  return ref.read(posCheckoutRepositoryProvider).quote(
    segmentId: int.tryParse(staff.business.segmentId) ?? 0,
    serviceTypeId: int.tryParse(service?.id ?? '') ?? 0,
    sessionId: int.tryParse(session.id) ?? 0,
    orderType: orderTypeKey(service?.name ?? ''),
    terminalId: int.tryParse(session.terminalId) ?? 0,
    items: items,
    customerName: choices.customer.walkIn ? '' : choices.customer.name,
    customerPhone: choices.customer.walkIn ? '' : choices.customer.phone,
    promoCode: choices.promoCode,
  );
});