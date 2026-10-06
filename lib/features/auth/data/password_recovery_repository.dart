import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/end_points.dart';
import '../../../core/storage/app_prefs.dart';
import '../../../core/storage/storage_providers.dart';

class OtpChallenge {
  const OtpChallenge({required this.otp, required this.autoFill});

  final String otp;

  /// The server's "demo mode" flag: it wants the code filled in automatically.
  final bool autoFill;
}

/// ⚠️ SECURITY (tell the backend team): today the server returns the code in the response and the reset call
/// needs no code or token. When the backend is fixed (code sent by email/SMS, a verify endpoint returning a
/// reset token, the reset call requiring that token), only THIS file and RecoveryController.verify() change.
class PasswordRecoveryRepository {
  PasswordRecoveryRepository(this._api, this._prefs);

  final ApiClient _api;
  final AppPrefs _prefs;

  /// Throws AppException (the server's message when the account is unknown).
  Future<OtpChallenge> requestCode(String identifier) async {
    final root = await _api.postForm(EndPoints.forgotPasswordRequest, {
      'email': identifier,
      'locale': _prefs.language ?? 'en',
    });
    final data = root.sub('data');
    return OtpChallenge(otp: data.text('otp'), autoFill: data.flag('autoFill'));
  }

  /// Returns the server's success message. `for` is always "EMAIL" and the identifier travels in `phone`
  /// (that is how the API works).
  Future<String> resetPassword({required String identifier, required String password}) async {
    final root = await _api.postJson(EndPoints.resetPassword, {
      'password': password,
      'for': 'EMAIL',
      'phone': identifier,
      'locale': _prefs.language ?? 'en',
    });
    return root.text('message');
  }
}

final passwordRecoveryRepositoryProvider = Provider<PasswordRecoveryRepository>(
      (ref) => PasswordRecoveryRepository(ref.watch(apiClientProvider), ref.watch(appPrefsProvider)),
);