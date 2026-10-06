import 'package:shared_preferences/shared_preferences.dart';

/// Non-secret settings. Later steps add more getters here.
class AppPrefs {
  AppPrefs(this._p);

  final SharedPreferences _p;

  // Language code sent as the `locale` header ("en", "ar" …). null = not chosen yet.
  String? get language => _p.getString('language');
  Future<void> setLanguage(String code) => _p.setString('language', code);

  // OneSignal subscription id (saved by the push service, sent at login).
  String get playerId => _p.getString('player_id') ?? '7ef17c97-2254-484b-b0cf-8a234ace6749';
  Future<void> savePlayerId(String id) => _p.setString('player_id', id);

  // Set at login.
  String get businessSegmentId => _p.getString('business_segment_id') ?? '';
  Future<void> setBusinessSegmentId(String v) => _p.setString('business_segment_id', v);

  /// 0 = fine · 3 = Stripe documents required · 4 = upload documents required.
  int get signupStatus => _p.getInt('signup_status') ?? 0;
  Future<void> setSignupStatus(int v) => _p.setInt('signup_status', v);

  /// "food", "grocery" …
  String get segmentType => _p.getString('segment_type') ?? '';
  Future<void> setSegmentType(String v) => _p.setString('segment_type', v);
  bool get isFood => segmentType.toLowerCase() == 'food';

  String get currency => _p.getString('currency') ?? '';
  Future<void> setCurrency(String v) => _p.setString('currency', v);

  /// PIN entered on the preview login (the demo store uses 12345678).
  String get enteredPin => _p.getString('entered_pin') ?? '';
  Future<void> setEnteredPin(String v) => _p.setString('entered_pin', v);

  // Cached configuration response (Step 6): lets the app start offline.
  String? get configJson => _p.getString('config_json');
  Future<void> setConfigJson(String v) => _p.setString('config_json', v);
  Future<void> clearConfig() => _p.remove('config_json');

  /// Logout: forget everything about the account, keep device settings (language, theme, push id).
  Future<void> clearAccount() async {
    for (final k in ['business_segment_id', 'signup_status', 'segment_type', 'currency', 'entered_pin','membership_enabled']) {
      await _p.remove(k);
    }
  }
  /// false until the user picks a language on the welcome screen (Step 6 shows the picker then).
  bool get languageChosen => _p.getBool('language_chosen') ?? false;
  Future<void> setLanguageChosen(bool v) => _p.setBool('language_chosen', v);

  // Cached server strings, one entry per language.
  String? stringsJson(String code) => _p.getString('strings_$code');
  Future<void> setStringsJson(String code, String json) => _p.setString('strings_$code', json);

  /// The "Data & Privacy" sheet was accepted. Survives sign-out (it is about the device).
  bool get consentGiven => _p.getBool('consent_given') ?? false;
  Future<void> setConsentGiven(bool v) => _p.setBool('consent_given', v);

  /// Set at login (Step 7). Sends the owner to the membership page after launch.
  bool get membershipEnabled => _p.getBool('membership_enabled') ?? false;
  Future<void> setMembershipEnabled(bool v) => _p.setBool('membership_enabled', v);

  /// The merchant's brand colour returned by the Preview PIN ("#RRGGBB").
  String get previewPrimaryColor => _p.getString('preview_primary_color') ?? '';
  Future<void> setPreviewPrimaryColor(String v) => _p.setString('preview_primary_color', v);

  /// Another merchant's PIN: the saved texts belong to the previous one.
  Future<void> clearStringsCache() async {
    for (final k in _p.getKeys().where((k) => k.startsWith('strings_')).toList()) {
      await _p.remove(k);
    }
  }
}