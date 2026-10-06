import 'package:flutter/material.dart';

abstract final class Space {
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32;
}

abstract final class Radii {
  static const double sm = 8, md = 12, lg = 16, xl = 24;
}

abstract final class Motion {
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 250);
}

/// Semantic colours for both themes. The primary colour is NOT here:
/// it comes from the environment / merchant config (`context.primary`).
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.canvas,
    required this.surface,
    required this.sunken,
    required this.border,
    required this.borderStrong,
    required this.text1,
    required this.text2,
    required this.text3,
    required this.success,
    required this.successBg,
    required this.warning,
    required this.warningBg,
    required this.danger,
    required this.dangerBg,
    required this.info,
    required this.infoBg,
  });

  final Color canvas; // page background
  final Color surface; // cards, sidebar, top bar
  final Color sunken; // inputs, table headers, hover
  final Color border;
  final Color borderStrong;
  final Color text1; // primary text
  final Color text2; // secondary text
  final Color text3; // hints
  final Color success, successBg, warning, warningBg, danger, dangerBg, info, infoBg;

  static const light = AppTokens(
    canvas: Color(0xFFF6F7F9),
    surface: Color(0xFFFFFFFF),
    sunken: Color(0xFFF1F3F6),
    border: Color(0xFFE5E7EB),
    borderStrong: Color(0xFFD1D5DB),
    text1: Color(0xFF111827),
    text2: Color(0xFF4B5563),
    text3: Color(0xFF9CA3AF),
    success: Color(0xFF166534),
    successBg: Color(0xFFDCFCE7),
    warning: Color(0xFF92400E),
    warningBg: Color(0xFFFEF3C7),
    danger: Color(0xFFB91C1C),
    dangerBg: Color(0xFFFEE2E2),
    info: Color(0xFF1D4ED8),
    infoBg: Color(0xFFDBEAFE),
  );

  static const dark = AppTokens(
    canvas: Color(0xFF0B0D10),
    surface: Color(0xFF14171C),
    sunken: Color(0xFF0F1216),
    border: Color(0xFF262B33),
    borderStrong: Color(0xFF363C46),
    text1: Color(0xFFF3F4F6),
    text2: Color(0xFFA3AAB5),
    text3: Color(0xFF6B7280),
    success: Color(0xFF86EFAC),
    successBg: Color(0xFF052E1A),
    warning: Color(0xFFFCD34D),
    warningBg: Color(0xFF422006),
    danger: Color(0xFFFCA5A5),
    dangerBg: Color(0xFF450A0A),
    info: Color(0xFF93C5FD),
    infoBg: Color(0xFF172554),
  );

  @override
  AppTokens copyWith() => this;

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppTokens(
      canvas: l(canvas, other.canvas),
      surface: l(surface, other.surface),
      sunken: l(sunken, other.sunken),
      border: l(border, other.border),
      borderStrong: l(borderStrong, other.borderStrong),
      text1: l(text1, other.text1),
      text2: l(text2, other.text2),
      text3: l(text3, other.text3),
      success: l(success, other.success),
      successBg: l(successBg, other.successBg),
      warning: l(warning, other.warning),
      warningBg: l(warningBg, other.warningBg),
      danger: l(danger, other.danger),
      dangerBg: l(dangerBg, other.dangerBg),
      info: l(info, other.info),
      infoBg: l(infoBg, other.infoBg),
    );
  }
}

extension TokensContext on BuildContext {
  /// `context.tk.surface`, `context.tk.border` …
  AppTokens get tk => Theme.of(this).extension<AppTokens>()!;

  /// The brand colour of the current theme.
  Color get primary => Theme.of(this).colorScheme.primary;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}