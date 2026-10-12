import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/end_points.dart';
import 'style_models.dart';

class StylesRepository {
  StylesRepository(this._api);

  final ApiClient _api;

  Future<List<CuisineStyle>> styles() async {
    final root = await _api.postForm(EndPoints.styles);
    return [for (final s in root.list('data', CuisineStyle.fromJson)) if (s.id.isNotEmpty) s];
  }

  /// A JSON body (not a form). Returns the server's message.
  Future<String> save(List<CuisineStyle> all, Set<String> chosen) async {
    final root = await _api.postJson(EndPoints.saveStyles, {'arr_style': stylesPayload(all, chosen)});
    return root.text('message');
  }
}

final stylesRepositoryProvider = Provider<StylesRepository>((ref) => StylesRepository(ref.watch(apiClientProvider)));

final stylesProvider = FutureProvider.autoDispose<List<CuisineStyle>>((ref) {
  ref.watch(userScopeProvider);
  return ref.watch(stylesRepositoryProvider).styles();
});