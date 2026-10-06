import 'package:flutter/foundation.dart';

/// true  = the four rules shown on screen are enforced (recommended).
/// false = Jetpack's behaviour: only 6+ characters are required, the checklist is guidance.
const kEnforceAllPasswordRules = true;

@immutable
class PasswordCheck {
  const PasswordCheck({required this.length8, required this.upper, required this.number, required this.special, required this.length});

  final bool length8;
  final bool upper;
  final bool number;
  final bool special;
  final int length;

  factory PasswordCheck.of(String p) => PasswordCheck(
    length8: p.length >= 8,
    upper: RegExp(r'[A-Z]').hasMatch(p),
    number: RegExp(r'\d').hasMatch(p),
    special: RegExp(r'[^A-Za-z0-9\s]').hasMatch(p),
    length: p.length,
  );

  /// 0–4: how many rules are met (drives the strength bar).
  int get score => [length8, upper, number, special].where((e) => e).length;

  bool get allMet => score == 4;

  /// What the app actually accepts.
  bool get acceptable => kEnforceAllPasswordRules ? allMet : length >= 6;
}