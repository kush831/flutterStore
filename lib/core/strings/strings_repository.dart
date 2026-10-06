import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../network/end_points.dart';
import '../storage/app_prefs.dart';
import '../storage/storage_providers.dart';

class StringsRepository {
  StringsRepository(this._api, this._prefs);

  final ApiClient _api;
  final AppPrefs _prefs;

  /// Last downloaded strings for this language, or null.
  Map<String, String>? readCache(String code) {
    final raw = _prefs.stringsJson(code);
    if (raw == null || raw.isEmpty) return null;
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return null;
      final m = {
        for (final e in j.entries)
          if (e.value != null) '${e.key}': '${e.value}',
      };
      return m.isEmpty ? null : m;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeCache(String code, Map<String, String> strings) =>
      _prefs.setStringsJson(code, jsonEncode(strings));

  /// Downloads the strings for the language stored in AppPrefs (it is sent as the `locale` header).
  /// Throws AppException when offline or the server says no.
  Future<Map<String, String>> fetch() async {
    final root = await _api.get(EndPoints.appStrings);
    final translations = root.sub('data').obj('translations');
    if (translations == null) return const {};
    return {
      for (final e in translations.map.entries)
        if (e.value != null) e.key: '${e.value}',
    };
  }
}

final stringsRepositoryProvider = Provider<StringsRepository>(
      (ref) => StringsRepository(ref.watch(apiClientProvider), ref.watch(appPrefsProvider)),
);