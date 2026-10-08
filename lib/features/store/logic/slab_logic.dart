import '../../../core/media/image_picking.dart';
import '../data/slab_models.dart';

/// "All day" ends at 11:59 PM.
const kAllDayEnd = '23:59';

enum SlabField { name, priority, start, end, price }

class SlabForm {
  const SlabForm({
    this.name = '',
    this.priority = '',
    this.start = '',
    this.end = '',
    this.allDay = false,
    this.custom = false,
    this.price = '',
    this.photo,
    this.imageUrl = '',
  });

  final String name;
  final String priority;
  final String start; // "HH:mm" or ''
  final String end;
  final bool allDay;
  final bool custom;
  final String price;
  final PickedPhoto? photo; // a new picture
  final String imageUrl; // the picture the server has

  bool get hasImage => photo != null || imageUrl.isNotEmpty;

  SlabForm copyWith({String? name, String? priority, String? start, String? end, bool? allDay, bool? custom, String? price, PickedPhoto? photo}) => SlabForm(
    name: name ?? this.name,
    priority: priority ?? this.priority,
    start: start ?? this.start,
    end: end ?? this.end,
    allDay: allDay ?? this.allDay,
    custom: custom ?? this.custom,
    price: price ?? this.price,
    photo: photo ?? this.photo,
    imageUrl: imageUrl,
  );

  /// Jetpack: All day ON → only the end is fixed (11:59 PM), the start is chosen (or midnight). OFF → both times cleared.
  SlabForm withAllDay(bool on) => on ? copyWith(allDay: true, start: '', end: kAllDayEnd) : copyWith(allDay: false, start: '', end: '');

  /// Jetpack: Custom ON → All day OFF and the times cleared. OFF → the price is cleared.
  SlabForm withCustom(bool on) => on ? copyWith(custom: true, allDay: false, start: '', end: '') : copyWith(custom: false, price: '');

  factory SlabForm.fromSlab(AvailabilitySlab s) => SlabForm(
    name: s.name,
    priority: s.priority,
    start: s.custom ? '' : (s.allDay && s.start == '00:00' ? '' : s.start),
    end: s.allDay ? kAllDayEnd : (s.custom ? '' : s.end),
    allDay: s.allDay,
    custom: s.custom,
    price: s.custom ? s.customPrice : '',
    imageUrl: s.image,
  );
}

/// All problems at once: field → key of the server text. The rules Jetpack really uses.
Map<SlabField, String> validateSlab(SlabForm f) {
  final e = <SlabField, String>{};
  if (f.name.trim().isEmpty) e[SlabField.name] = 'storedetails_storeprofile_timeSlabNameIsRequired';
  if (f.priority.trim().isEmpty) e[SlabField.priority] = 'storedetails_storeprofile_priorityIsRequired';
  if (!f.allDay && !f.custom) {
    if (f.start.isEmpty) e[SlabField.start] = 'storedetails_storeprofile_startTimeRequired';
    if (f.end.isEmpty) e[SlabField.end] = 'storedetails_storeprofile_endTimeRequired';
  }
  if (f.custom && f.price.trim().isEmpty) e[SlabField.price] = 'storedetails_storeprofile_priceIsRequired';
  return e;
}

/// "08:00" → "08:00:00". A blank time is midnight (Jetpack).
String apiTime(String hhmm) => hhmm.isEmpty ? '00:00:00' : '$hhmm:00';

/// The text fields of the save. One slab, so every key ends with [0]. An `id` makes it an update.
Map<String, String> slabFields({String? id, required SlabForm f}) => {
  if (id != null && id.isNotEmpty) 'time_slab_id[0]': id,
  'time_slab_name[0]': f.name.trim(),
  'priority[0]': f.priority.trim(),
  'available_all_day[0]': f.allDay ? '1' : '0',
  'is_custom[0]': f.custom ? '1' : '0',
  'start_time[0]': apiTime(f.start),
  'end_time[0]': apiTime(f.end),
  if (f.custom && f.price.trim().isNotEmpty) 'custom_price[0]': f.price.trim(),
};