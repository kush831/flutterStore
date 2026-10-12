import '../data/pos_shift_models.dart';

const kTerminalTypes = ['counter', 'kiosk', 'mobile'];

/// "₹ 1,234.50" → 1234.5. Unreadable text is 0.
double posNum(String s) => double.tryParse(s.replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? 0;

/// A number as text for the money formatter: no ".00" when it is whole.
String posAmountText(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

/// What should be in the drawer: the opening cash plus the cash sales (Jetpack).
double expectedCash(String opening, String cashSales) => posNum(opening) + posNum(cashSales);

/// A cash field (opening, counted): a number, not negative. Zero is fine.
bool cashValid(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return false;
  final n = double.tryParse(t);
  return n != null && n >= 0;
}

/// Jetpack enables Save when the name and the device id are filled in, and the code too when adding.
bool terminalFormValid({required String name, required String code, required String deviceId, required bool isEdit}) =>
    name.trim().isNotEmpty && (isEdit || code.trim().isNotEmpty) && deviceId.trim().isNotEmpty;

({int total, int available, int inUse}) terminalStats(List<PosTerminal> all) => (
total: all.length,
available: all.where((t) => t.available).length,
inUse: all.where((t) => t.isInUse).length,
);

List<PosTerminal> availableOnly(List<PosTerminal> all) => [for (final t in all) if (t.available) t];

/// How long a shift has run. null when the server's time cannot be read.
Duration? sessionLength(String loginAt, DateTime now) {
  final t = DateTime.tryParse(loginAt.trim().replaceFirst(' ', 'T'));
  if (t == null) return null;
  final d = now.difference(t);
  return d.isNegative ? Duration.zero : d;
}

/// "3h 12m" (Jetpack: "0h 0m" when unknown).
String formatLength(Duration? d) => d == null ? '0h 0m' : '${d.inHours}h ${d.inMinutes.remainder(60)}m';

/// "counter" → "Counter".
String titleCase(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Counted minus expected: above 0 a surplus, below 0 a shortage.
double cashDifference(String counted, double expected) => posNum(counted) - expected;

enum CashStatus { balanced, surplus, shortage }

CashStatus cashStatus(double diff) => diff.abs() < 0.005 ? CashStatus.balanced : (diff > 0 ? CashStatus.surplus : CashStatus.shortage);

String cashStatusKey(CashStatus s) => switch (s) {
  CashStatus.balanced => 'pos_posclosesessionscreen_cash_balanced',
  CashStatus.surplus => 'pos_posclosesessionscreen_cash_surplus',
  CashStatus.shortage => 'pos_posclosesessionscreen_cash_shortage',
};

/// Jetpack enables "Complete Handover" with a phone number and a 4-digit PIN.
bool handoverReady(String phone, String pin) => phone.trim().isNotEmpty && pin.length == 4;

/// Jetpack sends the OLD shift's opening cash as the new shift's opening cash, which ignores everything sold since.
/// The cash really in the drawer is the closing cash, so that is what the incoming staff member starts with.
/// Set this to false if your backend expects Jetpack's way.
const kHandoverOpensWithClosingCash = true;

Map<String, String> handoverFields({required String businessId, required String sessionId, required String phone, required String pin, required String openingCash, required double closingCash}) {
  final closing = posAmountText(closingCash);
  return {
    'incoming_staff_phone': phone.trim(),
    'incoming_staff_pin': pin,
    'closing_cash': closing,
    'opening_cash': kHandoverOpensWithClosingCash ? closing : openingCash,
    'session_id': sessionId,
    'business_segment_id': businessId,
  };
}

List<PosManagerSession> activeOf(List<PosManagerSession> all) => [for (final s in all) if (s.isActive) s];

/// The cash that should be in all the open drawers together.
double drawersTotal(List<PosManagerSession> all) => activeOf(all).fold(0.0, (a, s) => a + posNum(s.expectedDrawer));