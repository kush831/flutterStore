import 'dart:convert';

import '../../../core/media/image_picking.dart';
import '../data/store_models.dart';

const kDefaultOpen = '09:00';
const kDefaultClose = '22:00';

// ── time ─────────────────────────────────────────────────────────────────────

/// "09:00", "09:00:00", "9:00 AM", "9:00pm" → "HH:mm" (24 hours). '' when it cannot be read.
String normalizeTime(String raw) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*(AM|PM)?$').firstMatch(raw.trim().toUpperCase());
  if (m == null) return '';
  var h = int.parse(m[1]!);
  final min = int.parse(m[2]!);
  final ap = m[3];
  if (min > 59) return '';
  if (ap != null) {
    if (h < 1 || h > 12) return '';
    if (ap == 'PM' && h != 12) h += 12;
    if (ap == 'AM' && h == 12) h = 0;
  } else if (h > 23) {
    return '';
  }
  return '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
}

({int hour, int minute}) splitTime(String hhmm) {
  final p = hhmm.split(':');
  return (hour: int.tryParse(p.first) ?? 0, minute: p.length > 1 ? (int.tryParse(p[1]) ?? 0) : 0);
}

String joinTime(int hour, int minute) => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

// ── weekly timings ───────────────────────────────────────────────────────────

/// Positions of Saturday and Sunday. Found by English name; when the names are in another language: the first and last day.
Set<int> weekendIndexes(List<String> names) {
  final found = <int>{};
  for (var i = 0; i < names.length; i++) {
    final n = names[i].trim().toLowerCase();
    if (n.startsWith('sun') || n.startsWith('sat')) found.add(i);
  }
  if (found.isNotEmpty || names.length != 7) return found;
  return {0, 6};
}

List<DaySchedule> selectAllDays(List<DaySchedule> days, bool on) => [for (final d in days) d.copyWith(enabled: on)];

List<DaySchedule> weekdaysOnly(List<DaySchedule> days) {
  final weekend = weekendIndexes([for (final d in days) d.name]);
  return [for (var i = 0; i < days.length; i++) days[i].copyWith(enabled: !weekend.contains(i))];
}

bool allDaysSelected(List<DaySchedule> days) => days.isNotEmpty && days.every((d) => d.enabled);

bool onlyWeekdaysSelected(List<DaySchedule> days) {
  if (days.isEmpty) return false;
  final weekend = weekendIndexes([for (final d in days) d.name]);
  if (weekend.isEmpty) return false;
  return [for (var i = 0; i < days.length; i++) days[i].enabled == !weekend.contains(i)].every((ok) => ok);
}

/// The four text fields of the timing save. Each is a JSON list with one entry per day, in the order the server sent them.
/// slot_end_time is always "2" (Jetpack).
Map<String, String> timingFields(List<DaySchedule> days) => {
  'open_time': jsonEncode([for (final d in days) d.open.isEmpty ? kDefaultOpen : d.open]),
  'close_time': jsonEncode([for (final d in days) d.close.isEmpty ? kDefaultClose : d.close]),
  'slot_end_time': jsonEncode([for (final _ in days) '2']),
  'is_open_close_arr': jsonEncode([for (final d in days) d.enabled ? '1' : '0']), // 1 = open, 0 = closed
};

// ── the profile form ─────────────────────────────────────────────────────────

enum StoreField { name, email, phone, address, landmark, persons, avgPrice, deliveryTime, latitude, longitude }

class StoreForm {
  const StoreForm({
    this.photo,
    this.name = '',
    this.email = '',
    this.phone = '',
    this.address = '',
    this.landmark = '',
    this.latitude = '',
    this.longitude = '',
    this.persons = '',
    this.avgPrice = '',
    this.deliveryTime = '',
    this.packaging = false,
    this.availability = false,
  });

  final PickedPhoto? photo; // a new logo chosen on this phone
  final String name;
  final String email;
  final String phone;
  final String address;
  final String landmark;
  final String latitude;
  final String longitude;
  final String persons;
  final String avgPrice;
  final String deliveryTime;
  final bool packaging;
  final bool availability;
}

final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool _inRange(String s, double min, double max) {
  final n = double.tryParse(s.trim());
  return n != null && n >= min && n <= max;
}

/// All problems at once: field → key of the server text.
Map<StoreField, String> validateStore(StoreForm f) {
  const invalid = 'products_addproductscreen_preparation_time_enterValidNumber'; // "Enter a valid number"
  final e = <StoreField, String>{};
  if (f.name.trim().isEmpty) e[StoreField.name] = 'storedetails_storeprofile_store_name_required';
  if (f.email.trim().isEmpty) {
    e[StoreField.email] = 'storedetails_storeprofile_emailRequired';
  } else if (!_email.hasMatch(f.email.trim())) {
    e[StoreField.email] = 'storedetails_storeprofile_invalidEmail';
  }
  if (f.phone.trim().isEmpty) e[StoreField.phone] = 'storedetails_storeprofile_phone_required';
  if (f.address.trim().isEmpty) e[StoreField.address] = 'storedetails_storeprofile_street_required';
  if (f.landmark.trim().isEmpty) e[StoreField.landmark] = 'storedetails_storeprofile_landMarkRequired';
  if (f.latitude.trim().isNotEmpty && !_inRange(f.latitude, -90, 90)) e[StoreField.latitude] = invalid;
  if (f.longitude.trim().isNotEmpty && !_inRange(f.longitude, -180, 180)) e[StoreField.longitude] = invalid;
  if (f.persons.trim().isEmpty) {
    e[StoreField.persons] = 'storedetails_storeprofile_noOfPersonsRequired';
  } else if (int.tryParse(f.persons.trim()) == null) {
    e[StoreField.persons] = invalid;
  }
  if (f.avgPrice.trim().isEmpty) {
    e[StoreField.avgPrice] = 'storedetails_storeprofile_avgMealPriceRequired';
  } else if (double.tryParse(f.avgPrice.trim()) == null) {
    e[StoreField.avgPrice] = invalid;
  }
  if (f.deliveryTime.trim().isEmpty) e[StoreField.deliveryTime] = 'storedetails_storeprofile_deliveryTimeRequired';
  return e;
}

/// The text fields of `edit-profile`. ⚠️ The two switches send "1" for on and "0" for off (Jetpack only shows that "1" means on).
Map<String, String> profileFields(StoreForm f) => {
  'full_name': f.name.trim(),
  'email': f.email.trim(),
  'phone_number': f.phone.trim(),
  'address': f.address.trim(),
  'latitude': f.latitude.trim(),
  'longitude': f.longitude.trim(),
  'landmark': f.landmark.trim(),
  'minimum_amount_for': f.persons.trim(),
  'minimum_amount': f.avgPrice.trim(),
  'delivery_time': f.deliveryTime.trim(),
  'packaging_preference_enable': f.packaging ? '1' : '0',
  'product_availability_time_module_enable': f.availability ? '1' : '0',
};