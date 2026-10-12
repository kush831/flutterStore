import '../data/pos_roles_models.dart';

/// Every custom role is created with level "2" (Jetpack).
const kCustomRoleLevel = '2';

/// The checklist, grouped by module (written in capitals, as Jetpack shows them), in the order the server sent them.
Map<String, List<PosPermission>> groupPermissions(List<PosPermission> all) {
  final out = <String, List<PosPermission>>{};
  for (final p in all) {
    (out[(p.module.isEmpty ? '—' : p.module).toUpperCase()] ??= []).add(p);
  }
  return out;
}

/// A tap on a permission: ticked becomes unticked, and the other way round.
Set<String> togglePermission(Set<String> chosen, String id) => chosen.contains(id) ? ({...chosen}..remove(id)) : {...chosen, id};

/// "Create Role" and "Update Role" wait for a name and at least one permission.
bool roleFormReady(String name, int selected) => name.trim().isNotEmpty && selected > 0;

/// The permission ids as the numbers the server wants, once each, in order.
List<int> permissionIds(Set<String> chosen) => ({for (final id in chosen) if (int.tryParse(id) != null) int.parse(id)}.toList()..sort());

Map<String, Object?> createRoleBody({required String businessId, required String name, required String description, required Set<String> chosen}) => {
  'business_segment_id': businessId,
  'name': name.trim(),
  'description': description.trim(),
  'permission_ids': permissionIds(chosen),
  'level': kCustomRoleLevel,
};

Map<String, Object?> updateRoleBody({required String businessId, required String roleId, required String name, required String description, required Set<String> chosen}) => {
  'business_segment_id': businessId,
  'role_id': roleId,
  'name': name.trim(),
  'description': description.trim(),
  'permission_ids': permissionIds(chosen),
};

/// Only a role that is not part of the system can be deleted.
bool canDeleteRole(PosRole r) => !r.isSystem;