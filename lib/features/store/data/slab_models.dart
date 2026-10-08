import '../../../core/network/json_reader.dart';
import '../logic/store_logic.dart' show normalizeTime;

class AvailabilitySlab {
  const AvailabilitySlab({
    required this.id,
    this.name = '',
    this.start = '',
    this.end = '',
    this.allDay = false,
    this.custom = false,
    this.customPrice = '',
    this.priority = '',
    this.image = '',
  });

  final String id;
  final String name;
  final String start; // "HH:mm" or ''
  final String end;
  final bool allDay;
  final bool custom; // a price override: the times are not used
  final String customPrice;
  final String priority;
  final String image;

  /// Sort key. Slabs without a number go last.
  int get order => int.tryParse(priority.trim()) ?? 1 << 30;

  /// A time range is only meaningful for a normal slab.
  bool get hasRange => !allDay && !custom && start.isNotEmpty && end.isNotEmpty;

  factory AvailabilitySlab.fromJson(JsonReader r) => AvailabilitySlab(
    id: r.text('id'),
    name: r.text('name'),
    start: normalizeTime(r.text('startTime')),
    end: normalizeTime(r.text('endTime')),
    allDay: r.text('availableAllDay') == '1',
    custom: r.text('isCustom') == '1',
    customPrice: r.text('customPrice'),
    priority: r.text('priority'),
    image: r.text('image'),
  );
}