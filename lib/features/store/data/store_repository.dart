import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/network/end_points.dart';
import '../logic/store_logic.dart';
import 'store_models.dart';

class StoreRepository {
  StoreRepository(this._api);

  final ApiClient _api;

  Future<StoreProfile> profile() async {
    final root = await _api.postForm(EndPoints.merchantDetails);
    final p = StoreProfile.fromJson(root);
    if (p.id == 0 && p.name.isEmpty) throw const AppException('', kind: ErrorKind.server, detail: 'store profile without data');
    return p;
  }

  /// Saves the profile. The logo goes as the file `business_profile_image`. Returns the server's message.
  Future<String> saveProfile(StoreForm f, {void Function(double)? onProgress}) async {
    final photo = f.photo;
    final root = await _api.postMultipart(
      EndPoints.editProfile,
      fields: profileFields(f),
      files: [if (photo != null) ('business_profile_image', UploadFile(bytes: photo.bytes, filename: photo.name.isEmpty ? 'profile.jpg' : photo.name))],
      onProgress: onProgress == null ? null : (sent, total) => total > 0 ? onProgress(sent / total) : null,
    );
    return root.text('message');
  }

  /// Saves the 7 days in one call (the same endpoint as the profile). Returns the server's message.
  Future<String> saveTimings(List<DaySchedule> days) async {
    final root = await _api.postMultipart(EndPoints.editProfile, fields: timingFields(days));
    return root.text('message');
  }
}

final storeRepositoryProvider = Provider<StoreRepository>((ref) => StoreRepository(ref.watch(apiClientProvider)));