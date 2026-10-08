/// How a plan's length is written: the text key and the number to put into it.
/// A whole number of months or years reads as months or years, anything else as days.
/// ({key: '', n: null} when the server's text is not a number: the caller shows the text as it is.)
({String key, int? n}) periodParts(String raw) {
  final d = int.tryParse(raw.trim());
  if (d == null || d <= 0) return (key: '', n: null);
  const p = 'membership_membershipscreen_period_';
  if (d == 1) return (key: '${p}day', n: null);
  if (d < 30) return (key: '${p}days', n: d);
  if (d == 30) return (key: '${p}month', n: null);
  if (d < 365 && d % 30 == 0) return (key: '${p}months', n: d ~/ 30);
  if (d == 365) return (key: '${p}year', n: null);
  return (key: '${p}days', n: d);
}

/// Jetpack's rule: the plan in the middle of the list is the recommended one (never the one you already have).
bool isRecommended(int index, int total, {required bool active}) => total > 1 && index == total ~/ 2 && !active;