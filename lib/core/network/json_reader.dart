/// Lenient JSON access for API responses that are not always well-typed:
/// numbers as strings, "null" as a string, snake_case vs camelCase keys, missing lists.
class JsonReader {
  JsonReader(Object? raw)
      : _m = raw is Map<String, dynamic>
      ? raw
      : raw is Map
      ? Map<String, dynamic>.from(raw)
      : const <String, dynamic>{};

  final Map<String, dynamic> _m;

  static final _upper = RegExp(r'[A-Z]');
  static final _under = RegExp(r'_([a-z])');
  static String _snake(String k) => k.replaceAllMapped(_upper, (m) => '_${m[0]!.toLowerCase()}');
  static String _camel(String k) => k.replaceAllMapped(_under, (m) => m[1]!.toUpperCase());

  /// Finds `key`, then its snake_case form, then its camelCase form.
  Object? operator [](String key) {
    if (_m.containsKey(key)) return _m[key];
    final s = _snake(key);
    if (s != key && _m.containsKey(s)) return _m[s];
    final c = _camel(key);
    if (c != key && _m.containsKey(c)) return _m[c];
    return null;
  }

  Map<String, dynamic> get map => _m;
  bool get isEmpty => _m.isEmpty;
  bool has(String key) => this[key] != null;

  /// Text, or null. The string "null" counts as null. `150.0` becomes "150".
  String? str(String key) {
    final v = this[key];
    if (v == null) return null;
    if (v is String) return v == 'null' ? null : v;
    if (v is Map || v is List) return null;
    if (v is double && v == v.truncateToDouble()) return v.toInt().toString();
    return v.toString();
  }

  /// Same as [str] but never null.
  String text(String key, [String fallback = '']) => str(key) ?? fallback;

  int? integer(String key) {
    final v = this[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      final t = v.trim();
      return int.tryParse(t) ?? double.tryParse(t)?.toInt();
    }
    return null;
  }

  double? number(String key) {
    final v = this[key];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '').trim());
    return null;
  }

  /// true for true / 1 / "1" / "true" / "yes" / "on".
  bool flag(String key) {
    final v = this[key];
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final t = v.trim().toLowerCase();
      return t == '1' || t == 'true' || t == 'yes' || t == 'on';
    }
    return false;
  }

  JsonReader? obj(String key) {
    final v = this[key];
    return v is Map ? JsonReader(v) : null;
  }

  /// Like [obj] but never null (an empty reader when missing).
  JsonReader sub(String key) => obj(key) ?? JsonReader(null);

  /// A list of objects. Missing or wrong type → empty list. Non-object items are skipped.
  List<T> list<T>(String key, T Function(JsonReader r) parse) {
    final v = this[key];
    if (v is! List) return <T>[];
    return [
      for (final e in v)
        if (e is Map) parse(JsonReader(e)),
    ];
  }

  List<String> strings(String key) {
    final v = this[key];
    if (v is! List) return const [];
    return [
      for (final e in v)
        if (e != null && '$e' != 'null') '$e',
    ];
  }
}