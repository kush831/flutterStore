import '../../../core/network/json_reader.dart';

/// The permission groups the server lists (Jetpack's model has exactly these five).
const kPermissionModules = ['orders', 'pos', 'products', 'reports', 'staff'];

class PosRole {
  const PosRole({required this.id, this.name = '', this.description = '', this.isSystem = false, this.permissionCount = 0, this.createdAt = ''});

  final String id;
  final String name;
  final String description;
  final bool isSystem;
  final int permissionCount;
  final String createdAt;

  factory PosRole.fromJson(JsonReader r) => PosRole(id: r.text('id'), name: r.text('name'), description: r.text('description'), isSystem: r.flag('isSystem'), permissionCount: r.integer('permissionCount') ?? 0, createdAt: r.text('createdAt'));
}

class PosPermission {
  const PosPermission({required this.id, this.key = '', this.name = '', this.description = '', this.module = ''});

  final String id;
  final String key;
  final String name;
  final String description;
  final String module;

  factory PosPermission.fromJson(JsonReader r, {String fallbackModule = ''}) {
    final m = r.text('module');
    return PosPermission(id: r.text('id'), key: r.text('key'), name: r.text('name'), description: r.text('description'), module: m.isEmpty ? fallbackModule : m);
  }
}

/// A role with the permissions it has, and the whole list to choose from.
class PosRoleDetail {
  const PosRoleDetail({required this.role, this.granted = const {}, this.all = const []});

  final PosRole role;
  final Set<String> granted; // permission ids
  final List<PosPermission> all;

  factory PosRoleDetail.fromJson(JsonReader root) {
    final d = root.sub('data');
    return PosRoleDetail(
      role: PosRole.fromJson(d.sub('role')),
      granted: {for (final p in d.list('permissions', PosPermission.fromJson)) if (p.id.isNotEmpty) p.id},
      all: [for (final p in d.list('allPermissions', PosPermission.fromJson)) if (p.id.isNotEmpty) p],
    );
  }
} 