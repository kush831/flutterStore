import 'package:flutter/widgets.dart';

/// compact   < 600     phone                      → bottom bar, app bar per page
/// medium    600–1023  tablet, iPad portrait      → icon rail, top bar, page header
/// expanded  1024–1439 iPad landscape, laptop     → full sidebar, top bar, page header
/// large     ≥ 1440    desktop monitor            → same as expanded, wider sidebar
enum ScreenSize {
  compact,
  medium,
  expanded,
  large;

  bool get isCompact => this == compact;
  bool get isWide => index >= medium.index;
  bool get hasSidebar => index >= expanded.index;
}

abstract final class Breakpoints {
  static const double medium = 600;
  static const double expanded = 1024;
  static const double large = 1440;

  static ScreenSize of(double width) => width >= large
      ? ScreenSize.large
      : width >= expanded
      ? ScreenSize.expanded
      : width >= medium
      ? ScreenSize.medium
      : ScreenSize.compact;

  /// Horizontal page padding per size.
  static double padding(ScreenSize s) => switch (s) {
    ScreenSize.compact => 16,
    ScreenSize.medium => 24,
    ScreenSize.expanded => 32,
    ScreenSize.large => 40,
  };
}

extension ScreenContext on BuildContext {
  /// Size class of the whole window.
  ScreenSize get screen => Breakpoints.of(MediaQuery.sizeOf(this).width);
}