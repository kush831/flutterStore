import 'app_language.dart';
import 'fallback_strings.dart';
import 'missing_keys.dart';

enum StringsSource { none, cache, server }

/// Immutable snapshot of the server texts for one language.
class AppStrings {
  const AppStrings({required this.code, this.strings = const {}, this.source = StringsSource.none});

  final String code;
  final Map<String, String> strings;
  final StringsSource source;

  bool get isLoaded => strings.isNotEmpty;
  bool get isRtl => AppLanguages.find(code)?.rtl ?? false;

  /// The text for [key]:
  ///  1. what the server sent                          (always wins)
  ///  2. [fallback] given at the call site (strOr)
  ///  3. the bundled English text in kFallbackStrings
  ///  4. the key itself (a visible gap), or '' while nothing has loaded yet
  /// A key the server did not send is still recorded in [MissingKeys] (see /dev/strings).
  String get(String key, [List<Object?> args = const [], String? fallback]) {
    // ignore: avoid_print
    if (key.contains('customerInfo')) print('STR $key → server="${strings[key]}" fallback="${kFallbackStrings[key]}" loaded=$isLoaded');
    final raw = strings[key];
    if (raw != null && raw.trim().isNotEmpty && raw.trim() != key) {
      return args.isEmpty ? raw : _format(raw, args);
    }

    if (isLoaded) MissingKeys.report(key);
    final fb = fallback ?? kFallbackStrings[key];
    if (fb != null) return args.isEmpty ? fb : _format(fb, args);
    return isLoaded ? key : '';
  }

  static final _placeholder = RegExp(r'%(?:(\d+)\$)?[sd]');

  static String _format(String s, List<Object?> args) {
    var next = 0;
    return s.replaceAllMapped(_placeholder, (m) {
      final index = m[1] != null ? int.parse(m[1]!) - 1 : next++;
      return index >= 0 && index < args.length ? '${args[index]}' : m[0]!;
    });
  }
}