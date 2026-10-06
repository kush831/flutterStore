import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_env.dart';

/// Token and API keys, in the platform's secure storage (Keychain / Keystore / WebCrypto).
/// Values are cached in memory, so the network layer reads them instantly.
class SessionStore {
  SessionStore._(this._storage);

  final FlutterSecureStorage _storage;

  static const _kToken = 'token';
  static const _kPublic = 'public_key';
  static const _kSecret = 'secret_key';

  String _token = '';
  String _publicKey = '';
  String _secretKey = '';

  static Future<SessionStore> load() async {
    const storage = FlutterSecureStorage();
    final s = SessionStore._(storage);
    try {
      s._token = await storage.read(key: _kToken) ?? '';
      s._publicKey = await storage.read(key: _kPublic) ?? '';
      s._secretKey = await storage.read(key: _kSecret) ?? '';
    } catch (_) {
      // Android keystore can become unreadable after a restore / OS update → start logged out, don't crash.
      try {
        await storage.deleteAll();
      } catch (_) {}
    }
    return s;
  }

  String get token => _token;
  bool get isLoggedIn => _token.isNotEmpty;

  /// Merchant keys from the login response, otherwise the flavor's keys from env.
  String get publicKey => _publicKey.isNotEmpty ? _publicKey : AppEnv.apiKey;
  String get secretKey => _secretKey.isNotEmpty ? _secretKey : AppEnv.secretKey;

  Future<void> saveLogin({required String token, String? publicKey, String? secretKey}) async {
    _token = 'Bearer $token';
    if (publicKey != null && publicKey.isNotEmpty) _publicKey = publicKey;
    if (secretKey != null && secretKey.isNotEmpty) _secretKey = secretKey;
    try {
      await _storage.write(key: _kToken, value: _token);
      await _storage.write(key: _kPublic, value: _publicKey);
      await _storage.write(key: _kSecret, value: _secretKey);
    } catch (_) {}
  }

  /// Logout: memory first (so requests stop using the token at once), then disk.
  Future<void> clear() async {
    _token = '';
    _publicKey = '';
    _secretKey = '';
    try {
      await _storage.deleteAll();
    } catch (_) {}
  }
  /// Preview PIN: this merchant's API keys replace the flavor's keys (until the next PIN).
  Future<void> saveMerchantKeys({required String publicKey, required String secretKey}) async {
    _publicKey = publicKey;
    _secretKey = secretKey;
    try {
      await _storage.write(key: _kPublic, value: publicKey);
      await _storage.write(key: _kSecret, value: secretKey);
    } catch (_) {}
  }
}