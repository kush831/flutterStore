import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/end_points.dart';
import '../logic/packaging_logic.dart';
import 'packaging_models.dart';

class PackagingRepository {
  PackagingRepository(this._api);

  final ApiClient _api;

  Future<List<PackagingPref>> list() async {
    final root = await _api.get(EndPoints.packagingPrefs);
    return [for (final p in root.sub('data').list('packagingPreferences', PackagingPref.fromJson)) if (p.id.isNotEmpty) p];
  }

  /// Creates an item, or updates it when `id` is given. The icon goes as `icon[0]`. Returns the server's message.
  Future<String> save(String? id, PackagingForm f) async {
    final p = f.photo;
    final ext = (p != null && p.name.toLowerCase().endsWith('.png')) ? 'png' : 'jpg';
    final root = await _api.postMultipart(
      EndPoints.savePackaging,
      fields: packagingFields(id: id, f: f),
      files: [if (p != null) ('icon[0]', UploadFile(bytes: p.bytes, filename: 'icon_0.$ext'))],
    );
    return root.text('message');
  }

  Future<String> delete(String id) async {
    final root = await _api.postForm(EndPoints.deletePackaging, {'id': id});
    return root.text('message');
  }
}

final packagingRepositoryProvider = Provider<PackagingRepository>((ref) => PackagingRepository(ref.watch(apiClientProvider)));

final packagingProvider = FutureProvider.autoDispose<List<PackagingPref>>((ref) {
  ref.watch(userScopeProvider);
  return ref.watch(packagingRepositoryProvider).list();
});