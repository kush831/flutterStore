import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/network/end_points.dart';
import '../../../core/storage/app_prefs.dart';
import '../../../core/storage/storage_providers.dart';
import 'login_models.dart';

class AuthRepository {
  AuthRepository(this._api, this._prefs);

  final ApiClient _api;
  final AppPrefs _prefs;

  /// [identifier] is the email, or the phone number on the phone tab (the API takes both in `email`).
  /// Throws AppException.
  Future<LoginResult> login({required String identifier, required String password}) async {
    final root = await _api.postForm(
      EndPoints.login,
      {
        'email': identifier,
        'password': password,
        'player_id': _prefs.playerId,
        'locale': _prefs.language ?? 'en',
      },
      null,
      false, // requireSuccess: a refused login still carries data we need
    );

    final result = root.str('result');
    if (result == '1') {
      final r = LoginResult.fromJson(root);
      if (r.token.isEmpty) throw const AppException('', kind: ErrorKind.server, detail: 'login without access_token');
      return r;
    }

    // result "0": the server may still return the segment id (the documents screens need it).
    final segmentId = root.sub('data').str('bussinessSegmentId');
    if (segmentId != null && segmentId.isNotEmpty) await _prefs.setBusinessSegmentId(segmentId);
    throw AppException(root.text('message'), kind: ErrorKind.api, code: result);
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
      (ref) => AuthRepository(ref.watch(apiClientProvider), ref.watch(appPrefsProvider)),
);