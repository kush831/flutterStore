import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_env.dart';

/// Records every key the UI asked for that the server did not send.
/// Only in debug builds and in the Preview flavor (the QA build). Never in production.
abstract final class MissingKeys {
  static final Set<String> _keys = {};

  /// Listen to this to redraw the /dev/strings page.
  static final ValueNotifier<int> changes = ValueNotifier(0);

  static bool get enabled => kDebugMode || AppEnv.isPreview;

  static List<String> get sorted => _keys.toList()..sort();

  static void report(String key) {
    if (!enabled) return;
    if (_keys.add(key)) {
      // never notify while a widget is building
      scheduleMicrotask(() => changes.value++);
    }
  }

  static void clear() {
    _keys.clear();
    changes.value++;
  }
}