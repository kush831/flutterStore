import 'package:flutter/widgets.dart';

import 'app_strings.dart';

/// Placed above the whole app (see app.dart). Every widget that calls `context.str`
/// rebuilds by itself when the language or the strings change.
class StringsScope extends InheritedWidget {
  const StringsScope({super.key, required this.strings, required super.child});

  final AppStrings strings;

  static AppStrings? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StringsScope>()?.strings;

  @override
  bool updateShouldNotify(StringsScope old) => !identical(strings, old.strings);
}

extension StringsContext on BuildContext {
  /// The Jetpack `strings.getString("key")` of this app.
  ///   context.str('main_tabbar_home_label')
  ///   context.str('some_key_with_placeholder', [12])
  String str(String key, [List<Object?> args = const []]) => StringsScope.maybeOf(this)?.get(key, args) ?? '';

  /// true for Arabic (and any other right-to-left language).
  bool get isRtl => Directionality.of(this) == TextDirection.rtl;
}