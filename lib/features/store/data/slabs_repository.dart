import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/end_points.dart';
import '../logic/slab_logic.dart';
import 'slab_models.dart';

class SlabsRepository {
  SlabsRepository(this._api);

  final ApiClient _api;

  /// The store's slabs, in priority order.
  Future<List<AvailabilitySlab>> slabs() async {
    final root = await _api.get(EndPoints.timeSlabs);
    final list = [for (final s in root.sub('data').list('timeSlabs', AvailabilitySlab.fromJson)) if (s.id.isNotEmpty) s];
    list.sort((a, b) {
      final c = a.order.compareTo(b.order);
      return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  /// Creates a slab, or updates it when `id` is given. The picture goes as `image_file[0]`. Returns the server's message.
  Future<String> saveSlab(String? id, SlabForm f) async {
    final p = f.photo;
    final ext = (p != null && p.name.toLowerCase().endsWith('.png')) ? 'png' : 'jpg';
    final root = await _api.postMultipart(
      EndPoints.saveSlab,
      fields: slabFields(id: id, f: f),
      files: [if (p != null) ('image_file[0]', UploadFile(bytes: p.bytes, filename: 'slab_0.$ext'))],
    );
    return root.text('message');
  }

  Future<String> deleteSlab(String id) async {
    final root = await _api.postForm(EndPoints.deleteSlab, {'id': id});
    return root.text('message');
  }
}

final slabsRepositoryProvider = Provider<SlabsRepository>((ref) => SlabsRepository(ref.watch(apiClientProvider)));

final slabsProvider = FutureProvider.autoDispose<List<AvailabilitySlab>>((ref) {
  ref.watch(userScopeProvider);
  return ref.watch(slabsRepositoryProvider).slabs();
});