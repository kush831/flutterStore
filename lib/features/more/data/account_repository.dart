import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/end_points.dart';

class AccountRepository {
  AccountRepository(this._api);

  final ApiClient _api;

  /// Tells the server this device signed out (so it stops sending pushes to it).
  /// Never throws: the user is signed out on the phone whatever the server says.
  Future<void> logout() async {
    try {
      await _api.postForm(EndPoints.logout, const {}, null, false).timeout(const Duration(seconds: 6));
    } catch (_) {
      // offline, a timeout or a refusal: the caller signs out anyway
    }
  }

  /// Deletes the store's account on the server. Throws AppException with the server's message on a refusal
  /// (for example on a demo store), so the caller keeps the user signed in.
  Future<void> deleteAccount() async {
    await _api.postForm(EndPoints.deleteAccount);
  }
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) => AccountRepository(ref.watch(apiClientProvider)));

/// "2.0.0 (20)"
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.buildNumber.isEmpty ? info.version : '${info.version} (${info.buildNumber})';
});