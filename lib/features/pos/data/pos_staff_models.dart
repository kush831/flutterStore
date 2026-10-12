import '../../../core/network/json_reader.dart';

/// One role in the summary: its name, how many permissions it carries, and whether it comes with the system.
class PosRoleSummary {
  const PosRoleSummary({required this.id, this.name = '', this.isSystem = false, this.permCount = 0, this.level = ''});

  final String id;
  final String name;
  final bool isSystem;
  final int permCount;
  final String level;

  factory PosRoleSummary.fromJson(JsonReader r) => PosRoleSummary(id: r.text('id'), name: r.text('name'), isSystem: r.flag('isSystem'), permCount: r.integer('permCount') ?? 0, level: r.text('level'));
}

class PosStaffSummary {
  const PosStaffSummary({this.active = 0, this.onBreak = 0, this.offline = 0, this.total = 0, this.roles = const []});

  final int active;
  final int onBreak;
  final int offline;
  final int total;
  final List<PosRoleSummary> roles;

  factory PosStaffSummary.fromJson(JsonReader root) {
    final d = root.sub('data');
    final c = d.sub('counts');
    return PosStaffSummary(
      active: c.integer('active') ?? 0,
      onBreak: c.integer('onBreak') ?? 0,
      offline: c.integer('offline') ?? 0,
      total: c.integer('total') ?? 0,
      roles: [for (final r in d.list('roles', PosRoleSummary.fromJson)) if (r.id.isNotEmpty) r],
    );
  }
}

/// A team member in a list.
class PosStaffMember {
  const PosStaffMember({required this.staffId, this.userId = '', this.name = '', this.initials = '', this.avatarColor = '', this.roleId = '', this.roleName = '', this.shift = '', this.status = '', this.statusLabel = '', this.phone = ''});

  final String staffId;
  final String userId;
  final String name;
  final String initials;
  final String avatarColor; // "#RRGGBB"
  final String roleId;
  final String roleName;
  final String shift;
  final String status; // current_status
  final String statusLabel; // the server's words for it
  final String phone;

  factory PosStaffMember.fromJson(JsonReader r) => PosStaffMember(
    staffId: r.text('staffId'),
    userId: r.text('userId'),
    name: r.text('name'),
    initials: r.text('initials'),
    avatarColor: r.text('avatarColor'),
    roleId: r.text('roleId'),
    roleName: r.text('roleName'),
    shift: r.text('shift'),
    status: r.text('currentStatus'),
    statusLabel: r.text('statusLabel'),
    phone: r.text('phone'),
  );
}

class PosStaffPermission {
  const PosStaffPermission({required this.id, this.key = '', this.name = '', this.description = '', this.module = '', this.enabled = false});

  final String id;
  final String key;
  final String name;
  final String description;
  final String module;
  final bool enabled;

  factory PosStaffPermission.fromJson(JsonReader r) => PosStaffPermission(id: r.text('id'), key: r.text('key'), name: r.text('name'), description: r.text('description'), module: r.text('module'), enabled: r.flag('isEnabled'));
}

class PosStaffDetail {
  const PosStaffDetail({
    required this.staffId,
    this.userId = '',
    this.name = '',
    this.initials = '',
    this.avatarColor = '',
    this.roleId = '',
    this.roleName = '',
    this.shift = '',
    this.shiftStart = '',
    this.shiftEnd = '',
    this.status = '',
    this.statusLabel = '',
    this.phone = '',
    this.isActive = false,
    this.permLabel = '',
    this.permissions = const [],
  });

  final String staffId;
  final String userId;
  final String name;
  final String initials;
  final String avatarColor;
  final String roleId;
  final String roleName;
  final String shift;
  final String shiftStart; // "HH:mm"
  final String shiftEnd;
  final String status;
  final String statusLabel;
  final String phone;
  final bool isActive;
  final String permLabel;
  final List<PosStaffPermission> permissions;

  /// The name split at the first space: the edit form needs the two parts.
  ({String first, String last}) get nameParts {
    final t = name.trim();
    final i = t.indexOf(' ');
    return i < 0 ? (first: t, last: '') : (first: t.substring(0, i), last: t.substring(i + 1).trim());
  }

  factory PosStaffDetail.fromJson(JsonReader root) {
    final d = root.sub('data');
    return PosStaffDetail(
      staffId: d.text('staffId'),
      userId: d.text('userId'),
      name: d.text('name'),
      initials: d.text('initials'),
      avatarColor: d.text('avatarColor'),
      roleId: d.text('roleId'),
      roleName: d.text('roleName'),
      shift: d.text('shift'),
      shiftStart: d.text('shiftStart'),
      shiftEnd: d.text('shiftEnd'),
      status: d.text('currentStatus'),
      statusLabel: d.text('statusLabel'),
      phone: d.text('phone'),
      isActive: d.flag('isActive'),
      permLabel: d.text('permLabel'),
      permissions: d.list('permissions', PosStaffPermission.fromJson),
    );
  }
}

/// One entry of a staff member's status history.
class PosStatusEntry {
  const PosStatusEntry({required this.id, this.status = '', this.note = '', this.startedAt = '', this.endedAt = ''});

  final String id;
  final String status;
  final String note;
  final String startedAt;
  final String endedAt;

  factory PosStatusEntry.fromJson(JsonReader r) => PosStatusEntry(id: r.text('id'), status: r.text('status'), note: r.text('note'), startedAt: r.text('startedAt'), endedAt: r.text('endedAt'));
}