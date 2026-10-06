import 'dart:convert';

import 'package:apporio_store_30sept/core/network/end_points.dart';
import 'package:apporio_store_30sept/core/network/json_reader.dart';
import 'package:apporio_store_30sept/core/storage/storage_providers.dart';
import 'package:apporio_store_30sept/features/splash/data/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/app_prefs.dart';

class ConfigRepository {
  ConfigRepository(this._api, this._prefs);

  final ApiClient _api;
  final AppPrefs _prefs;

  String get _callFrom =>
      kIsWeb ? 'WEB' : defaultTargetPlatform.name.toUpperCase();

  /// The saved configuration from the last launch, or null
  AppConfig? readCache() {
    final raw = _prefs.configJson;
    if (raw == null || raw.isEmpty) return null;
    try {
      return AppConfig.fromJson(JsonReader(jsonDecode(raw)));
    } catch (_) {
      return null;
    }
  }

  /// Downloads and save the configuration. Throws AppException.

  Future<AppConfig> fetch() async {
    final info = await PackageInfo.fromPlatform();
    final root = await _api.postForm(EndPoints.configuration, {
      'call_from': _callFrom,
      'apk_version': info.version,
    });
    final data = root.sub('data');
    await _prefs.setConfigJson(jsonEncode(data.map));
    return AppConfig.fromJson(data);
  }
}

final configRepositoryProvider = Provider<ConfigRepository>(
  (ref) => ConfigRepository(
    ref.watch(apiClientProvider),
    ref.watch(appPrefsProvider),
  ),
);
