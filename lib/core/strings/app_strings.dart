import 'app_language.dart';
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

  /// The server text for [key].
  ///  • not loaded yet  → '' (no flicker of raw keys while the first download runs)
  ///  • key missing     → the key itself, and it is recorded in [MissingKeys]
  /// Placeholders: `%s`, `%d` (in order) or `%1$s`, `%2$s` (numbered).
  String get(String key, [List<Object?> args = const []]) {
    final raw = strings[key];
    if (raw == null || raw.isEmpty) {
      if (!isLoaded) return '';
      MissingKeys.report(key);
      return key;
    }
    return args.isEmpty ? raw : _format(raw, args);
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