/// A period for a report: today, this week, this month, everything, or a custom range.
enum PeriodPreset { today, week, month, all, custom }

/// Dates as the server wants them: yyyy-MM-dd, ALWAYS plain digits (a device locale can turn them into Arabic digits).
String formatApiDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class PeriodRange {
  const PeriodRange._(this.preset, this.start, this.end);

  final PeriodPreset preset;
  final DateTime? start; // null for "all"
  final DateTime? end;

  /// [firstDayOfWeek]: 0 = Sunday … 6 = Saturday (what MaterialLocalizations.firstDayOfWeekIndex gives).
  factory PeriodRange.preset(PeriodPreset p, DateTime now, {int firstDayOfWeek = 0}) {
    final today = DateTime(now.year, now.month, now.day);
    switch (p) {
      case PeriodPreset.today:
      case PeriodPreset.custom:
        return PeriodRange._(p, today, today);
      case PeriodPreset.week:
        final back = ((today.weekday % 7) - firstDayOfWeek + 7) % 7;
        return PeriodRange._(p, DateTime(today.year, today.month, today.day - back), today);
      case PeriodPreset.month:
        return PeriodRange._(p, DateTime(today.year, today.month, 1), today);
      case PeriodPreset.all:
        return const PeriodRange._(PeriodPreset.all, null, null);
    }
  }

  /// The two dates in either order, without a time of day.
  factory PeriodRange.custom(DateTime a, DateTime b) {
    final x = DateTime(a.year, a.month, a.day);
    final y = DateTime(b.year, b.month, b.day);
    return x.isAfter(y) ? PeriodRange._(PeriodPreset.custom, y, x) : PeriodRange._(PeriodPreset.custom, x, y);
  }

  String? get apiStart => start == null ? null : formatApiDate(start!);
  String? get apiEnd => end == null ? null : formatApiDate(end!);

  /// Two ranges with the same dates ask the server the same thing, whatever chip they came from.
  @override
  bool operator ==(Object other) => other is PeriodRange && other.apiStart == apiStart && other.apiEnd == apiEnd;

  @override
  int get hashCode => Object.hash(apiStart, apiEnd);
}