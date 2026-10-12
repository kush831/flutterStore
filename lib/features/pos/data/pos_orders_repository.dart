import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/end_points.dart';
import '../logic/pos_auth.dart';
import 'pos_orders_models.dart';

class PosOrdersRepository {
  PosOrdersRepository(this._api);

  final ApiClient _api;

  /// A page of orders of one shift, filtered by status (empty = all) and by a search text (id, phone or name).
  Future<({List<PosOrderRow> items, int? next, int total})> orders({required String sessionId, required String search, required String status, required int page}) async {
    final root = await _api.postForm(EndPoints.posOrders, {'pos_session_id': sessionId, 'search': search.trim(), 'order_status': status, 'page': page});
    final d = root.sub('data');
    final items = [for (final o in d.list('orders', PosOrderRow.fromJson)) if (o.orderId.isNotEmpty) o];
    final pag = d.sub('pagination');
    return (items: items, next: (pag.flag('hasMore') && items.isNotEmpty) ? page + 1 : null, total: pag.integer('total') ?? items.length);
  }

  /// Moves an order to the next stage. Returns the server's message.
  Future<String> updateStatus(String orderId, int status) async => (await _api.postForm(EndPoints.posUpdateOrderStatus, {'order_id': orderId, 'order_status': '$status'})).text('message');

  Future<String> cancel(String orderId) async => (await _api.postForm(EndPoints.posCancelOrder, {'order_id': orderId})).text('message');
}

final posOrdersRepositoryProvider = Provider<PosOrdersRepository>((ref) => PosOrdersRepository(ref.watch(posApiProvider)));