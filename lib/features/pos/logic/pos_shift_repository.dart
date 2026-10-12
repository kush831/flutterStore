import 'package:apporio_store_30sept/core/network/api_client.dart';
import 'package:apporio_store_30sept/core/network/end_points.dart';
import 'package:apporio_store_30sept/features/pos/data/pos_shift_models.dart';
import 'package:apporio_store_30sept/features/pos/logic/pos_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/paging.dart';

class PosShiftRepository {
  PosShiftRepository(this._api);

  final ApiClient _api;

  // All terminals; with [only available] only the ones the server says are free.

  Future<List<PosTerminal>> terminals(
    String businessId, {
    bool onlyAvailable = false,
  }) async {
    final root = await _api.postForm(EndPoints.posTerminalsList, {
      'business_segment_id': businessId,
      if (onlyAvailable) 'only_available': 'true',
    });
    return [
      for (final t in root.list('data', PosTerminal.fromJson))
        if (t.id.isNotEmpty) t,
    ];
  }

  Future<String> createTerminal(
    String businessId, {
    required String name,
    required String code,
    required String type,
    required String deviceId,
    required String note,
  }) async {
    final root = await _api.postJson(EndPoints.posTerminals, {
      'name': name.trim(),
      'code': code.trim(),
      'type': type,
      'device_id': deviceId.trim(),
      'location_note': note.trim(),
      'business_segment_id': businessId,
    });
    return root.text('message');
  }

  Future<String> updateTerminal(
    String businessId, {
    required String terminalId,
    required String name,
    required String deviceId,
    required String note,
  }) async {
    final root = await _api.postJson(EndPoints.posTerminalUpdate, {
      'name': name.trim(),
      'location_note': note.trim(),
      'device_id': deviceId.trim(),
      'terminal_id': terminalId,
      'business_segment_id': businessId,
    });
    return root.text('message');
  }

  Future<String> deleteTerminal(String businessId, String terminalId) async {
    final root = await _api.postJson(EndPoints.posTerminalDelete, {
      'business_segment_id': businessId,
      'terminal_id': terminalId,
    });
    return root.text('message');
  }

  // starts a shift on [terminal]. The device id sent is the terminal's device id, or its code when what that is empty.

  Future<PosOpenResult> openSession(
    String businessId, {
    required String openingCash,
    required PosTerminal terminal,
  }) async {
    final root = await _api.postForm(EndPoints.posOpenSession, {
      'opening_cash': openingCash.trim(),
      'pos_device_id': terminal.deviceKey,
      'pos_terminal_id': terminal.id,
      'business_segment_id': businessId,
    });
    return PosOpenResult.fromJson(root.sub('data'));
  }


  /// Closes the open shift with the counted cash. The answer is the shift's summary.
  Future<PosCloseResult> closeSession(String businessId, {required String sessionId, required String closingCash}) async {
    final root = await _api.postForm(EndPoints.posCloseSession, {'closing_cash': closingCash.trim(), 'session_id': sessionId, 'business_segment_id': businessId});
    return PosCloseResult.fromJson(root.sub('data'));
  }

  /// Hands the terminal to the incoming staff member. Returns the server's message.
  Future<String> handover(Map<String, String> fields) async => (await _api.postForm(EndPoints.posHandover, fields)).text('message');

  /// Moves a shift to another terminal (self transfer) or re-binds it (manager). Returns the server's message.
  Future<String> forceTransfer(String businessId, {required String sessionId, required String terminalId, required String deviceId}) async {
    final root = await _api.postForm(EndPoints.posForceTransfer, {'business_segment_id': businessId, 'pos_session_id': sessionId, 'to_terminal_id': terminalId, 'to_device_id': deviceId});
    return root.text('message');
  }

  Future<({List<PosShift> items, int? next})> shiftHistory(String businessId, int page) async {
    final root = await _api.postForm(EndPoints.posSessions, {'page': page, 'business_segment_id': businessId});
    final d = root.sub('data');
    final items = [for (final s in d.list('data', PosShift.fromJson)) if (s.sessionId.isNotEmpty) s];
    return (items: items, next: nextPageOf(page, d.str('nextPageUrl'), gotItems: items.isNotEmpty));
  }

  Future<({List<PosManagerSession> items, int? next})> managerSessions(String businessId, int page) async {
    final root = await _api.postForm(EndPoints.posManagerSessions, {'business_segment_id': businessId, 'page': page});
    final d = root.sub('data');
    final items = [for (final s in d.list('data', PosManagerSession.fromJson)) if (s.sessionId.isNotEmpty) s];
    return (items: items, next: (d.flag('hasMore') && items.isNotEmpty) ? page + 1 : null);
  }
}

final posShiftRepositoryProvider = Provider<PosShiftRepository>((ref)=>PosShiftRepository(ref.watch(posApiProvider)));

final popBusinessIdProvider = Provider<String>((ref)=>ref.watch(posAuthProvider.select((s)=>s.staff?.business.id ?? '')));
