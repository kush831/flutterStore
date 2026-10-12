import 'package:apporio_store_30sept/features/pos/data/pos_sale_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/end_points.dart';
import '../logic/pos_auth.dart';
import '../logic/pos_cart_logic.dart';
import '../logic/pos_checkout_logic.dart';
import 'pos_checkout_models.dart';

class PosCheckoutRepository {
  PosCheckoutRepository(this._api);

  final ApiClient _api;

  /// Saves the cart on the server and returns it priced: the bill, the cart id, the ways to pay.
  Future<PosCartQuote> quote({
    required int segmentId,
    required int serviceTypeId,
    required int sessionId,
    required String orderType,
    required int terminalId,
    required List<PosCartItem> items,
    String customerName = '',
    String customerPhone = '',
    String promoCode = '',
  }) async {
    final root = await _api.postJson(EndPoints.posSaveCart, {
      'product_update': 'NO',
      'segment_id': segmentId,
      'service_type_id': serviceTypeId,
      'pos_session_id': sessionId,
      'pos_order_type': orderType,
      'pos_table_number': '',
      'pos_customer_name': customerName,
      'pos_customer_phone': customerPhone,
      'pos_terminal_id': terminalId,
      'product_details': productDetailsJson(items),
      'promo_code': promoCode,
    });
    return PosCartQuote.fromJson(root);
  }

  /// Checks a promo code with the server. A refusal throws with the server's message.
  Future<PosCartQuote> applyPromo({required String sessionId, required String code, required String segmentId}) async =>
      PosCartQuote.fromJson(await _api.postForm(EndPoints.posPromoApply, {'pos_session_id': sessionId, 'promo_code': code.trim(), 'segment_id': segmentId}));

  /// Empties the server's copy of the cart. Never throws: the app's own cart is cleared whatever the server says.
  Future<void> deleteCart({required String sessionId, required String segmentId}) async {
    try {
      await _api.postForm(EndPoints.posCartDelete, {'pos_session_id': sessionId, 'segment_id': segmentId}, null, false);
    } catch (_) {}
  }

  Future<List<PosPromo>> promoCodes(String segmentId) async {
    final root = await _api.postForm(EndPoints.posPromoCodes, {'segment_id': segmentId});
    return [for (final p in root.list('data', PosPromo.fromJson)) if (p.code.isNotEmpty) p];
  }

  Future<List<PosCustomerUser>> users(String search) async {
    final root = await _api.postForm(EndPoints.posUsers, {'search': search.trim()});
    return [for (final u in root.list('data', PosCustomerUser.fromJson)) if (u.userId.isNotEmpty || u.phone.isNotEmpty) u];
  }
  /// Places the order for a priced cart. A refusal throws with the server's message.
  Future<PosPlacedOrder> placeOrder(Map<String, Object?> body) async => PosPlacedOrder.fromJson(await _api.postJson(EndPoints.posPlaceOrder, body));

  /// A placed order, for the receipt.
  Future<PosReceipt> orderDetail(String orderId) async => PosReceipt.fromJson(await _api.postForm(EndPoints.posOrderDetail, {'order_id': orderId}));
}

final posCheckoutRepositoryProvider = Provider<PosCheckoutRepository>((ref) => PosCheckoutRepository(ref.watch(posApiProvider)));