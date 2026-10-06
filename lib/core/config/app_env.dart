import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Everything that used to be BuildConfig in the Jetpack project.
/// Filled at build time: flutter run --dart-define-from-file=env/<flavor>.json
abstract final class AppEnv {
  static const flavor = String.fromEnvironment('FLAVOR');
  static const appName = String.fromEnvironment('APP_NAME', defaultValue: 'Store');
  static const baseUrl = String.fromEnvironment('BASE_URL');
  static const apiKey = String.fromEnvironment('API_KEY');
  static const secretKey = String.fromEnvironment('SECRET_KEY');
  static const oneSignalAppId = String.fromEnvironment('ONESIGNAL_APP_ID');
  static const _primaryHex = String.fromEnvironment('COLOR_PRIMARY', defaultValue: '#D62924');
  static const _primaryEndHex = String.fromEnvironment('COLOR_PRIMARY_END', defaultValue: '#B71C1C');

  static bool get isPreview => flavor == 'apporioPreview';
  static bool get devTools => kDebugMode || isPreview;
  static Color get primary => _hex(_primaryHex);
  static Color get primaryEnd => _hex(_primaryEndHex);
  static const _previewPinReady = false;
  static bool get previewPinGate => isPreview && _previewPinReady;

  /// Fails fast with a clear message instead of a confusing network error later.
  static void assertConfigured() {
    if (baseUrl.isEmpty || apiKey.isEmpty || secretKey.isEmpty) {
      throw StateError(
        'Missing configuration. Run with: --dart-define-from-file=env/<flavor>.json',
      );
    }
  }
  /// "#D62924" or "D62924" → Color, or null when empty / invalid.
  static Color? parseColor(String? v) {
    if (v == null) return null;
    final h = v.replaceAll('#', '').trim();
    if (h.length != 6 && h.length != 8) return null;
    final n = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
    return n == null ? null : Color(n);
  }

  static Color _hex(String v) {
    final h = v.replaceAll('#', '').trim();
    final n = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
    return Color(n ?? 0xFFD62924);
  }
}