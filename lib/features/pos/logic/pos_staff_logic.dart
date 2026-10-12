import 'package:flutter/material.dart' show TimeOfDay;

import '../data/pos_staff_models.dart';

enum StaffStatus { active, onBreak, offline, unknown }

/// The server writes the status in more than one way ("on_break", "onbreak", "break").
StaffStatus staffStatusOf(String raw) => switch (raw.trim().toLowerCase().replaceAll(' ', '_')) {
  'active' => StaffStatus.active,
  'on_break' || 'onbreak' || 'break' => StaffStatus.onBreak,
  'offline' => StaffStatus.offline,
  _ => StaffStatus.unknown,
};

/// What "Change Status" sends (Jetpack: active, break, offline).
String? statusUpdateValue(StaffStatus s) => switch (s) {
  StaffStatus.active => 'active',
  StaffStatus.onBreak => 'break',
  StaffStatus.offline => 'offline',
  StaffStatus.unknown => null,
};

String statusTextKey(StaffStatus s) => switch (s) {
  StaffStatus.active => 'pos_posstaffscreen_active',
  StaffStatus.onBreak => 'pos_posstaffscreen_on_break',
  StaffStatus.offline => 'pos_posstaffscreen_offline',
  StaffStatus.unknown => 'pos_posstaffscreen_offline',
};

/// "Asha Rao" → "AR". The server's own initials win when it sends them.
String initialsOf(String name, [String fromServer = '']) {
  if (fromServer.trim().isNotEmpty) return fromServer.trim();
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '·';
  return parts.length == 1 ? parts.first[0].toUpperCase() : (parts.first[0] + parts.last[0]).toUpperCase();
}

/// "#E65100" or "E65100" → an ARGB number, or null.
int? parseHexColor(String s) {
  final h = s.trim().replaceFirst('#', '');
  if (h.length != 6) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : 0xFF000000 | v;
}

/// "09:00" ← a time of day, as the shift fields want it.
String shiftText(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// "09:00" → a time of day (null when it does not read).
TimeOfDay? parseShift(String s) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(s.trim());
  if (m == null) return null;
  final h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  return (h > 23 || min > 59) ? null : TimeOfDay(hour: h, minute: min);
}

const kDefaultShiftStart = '09:00';
const kDefaultShiftEnd = '17:00';

enum StaffField { firstName, phone, pin, role }

/// All problems at once. Adding: a first name, a phone, a 4-digit PIN and a role. Editing: a first name and a phone,
/// and the PIN only if one is typed (then it must be 4 digits).
Set<StaffField> validateStaff({required String first, required String phone, required String pin, required String roleId, required bool isEdit}) {
  final e = <StaffField>{};
  if (first.trim().isEmpty) e.add(StaffField.firstName);
  if (phone.replaceAll(RegExp(r'[^0-9]'), '').isEmpty) e.add(StaffField.phone);
  if (isEdit) {
    if (pin.isNotEmpty && pin.length != 4) e.add(StaffField.pin);
  } else {
    if (pin.length != 4) e.add(StaffField.pin);
    if (roleId.isEmpty) e.add(StaffField.role);
  }
  return e;
}

/// The permissions of a staff member, grouped by module in the order the server sent them.
Map<String, List<PosStaffPermission>> groupByModule(List<PosStaffPermission> all) {
  final out = <String, List<PosStaffPermission>>{};
  for (final p in all) {
    (out[p.module.isEmpty ? '—' : p.module] ??= []).add(p);
  }
  return out;
}

/// The body of "add staff member".
Map<String, Object?> addStaffBody({required String businessId, required String first, required String last, required String phone, required String pin, required PosRoleSummary role, required String shiftStart, required String shiftEnd}) => {
  'first_name': first.trim(),
  'last_name': last.trim(),
  'phone': phone.replaceAll(RegExp(r'[^0-9]'), ''),
  'pin': pin,
  'role_id': role.id,
  'shift_start': shiftStart,
  'shift_end': shiftEnd,
  'business_segment_id': businessId,
  'level': role.level,
};

/// The body of "update staff". The PIN is sent empty when it is not being changed.
Map<String, Object?> updateStaffBody({required String businessId, required String staffId, required String first, required String last, required String phone, required String pin, required String shiftStart, required String shiftEnd}) => {
  'first_name': first.trim(),
  'last_name': last.trim(),
  'phone': phone.replaceAll(RegExp(r'[^0-9]'), ''),
  'shift_start': shiftStart,
  'shift_end': shiftEnd,
  'business_segment_id': businessId,
  'staff_id': staffId,
  'pin': pin,
};