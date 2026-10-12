import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/end_points.dart';
import '../../../core/network/paging.dart';
import '../logic/pos_auth.dart';
import 'pos_staff_models.dart';

class PosStaffRepository {
  PosStaffRepository(this._api);

  final ApiClient _api;

  Future<PosStaffSummary> summary(String businessId) async => PosStaffSummary.fromJson(await _api.postForm(EndPoints.posStaffSummary, {'business_segment_id': businessId}));

  Future<({List<PosStaffMember> items, int? next, int total})> staff(String businessId, int page, String search) async {
    final root = await _api.postForm(EndPoints.posStaffList, {'page': page, 'business_segment_id': businessId, 'search': search.trim()});
    final d = root.sub('data');
    final items = [for (final m in d.list('data', PosStaffMember.fromJson)) if (m.staffId.isNotEmpty) m];
    return (items: items, next: nextPageOf(page, d.str('nextPageUrl'), gotItems: items.isNotEmpty), total: d.integer('total') ?? items.length);
  }

  Future<PosStaffDetail> detail(String businessId, String staffId) async => PosStaffDetail.fromJson(await _api.postForm(EndPoints.posStaffDetail, {'staff_id': staffId, 'business_segment_id': businessId}));

  Future<({List<PosStatusEntry> items, int? next, int total})> statusLog(String businessId, String staffId, int page) async {
    final root = await _api.postForm(EndPoints.posStaffStatusLog, {'staff_id': staffId, 'business_segment_id': businessId, 'page': page});
    final d = root.sub('data');
    final items = [for (final e in d.list('data', PosStatusEntry.fromJson)) if (e.id.isNotEmpty) e];
    return (items: items, next: nextPageOf(page, d.str('nextPageUrl'), gotItems: items.isNotEmpty), total: d.integer('total') ?? items.length);
  }

  /// Each of these returns the server's message. A refusal throws with the server's own words.
  Future<String> add(Map<String, Object?> body) async => (await _api.postJson(EndPoints.posStaffCreate, body)).text('message');

  Future<String> update(Map<String, Object?> body) async => (await _api.postJson(EndPoints.posStaffUpdate, body)).text('message');

  Future<String> changeRole(String businessId, {required String staffId, required String roleId}) async =>
      (await _api.postForm(EndPoints.posStaffChangeRole, {'role_id': roleId, 'staff_id': staffId, 'business_segment_id': businessId})).text('message');

  Future<String> changeStatus(String businessId, {required String staffId, required String status, required String sessionId}) async =>
      (await _api.postJson(EndPoints.posStaffStatus, {'status': status, 'pos_session_id': sessionId, 'business_segment_id': businessId, 'staff_id': staffId})).text('message');

  Future<String> deactivate(String businessId, String staffId) async => (await _api.postForm(EndPoints.posStaffDeactivate, {'business_segment_id': businessId, 'staff_id': staffId})).text('message');
}

final posStaffRepositoryProvider = Provider<PosStaffRepository>((ref) => PosStaffRepository(ref.watch(posApiProvider)));