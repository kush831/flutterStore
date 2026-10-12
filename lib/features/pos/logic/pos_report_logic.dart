import '../data/pos_report_models.dart';
import 'pos_shift_logic.dart' show posNum;

/// The periods of Analytics: the value the server takes, and the text key of the tab.
enum PosPeriod {
  today('today', 'pos_posanalysisscreen_period_today'),
  week('week', 'pos_posanalysisscreen_period_this_week'),
  month('month', 'pos_posanalysisscreen_period_this_month');

  const PosPeriod(this.value, this.labelKey);

  final String value;
  final String labelKey;
}

enum Trend { up, down, flat }

/// Up, down or flat from the server's growth text ("+12.5%", "-3%", "0%"). A flag from the server, when it sends one, wins.
Trend trendOf(String? growth, {bool? positive}) {
  final g = (growth ?? '').trim();
  if (g.isEmpty) return Trend.flat;
  final n = double.tryParse(g.replaceAll(RegExp(r'[^0-9.\-]'), ''));
  if (n != null && n == 0) return Trend.flat;
  if (positive != null) return positive ? Trend.up : Trend.down;
  return g.startsWith('-') ? Trend.down : Trend.up;
}

/// The bars of the hourly chart: each slot with its height as a share of the busiest hour (0 to 1). Empty when nothing was sold.
List<({PosHourlySlot slot, double fraction})> hourlyBars(List<PosHourlySlot> slots) {
  final max = slots.fold(0.0, (m, s) => s.revenueRaw > m ? s.revenueRaw : m);
  if (max <= 0) return const [];
  return [for (final s in slots) (slot: s, fraction: (s.revenueRaw / max).clamp(0.0, 1.0))];
}

/// The slot the server calls the peak.
bool isPeakSlot(PosHourlySlot s, String peakLabel) => peakLabel.trim().isNotEmpty && s.label.trim().toLowerCase() == peakLabel.trim().toLowerCase();

/// Jetpack compared the TEXT of expected and actual cash, so "₹1,000.00" against "₹1000" looked like a discrepancy.
/// The numbers are compared here. No shift summary counts as balanced.
bool shiftBalanced(PosShiftSummary? s) {
  if (s == null) return true;
  final e = double.tryParse(s.expectedCash.replaceAll(RegExp(r'[^0-9.\-]'), ''));
  final a = double.tryParse(s.actualCash.replaceAll(RegExp(r'[^0-9.\-]'), ''));
  if (e != null && a != null) return (e - a).abs() < 0.005;
  return s.expectedCash.trim() == s.actualCash.trim();
}

/// Orders in the queue: the server's total, else the three stages added.
int queueActive(PosOrderQueue q) => q.total > 0 ? q.total : q.waiting + q.preparing + q.ready;

/// The first [n] best sellers, the biggest revenue first (the server already sorts them; this keeps it true).
List<PosBestItem> topSellers(List<PosBestItem> items, int n) => ([...items]..sort((a, b) => b.revenueRaw.compareTo(a.revenueRaw))).take(n).toList();

/// A share as a fraction of the bar: "37.5% of gross" → 0.375.
double shareOf(String text) {
  final m = RegExp(r'-?\d+(\.\d+)?').firstMatch(text);
  if (m == null) return 0;
  return ((double.tryParse(m.group(0)!) ?? 0) / 100).clamp(0.0, 1.0);
}

/// The body of the report request: the shift, and a period only for Analytics.
Map<String, Object?> reportBody(String sessionId, {String? period}) => {'pos_session_id': sessionId, if (period != null && period.isNotEmpty) 'period': period};

/// A figure from the server text, for sorting and bars.
double figure(String s) => posNum(s);