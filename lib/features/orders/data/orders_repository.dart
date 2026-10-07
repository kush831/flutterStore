import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/network/end_points.dart';
import '../../../core/network/paging.dart';
import '../../../core/storage/app_prefs.dart';
import '../../../core/storage/storage_providers.dart';
import 'driver_models.dart';
import 'order_detail_models.dart';
import 'order_models.dart';

String encodeDriverIds(List<int> ids) => jsonEncode([for (final id in ids) {'id': '$id'}]);

class OrdersRepository {
  OrdersRepository(this._api, this._prefs);

  final ApiClient _api;
  final AppPrefs _prefs;

  /// One page of orders. A next page exists only when the API sends `next_page_url` AND this page had orders.
  Future<PageResult<OrderItem>> page(String status, int page) async {
    final root = await _api.postForm(EndPoints.getOrders, {
      'status': status,
      'page': page,
      'locale': _prefs.language ?? 'en',
    });
    final d = root.sub('data');
    final items = d.list('responseData', OrderItem.fromJson);
    return PageResult(items, nextPageOf(page, d.str('nextPageUrl'), gotItems: items.isNotEmpty));
  }
  /// Throws AppException (the server's message when the order is not found).
  /// Throws AppException (the server's message when the order is not found).
  Future<OrderDetail> detail(String id) async {
    // requireSuccess: false → the payload may sit at the root, with no `result` field
    final root = await _api.postForm(EndPoints.getOrderDetails, {'id': id, 'locale': _prefs.language ?? 'en'}, null, false);
    if (root.str('result') == '0') throw AppException(root.text('message'), kind: ErrorKind.api, code: '0');

    final d = OrderDetail.fromJson(root);
    if (d.id == 0 && d.number == 0) {
      if (kDebugMode) debugPrint('Order detail: no "details" found in the response for order $id');
      throw const AppException('', kind: ErrorKind.server, detail: 'order detail without details');
    }
    return d;
  }

  String get _locale => _prefs.language ?? 'en';

  /// Every action returns the server's message. A refusal throws AppException with that message.
  Future<String> _act(String path, Map<String, Object?> body) async => (await _api.postForm(path, body)).text('message');

  Future<String> accept(String id) => _act(EndPoints.acceptOrder, {'order_id': id});
  Future<String> reject(String id) => _act(EndPoints.rejectOrder, {'order_id': id, 'locale': _locale});
  Future<String> process(String id) => _act(EndPoints.processOrder, {'order_id': id, 'locale': _locale});
  Future<String> ready(String id) => _act(EndPoints.orderReady, {'order_id': id, 'locale': _locale});
  Future<String> deliver(String id) => _act(EndPoints.deliverOrder, {'order_id': id});
  Future<String> autoAssign(String id) => _act(EndPoints.autoAssignDriver, {'order_id': id, 'locale': _locale});

  Future<String> manualAssign(String id, List<int> driverIds) =>
      _act(EndPoints.manualAssignDriver, {'order_id': id, 'driver_id': encodeDriverIds(driverIds), 'locale': _locale});

  /// The server verifies the code. Throws AppException ("Invalid OTP …") when it is wrong.
  Future<String> verifyPickup(String id, String otp) =>
      _act(EndPoints.pickupOtpVerification, {'order_id': id, 'otp': otp, 'locale': _locale});

  Future<List<Driver>> drivers(String orderId) async {
    final root = await _api.postForm(EndPoints.getDrivers, {'order_id': orderId, 'locale': _locale});
    return [for (final d in root.sub('data').list('drivers', Driver.fromJson)) if (d.id != 0) d];
  }
}

final ordersRepositoryProvider = Provider<OrdersRepository>(
      (ref) => OrdersRepository(ref.watch(apiClientProvider), ref.watch(appPrefsProvider)),
);