import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/end_points.dart';
import '../../../core/storage/app_prefs.dart';
import '../../../core/storage/storage_providers.dart';
import '../logic/signup_validation.dart';

class SignupRepository {
  SignupRepository(this._api, this._prefs);

  final ApiClient _api;
  final AppPrefs _prefs;

  /// Returns the server's success message. Throws AppException (the server's message on a refusal).
  Future<String> signup(SignupForm f, {required bool sponsor}) async {
    final info = await PackageInfo.fromPlatform();
    final root = await _api.postJson(EndPoints.signup, {
      'full_name': f.store.trim(), // the STORE name (that is what the API calls full_name)
      'name': f.name.trim(), // the owner
      'email': f.email.trim(),
      'phone_number': f.phoneDigits,
      'country_id': f.country!.id,
      'password': f.password,
      'segment_id': f.segmentId,
      'timestampvalue': '${DateTime.now().millisecondsSinceEpoch}',
      'package_name': info.packageName,
      'player_id': _prefs.playerId,
      'user_sponsor_details': sponsor
          ? jsonEncode([
        {'key': 'sponsor_email', 'value': f.sponsorEmail.trim()},
        {'key': 'sponsor_name', 'value': f.sponsorName.trim()},
      ])
          : '',
    });
    return root.text('message');
  }
}

final signupRepositoryProvider = Provider<SignupRepository>(
      (ref) => SignupRepository(ref.watch(apiClientProvider), ref.watch(appPrefsProvider)),
);