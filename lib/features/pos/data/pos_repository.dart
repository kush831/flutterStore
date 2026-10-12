import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/network/end_points.dart';
import '../../../core/storage/app_prefs.dart';
import '../../../core/storage/storage_providers.dart';
import '../logic/pos_auth.dart';
import 'pos_models.dart';

class PosRepository {
  PosRepository(this._api, this._prefs);

  final ApiClient _api;
  final AppPrefs _prefs;

  /// The staff PIN login. The body is JSON, with the store id the app already knows (empty on a cashier-only device).
  Future<({PosStaff staff, Map<String, dynamic> raw, String token})> verifyPin({required String phone, required String countryId, required String pin}) async {
    final root = await _api.postJson(EndPoints.posVerifyPin, {
      'phone': phone,
      'countryCode': countryId,
      'pin': pin,
      'business_segment_id': _prefs.businessSegmentId,
    });
    final d = root.sub('data');
    final token = d.text('accessToken');
    if (token.isEmpty) throw const AppException(AppException.generic, kind: ErrorKind.api);
    return (staff: PosStaff.fromJson(d), raw: d.map, token: token);
  }

  /// null = no open shift. Jetpack treats any failure as "no shift" (so the staff member is sent to Open Session);
  /// an expired POS token is the one exception and is rethrown.
  Future<PosActiveSession?> activeSession(String businessId) async {
    try {
      final root = await _api.postForm(EndPoints.posCurrentSession, {'business_segment_id': businessId}, null, false);
      if (root.text('result') != '1') return null;
      final d = root.obj('data');
      if (d == null || d.isEmpty) return null;
      return PosActiveSession.fromJson(d);
    } on AppException catch (e) {
      if (e.kind == ErrorKind.session) rethrow;
      return null;
    }
  }

  /// Tells the server this POS session ended. Never throws: the staff member is signed out here whatever the server says.
  Future<void> logout(String businessId) async {
    try {
      await _api.postForm(EndPoints.posLogout, {'business_segment_id': businessId}, null, false).timeout(const Duration(seconds: 6));
    } catch (_) {}
  }

  Future<PosMerchant> merchant() async => PosMerchant.fromJson(await _api.get(EndPoints.posMerchantDetails));
}

final posRepositoryProvider = Provider<PosRepository>((ref) => PosRepository(ref.watch(posApiProvider), ref.watch(appPrefsProvider)));

final posActiveSessionProvider = FutureProvider.autoDispose<PosActiveSession?>((ref) async {
  ref.watch(posScopeProvider);
  final staff = ref.watch(posAuthProvider).staff;
  if (staff == null) return null;
  return ref.watch(posRepositoryProvider).activeSession(staff.business.id);
});

final posMerchantProvider = FutureProvider.autoDispose<PosMerchant>((ref) {
  ref.watch(posScopeProvider);
  return ref.watch(posRepositoryProvider).merchant();
});