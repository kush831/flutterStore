import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/end_points.dart';
import '../logic/pos_auth.dart';
import 'pos_roles_models.dart';

class PosRolesRepository {
  PosRolesRepository(this._api);

  final ApiClient _api;

  Future<List<PosRole>> roles(String businessId) async {
    final root = await _api.postForm(EndPoints.posRoles, {'business_segment_id': businessId});
    return [for (final r in root.list('data', PosRole.fromJson)) if (r.id.isNotEmpty) r];
  }

  /// Every permission there is, for creating a role.
  Future<List<PosPermission>> allPermissions() async {
    final root = await _api.get(EndPoints.posPermissions);
    final d = root.sub('data');
    return [
      for (final m in kPermissionModules)
        for (final p in d.list(m, (r) => PosPermission.fromJson(r, fallbackModule: m))) if (p.id.isNotEmpty) p,
    ];
  }

  /// A role with its permissions, for editing it.
  Future<PosRoleDetail> role(String businessId, String roleId) async => PosRoleDetail.fromJson(await _api.postForm(EndPoints.posRoleShow, {'business_segment_id': businessId, 'role_id': roleId}));

  /// Each of these returns the server's message; a refusal throws with the server's own words.
  Future<String> create(Map<String, Object?> body) async => (await _api.postJson(EndPoints.posRoleStore, body)).text('message');

  Future<String> update(Map<String, Object?> body) async => (await _api.postJson(EndPoints.posRoleUpdate, body)).text('message');

  Future<String> delete(String businessId, String roleId) async => (await _api.postForm(EndPoints.posRoleDestroy, {'business_segment_id': businessId, 'role_id': roleId})).text('message');
}

final posRolesRepositoryProvider = Provider<PosRolesRepository>((ref) => PosRolesRepository(ref.watch(posApiProvider)));