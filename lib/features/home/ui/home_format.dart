/// 'Good Day!' before noon, then afternoon, evening, night (the same hours as Jetpack).
String greetingKeyFor(int hour) => hour < 12
    ? 'main_storedashboard_store_status_closed_goodDay'
    : hour < 17
    ? 'main_storedashboard_good_afternoon'
    : hour < 21
    ? 'main_storedashboard_good_evening'
    : 'main_storedashboard_good_night';

/// "1,200.50" → "₹1,200.50". A value that already carries its own symbol ("₹1,200") is left alone.
String money(String currency, String value) {
  final v = value.trim();
  if (v.isEmpty) return '—';
  final plain = RegExp(r'^[0-9.,\s]+$').hasMatch(v);
  if (!plain || currency.isEmpty) return v;
  return currency.length > 1 ? '$currency $v' : '$currency$v';
}