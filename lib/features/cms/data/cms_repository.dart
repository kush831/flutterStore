import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/network/end_points.dart';
import '../../splash/logic/config_controller.dart';

class CmsContent {
  const CmsContent({required this.title, required this.body, required this.isUrl, this.updatedAt, this.fromSavedCopy = false});

  final String title;

  /// HTML to render, or (when [isUrl]) a web address to show.
  final String body;
  final bool isUrl;
  final DateTime? updatedAt;

  /// Shown from the configuration saved on the phone because the server could not be reached.
  final bool fromSavedCopy;
}

/// The API's `contentType` says whether `description` is HTML or a link. If it says nothing,
/// a description that is just one web address counts as a link.
bool isUrlContent(String contentType, String body) {
  final t = contentType.toLowerCase();
  if (t.contains('url') || t.contains('link')) return true;
  if (t.contains('html') || t.contains('text')) return false;
  return RegExp(r'^https?://\S+$').hasMatch(body.trim());
}

class CmsRepository {
  CmsRepository(this._api);

  final ApiClient _api;

  /// Throws AppException.
  Future<CmsContent> fetch(String slug) async {
    final root = await _api.postForm(EndPoints.cmsPages, {'slug': slug});
    final d = root.sub('data');
    final body = d.text('description');
    final updated = d.str('updatedAt');
    return CmsContent(
      title: d.text('title'),
      body: body,
      isUrl: isUrlContent(d.text('contentType'), body),
      updatedAt: updated == null ? null : DateTime.tryParse(updated.replaceFirst(' ', 'T')),
    );
  }
}

final cmsRepositoryProvider = Provider<CmsRepository>((ref) => CmsRepository(ref.watch(apiClientProvider)));

/// The page for a slug. Offline (or a server error) → the copy saved in the configuration.
final cmsPageProvider = FutureProvider.autoDispose.family<CmsContent, String>((ref, slug) async {
  try {
    return await ref.watch(cmsRepositoryProvider).fetch(slug);
  } on AppException catch (e) {
    if (e.isSession) rethrow;
    final saved = ref.read(appConfigProvider)?.cmsPages.where((p) => p.slug == slug).firstOrNull;
    if (saved != null && saved.description.trim().isNotEmpty) {
      return CmsContent(
        title: saved.title,
        body: saved.description,
        isUrl: isUrlContent('', saved.description),
        fromSavedCopy: true,
      );
    }
    rethrow;
  }
});